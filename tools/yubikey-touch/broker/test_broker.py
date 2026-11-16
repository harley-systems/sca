#!/usr/bin/env python3
"""Tests of the fixture broker that need no hardware and no docker.

    python3 tools/yubikey-touch/broker/test_broker.py
"""
import importlib.machinery
import importlib.util
import os
import shutil
import socketserver
import subprocess
import sys
import threading
import tempfile
import unittest

sys.dont_write_bytecode = True     # no __pycache__ next to the broker
HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT = os.path.join(HERE, "..", "yubikey-fixture")
_loader = importlib.machinery.SourceFileLoader("broker", os.path.join(HERE, "..", "yubikey-fixture-broker"))
_spec = importlib.util.spec_from_loader("broker", _loader)
broker = importlib.util.module_from_spec(_spec)
_loader.exec_module(broker)

SHA = "0123456789abcdef0123456789abcdef01234567"
CONFIG = broker.Config({4: 38263298}, "repo", "sca-yubikey-fixture", 1800)


class TempDir(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)

    def write(self, rel, text=""):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        return path

    def link(self, rel, target):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        os.symlink(target, path)


class ConfigTest(TempDir):
    def load(self, text):
        return broker.load_config(self.write("fixture.conf", text))

    def assertRefused(self, text, message):
        with self.assertRaises(broker.BrokerError) as e:
            self.load(text)
        self.assertIn(message, str(e.exception))

    def test_slots_and_defaults(self):
        config = self.load("[slots]\n4 = 38263298\n")
        self.assertEqual({4: 38263298}, config.slots)
        self.assertEqual(broker.DEFAULT_REPOSITORY, config.repository)
        self.assertEqual("sca-yubikey-fixture", config.image)
        self.assertEqual(1800, config.max_timeout)

    def test_broker_section(self):
        config = self.load("[slots]\n4 = 1\n5 = 2\n[broker]\nrepository = /srv/sca.git\n"
                           "image = my-image\nmax_timeout = 60\n")
        self.assertEqual({4: 1, 5: 2}, config.slots)
        self.assertEqual(("/srv/sca.git", "my-image", 60), (config.repository, config.image, config.max_timeout))

    def test_errors(self):
        self.assertRefused("[slots]\n", "at least one slot")
        self.assertRefused("[broker]\nimage = x\n", "at least one slot")
        self.assertRefused("[slots]\n6 = 1\n", "slot 6 does not exist")
        self.assertRefused("[slots]\n4 = abc\n", "serial must be a number")
        self.assertRefused("[slots]\n4 = 1\n5 = 1\n", "same serial")
        self.assertRefused("[slots]\n4 = 1\n[other]\n", "unknown section")
        self.assertRefused("[slots]\n4 = 1\n[broker]\nrepo = x\n", "unknown key repo")
        self.assertRefused("[slots]\n4 = 1\n[broker]\nmax_timeout = 0\n", "max_timeout")
        self.assertRefused("[slots]\n4 = 1\n[broker]\nrepository = --upload-pack=x\n", "bad repository")
        self.assertRefused("not ini", "config")
        with self.assertRaises(broker.BrokerError) as e:
            broker.load_config(os.path.join(self.tmp, "missing.conf"))
        self.assertIn("cannot read config", str(e.exception))


class ValidateTest(unittest.TestCase):
    def assertRefused(self, req, message):
        with self.assertRaises(broker.BrokerError) as e:
            broker.validate(req, CONFIG)
        self.assertIn(message, str(e.exception))

    def run_req(self, **fields):
        return dict({"op": "run", "sha": SHA, "slot": 4, "steps": [{"test": "tests/hw/a.sh"}]}, **fields)

    def test_good_requests(self):
        for req in ({"op": "status"}, {"op": "touch", "slot": 4}, {"op": "touch", "slot": 4, "ms": 10},
                    {"op": "hold", "slot": 4}, {"op": "power", "slot": 4, "state": "off"},
                    {"op": "cycle", "slot": 4, "ms": 10000},
                    self.run_req(steps=[{"test": "tests/hw/a.sh"}, {"cycle": 1000}, {"test": "tests/hw/sub/b.sh"}],
                                 timeout=1800)):
            self.assertEqual(req, broker.validate(req, CONFIG))

    def test_shape(self):
        self.assertRefused([], "JSON object")
        self.assertRefused({"op": "reset"}, "unknown op")
        self.assertRefused({"op": "status", "slot": 4}, "unknown field 'slot'")
        self.assertRefused({"op": "touch"}, "missing field 'slot'")

    def test_slot(self):
        self.assertRefused({"op": "touch", "slot": 5}, "slot 5 is not configured")
        self.assertRefused({"op": "touch", "slot": "4"}, "slot must be a number")
        self.assertRefused({"op": "touch", "slot": True}, "slot must be a number")

    def test_ranges(self):
        self.assertRefused({"op": "touch", "slot": 4, "ms": 9}, "10..10000")
        self.assertRefused({"op": "touch", "slot": 4, "ms": 10001}, "10..10000")
        self.assertRefused({"op": "cycle", "slot": 4, "ms": 99}, "100..10000")
        self.assertRefused({"op": "power", "slot": 4, "state": "toggle"}, "on")
        self.assertRefused(self.run_req(timeout=1801), "timeout")
        self.assertRefused(self.run_req(steps=[{"cycle": 50}]), "cycle ms")

    def test_sha(self):
        for sha in ("main", SHA[:12], SHA.upper(), SHA + "0", "-" + SHA[1:], 1234):
            self.assertRefused(self.run_req(sha=sha), "40-character")

    def test_test_paths(self):
        for path in ("/etc/passwd", "tests/hw/../../x.sh", "tests/hw/./a.sh", "tests/test_smoke.sh",
                     "./tests/hw/a.sh", "tests/hw/", "tests/hw//a.sh", "tests/hw/a b.sh", 3):
            self.assertRefused(self.run_req(steps=[{"test": path}]), "under tests/hw/")

    def test_steps(self):
        self.assertRefused(self.run_req(steps=[]), "1..20")
        self.assertRefused(self.run_req(steps=[{"test": "tests/hw/a.sh"}] * 21), "1..20")
        self.assertRefused(self.run_req(steps=[{"test": "tests/hw/a.sh", "cycle": 1000}]), "each step")
        self.assertRefused(self.run_req(steps=[{"shell": "id"}]), "each step")
        self.assertRefused(self.run_req(steps="tests/hw/a.sh"), "list")


class FakeTree(TempDir):
    """A sysfs and /dev with the fixture on hub 1-3, a test key on 1-3.4 and the owner's key on 1-1."""

    def setUp(self):
        super().setUp()
        self.sys = os.path.join(self.tmp, "sys")
        self.dev = os.path.join(self.tmp, "dev")
        usb1 = "sys/devices/pci0000:00/usb1"
        self.usb_device(usb1 + "/1-3", "05e3", 1, 2)                  # the fixture's hub
        self.usb_device(usb1 + "/1-3/1-3.1", "2e8a", 1, 4)            # the RP2040
        os.makedirs(os.path.join(self.tmp, usb1, "1-3/1-3.1/1-3.1:1.0"))
        self.link("sys/class/tty/ttyACM0/device", os.path.join(self.tmp, usb1, "1-3/1-3.1/1-3.1:1.0"))
        self.write("dev/ttyACM0")
        self.link("dev/serial/by-id/usb-harley_YubiKey_touch_E66-if00", "../../ttyACM0")
        self.test_key = self.usb_device(usb1 + "/1-3/1-3.4", broker.YUBICO_VENDOR, 1, 7)
        self.hidraw(usb1 + "/1-3/1-3.4/1-3.4:1.0/0003:1050:0407.0002", "hidraw2")
        self.hidraw(usb1 + "/1-3/1-3.4/1-3.4:1.1/0003:1050:0407.0003", "hidraw3")
        self.usb_device(usb1 + "/1-1", broker.YUBICO_VENDOR, 1, 3)    # the owner's key, not on the hub
        self.hidraw(usb1 + "/1-1/1-1:1.0/0003:1050:0407.0001", "hidraw0")
        self.usb_device(usb1 + "/1-3/1-3.2", "046d", 1, 5)            # something else on the hub
        self.devices = broker.Devices(self.sys, self.dev)

    def usb_device(self, rel, vendor, busnum, devnum):
        self.write(rel + "/idVendor", vendor + "\n")
        self.write(rel + "/busnum", f"{busnum}\n")
        self.write(rel + "/devnum", f"{devnum}\n")
        self.link("sys/bus/usb/devices/" + os.path.basename(rel), os.path.join(self.tmp, rel))
        return os.path.join(self.tmp, rel)

    def hidraw(self, rel, name):
        os.makedirs(os.path.join(self.tmp, rel, "hidraw", name))
        self.link(f"sys/class/hidraw/{name}/device", os.path.join(self.tmp, rel))

    def set_devnum(self, devnum):
        self.write(os.path.relpath(self.test_key, self.tmp) + "/devnum", f"{devnum}\n")


class DevicesTest(FakeTree):
    def test_hub(self):
        self.assertEqual("1-3", self.devices.hub())

    def test_only_yubikeys_on_the_hub(self):
        self.assertEqual([broker.Instance(self.test_key, 1, 7)], self.devices.keys())

    def test_nodes(self):
        inst = self.devices.keys()[0]
        self.assertEqual([os.path.join(self.dev, "bus/usb/001/007"), os.path.join(self.dev, "hidraw2"),
                          os.path.join(self.dev, "hidraw3")], self.devices.nodes(inst))
        self.assertEqual([(os.path.join(self.dev, "bus/usb/001/007"), "/dev/bus/usb/001/007"),
                          (os.path.join(self.dev, "hidraw2"), "/dev/hidraw2"),
                          (os.path.join(self.dev, "hidraw3"), "/dev/hidraw3")], self.devices.device_args(inst))

    def test_no_fixture(self):
        os.unlink(os.path.join(self.dev, "serial/by-id/usb-harley_YubiKey_touch_E66-if00"))
        with self.assertRaises(broker.BrokerError) as e:
            self.devices.keys()
        self.assertIn("fixture not found", str(e.exception))


class FakeFixture:
    def __init__(self, on_send=None):
        self.sent = []
        self.on_send = on_send

    def send(self, line):
        self.sent.append(line)
        if self.on_send:
            self.on_send(line)
        return "ok " + line


class FakeBroker(broker.Broker):
    def __init__(self, devices, fixture, serials):
        super().__init__(CONFIG, devices, fixture, cache_dir=tempfile.mkdtemp())
        self.serials = serials      # devnum -> serial the probe finds
        self.probed = []

    def probe(self, inst):
        self.probed.append(inst.devnum)
        return self.serials.get(inst.devnum)


class BrokerTest(FakeTree):
    def make(self, serials, on_send=None):
        b = FakeBroker(self.devices, FakeFixture(on_send), serials)
        self.addCleanup(shutil.rmtree, os.path.dirname(b.repo))
        return b

    def test_probe_is_cached_per_instance(self):
        b = self.make({7: 38263298, 8: 38263298})
        b.key_for(4)
        b.key_for(4)
        self.assertEqual([7], b.probed)
        self.set_devnum(8)          # a power cycle: new devnum
        self.assertEqual(8, b.key_for(4).devnum)
        self.assertEqual([7, 8], b.probed)

    def test_unknown_serial_is_not_served(self):
        b = self.make({7: 11111111})
        with self.assertRaises(broker.BrokerError) as e:
            b.handle({"op": "touch", "slot": 4})
        self.assertIn("test key 38263298 is not present", str(e.exception))
        self.assertEqual([], b.fixture.sent)

    def test_touch(self):
        b = self.make({7: 38263298})
        self.assertEqual({"ok": True, "reply": "ok touch 4 500"}, b.handle({"op": "touch", "slot": 4, "ms": 500}))

    def test_status(self):
        b = self.make({7: 38263298})
        self.assertEqual({"ok": True, "fixture": "ok status",
                          "slots": {"4": {"serial": 38263298, "present": True, "busy": False}},
                          "other_keys": 0}, b.handle({"op": "status"}))

    def test_cycle_waits_for_the_new_instance(self):
        b = self.make({7: 38263298, 9: 38263298}, on_send=lambda line: self.set_devnum(9))
        b.key_for(4)
        self.assertEqual({"ok": True, "reply": "ok cycle 4 1000"}, b.handle({"op": "cycle", "slot": 4}))
        self.assertEqual(9, b.key_for(4).devnum)

    def test_wrong_key_after_power_on_is_switched_off(self):
        b = self.make({9: 22222222}, on_send=lambda line: self.set_devnum(9))
        self.set_devnum(1)          # key not identified before
        b.serials[1] = None
        with self.assertRaises(broker.BrokerError) as e:
            b.handle({"op": "power", "slot": 4, "state": "on"})
        self.assertIn("found key 22222222 instead of test key 38263298", str(e.exception))
        self.assertEqual(["power 4 on", "power 4 off"], b.fixture.sent)

    def test_busy_slot(self):
        b = self.make({7: 38263298})
        b.claim(4)
        with self.assertRaises(broker.BrokerError) as e:
            b.handle({"op": "cycle", "slot": 4})
        self.assertEqual("slot 4 is busy", str(e.exception))
        b.handle({"op": "touch", "slot": 4})    # a touch still works during a run

    def test_run_socket_is_restricted(self):
        b = self.make({7: 38263298})
        b.key_for(4)
        for req, message in (({"op": "power", "slot": 4, "state": "off"}, "not allowed from inside a test"),
                             ({"op": "cycle", "slot": 4}, "not allowed from inside a test"),
                             ({"op": "run", "sha": SHA, "slot": 4, "steps": [{"cycle": 1000}]}, "not allowed")):
            with self.assertRaises(broker.BrokerError) as e:
                b.handle(req, run_slot=4)
            self.assertIn(message, str(e.exception))
        b.handle({"op": "touch", "slot": 4}, run_slot=4)
        self.assertEqual({"4"}, set(b.handle({"op": "status"}, run_slot=4)["slots"]))


class ContainerTest(unittest.TestCase):
    def test_argv(self):
        argv = broker.container_argv(
            "sca-ykfx-x", "img", [("/dev/bus/usb/001/007", "/dev/bus/usb/001/007"), ("/dev/hidraw2", "/dev/hidraw2")],
            mounts=[("/w/src", "/src", True), ("/w/state", "/state", False),
                    ("/w/fixture.sock", broker.SESSION_SOCK, False)],
            env=[("YUBIKEY_FIXTURE_SLOT", 4), ("YUBIKEY_FIXTURE_SERIAL", 38263298)],
            workdir="/src", cmd=["test", "tests/hw/a.sh"])
        self.assertEqual(["docker", "run", "--rm", "--init", "--name", "sca-ykfx-x", "--network", "none",
                          "--cap-drop", "ALL", "--security-opt", "no-new-privileges", "--pids-limit", "256",
                          "--tmpfs", "/run", "--tmpfs", "/tmp",
                          "-v", "/w/src:/src:ro", "-v", "/w/state:/state",
                          "-v", "/w/fixture.sock:/run/services/yubikey-fixture.sock",
                          "-e", "YUBIKEY_FIXTURE_SLOT=4", "-e", "YUBIKEY_FIXTURE_SERIAL=38263298", "-w", "/src",
                          "--device", "/dev/bus/usb/001/007:/dev/bus/usb/001/007",
                          "--device", "/dev/hidraw2:/dev/hidraw2",
                          "img", "test", "tests/hw/a.sh"], argv)
        self.assertNotIn("--privileged", argv)

    def test_output_cap(self):
        out = broker.Output(cap=5)
        out.add("abc")
        out.add(b"defg")
        self.assertEqual(("abcde", True), (out.text(), out.truncated))


class GitTest(TempDir):
    """fetch, check_blob and extract against a local repository standing in for GitHub."""

    def git(self, *args):
        return subprocess.run(["git", "-C", self.origin, *args], check=True, capture_output=True,
                              text=True).stdout.strip()

    def setUp(self):
        super().setUp()
        self.origin = os.path.join(self.tmp, "origin")
        os.makedirs(self.origin)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "t")
        self.write("origin/tests/hw/a.sh", "echo a\n")
        os.symlink("a.sh", os.path.join(self.origin, "tests/hw/link.sh"))
        self.git("add", ".")
        self.git("commit", "-q", "-m", "one")
        self.on_main = self.git("rev-parse", "HEAD")
        self.git("checkout", "-q", "-b", "gone")
        self.git("commit", "-q", "--allow-empty", "-m", "two")
        self.on_gone = self.git("rev-parse", "HEAD")
        config = broker.Config({4: 1}, self.origin, "img", 60)
        self.broker = broker.Broker(config, None, None, cache_dir=os.path.join(self.tmp, "cache"))

    def test_fetch_and_extract(self):
        self.broker.fetch(self.on_main)
        self.broker.check_blob(self.on_main, "tests/hw/a.sh")
        dest = os.path.join(self.tmp, "src")
        os.mkdir(dest)
        self.broker.extract(self.on_main, dest)
        with open(os.path.join(dest, "tests/hw/a.sh")) as f:
            self.assertEqual("echo a\n", f.read())

    def test_commit_must_be_on_a_branch(self):
        self.broker.fetch(self.on_gone)     # fetched while the branch exists
        self.git("checkout", "-q", "main")
        self.git("branch", "-q", "-D", "gone")
        with self.assertRaises(broker.BrokerError) as e:
            self.broker.fetch(self.on_gone)
        self.assertIn("is not on any branch", str(e.exception))
        with self.assertRaises(broker.BrokerError):
            self.broker.fetch("f" * 40)

    def test_blob_checks(self):
        self.broker.fetch(self.on_main)
        for path in ("tests/hw/link.sh", "tests/hw/missing.sh", "tests/hw"):
            with self.assertRaises(broker.BrokerError) as e:
                self.broker.check_blob(self.on_main, path)
            self.assertIn("is not a file", str(e.exception))


FAKE_DOCKER = r"""#!/usr/bin/env python3
# stands in for docker: runs a test step on the host, with the run's mounts mapped
import os, signal, sys
args, mounts, env = sys.argv[1:], {}, dict(os.environ)
pids = os.environ["FAKE_DOCKER_PIDS"]
if args[0] == "kill":
    with open(os.path.join(pids, args[1])) as f:
        os.kill(int(f.read()), signal.SIGKILL)
    sys.exit(0)
i, name = 1, None
while not args[i] == "img":
    if args[i] == "-v":
        src, dst = args[i + 1].split(":")[:2]
        mounts[dst] = src
    elif args[i] == "-e":
        key, value = args[i + 1].split("=", 1)
        env[key] = value
    elif args[i] == "--name":
        name = args[i + 1]
    i += 1 if args[i] in ("--rm", "--init") else 2
cmd = args[i + 1:]
if cmd == ["probe"]:
    print(os.environ["FAKE_SERIAL"])
    sys.exit(0)
with open(os.path.join(pids, name), "w") as f:
    f.write(str(os.getpid()))
env["YUBIKEY_FIXTURE_SOCK"] = mounts["/run/services/yubikey-fixture.sock"]
env["STATE"] = mounts["/state"]
os.execvpe("bash", ["bash", os.path.join(mounts["/src"], cmd[1])], env)
"""

TESTS = {
    "touch.sh": 'yubikey-fixture touch "$YUBIKEY_FIXTURE_SLOT" 100 && echo "serial=$YUBIKEY_FIXTURE_SERIAL"\n'
                'echo marker > "$STATE/marker"\n',
    "after.sh": 'cat "$STATE/marker"\n',
    "power.sh": 'yubikey-fixture cycle "$YUBIKEY_FIXTURE_SLOT"\n',
    "fail.sh": 'echo failing; exit 3\n',
    "sleep.sh": 'sleep 30\n',
}


class EndToEndTest(FakeTree):
    """The client talks to a real broker server; a fake docker runs the steps on the host."""

    def setUp(self):
        super().setUp()
        origin = os.path.join(self.tmp, "origin")
        for name, text in TESTS.items():
            self.write(f"origin/tests/hw/{name}", text)
        for args in (["init", "-q", "-b", "main"], ["add", "."],
                     ["-c", "user.email=t@example.com", "-c", "user.name=t", "commit", "-q", "-m", "tests"]):
            subprocess.run(["git", "-C", origin, *args], check=True, capture_output=True)
        self.sha = subprocess.run(["git", "-C", origin, "rev-parse", "HEAD"], check=True, capture_output=True,
                                  text=True).stdout.strip()
        bin_dir = os.path.join(self.tmp, "bin")
        os.makedirs(os.path.join(self.tmp, "pids"))
        self.write("bin/docker", FAKE_DOCKER)
        os.chmod(os.path.join(bin_dir, "docker"), 0o755)
        try:
            subprocess.run([os.path.join(bin_dir, "docker"), "--version"], capture_output=True)
        except PermissionError:
            self.skipTest(f"{self.tmp} is mounted noexec: set TMPDIR to a folder that allows running programs")
        os.symlink(os.path.abspath(CLIENT), os.path.join(bin_dir, "yubikey-fixture"))
        self.sock = os.path.join(self.tmp, "broker.sock")
        self.env = dict(os.environ, PATH=bin_dir + os.pathsep + os.environ["PATH"], YUBIKEY_FIXTURE_SOCK=self.sock,
                        FAKE_SERIAL="38263298", FAKE_DOCKER_PIDS=os.path.join(self.tmp, "pids"))
        self.old_environ = dict(os.environ)
        os.environ.update(self.env)     # the broker's own docker calls use the fake too
        self.addCleanup(os.environ.update, self.old_environ)    # cleanups run last first
        self.addCleanup(os.environ.clear)
        config = broker.Config({4: 38263298}, origin, "img", 60)
        self.fixture = FakeFixture(on_send=lambda line: line.startswith("cycle") and self.set_devnum(9))
        b = broker.Broker(config, self.devices, self.fixture, cache_dir=os.path.join(self.tmp, "cache"))
        server = socketserver.ThreadingUnixStreamServer(self.sock, broker.Handler)
        server.daemon_threads = True
        server.broker = b
        server.run_slot = None
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.broker = b

    def client(self, *args):
        return subprocess.run([sys.executable, CLIENT, *args], env=self.env, capture_output=True, text=True,
                              timeout=60)

    def test_fixture_commands(self):
        result = self.client("touch", "4", "500")
        self.assertEqual((0, "ok touch 4 500\n"), (result.returncode, result.stdout))
        result = self.client("status")
        self.assertEqual(0, result.returncode)
        self.assertIn("slot 4: test key 38263298, present", result.stdout)

    def test_unconfigured_slot(self):
        result = self.client("touch", "5")
        self.assertEqual((125, "yubikey-fixture: slot 5 is not configured\n"), (result.returncode, result.stderr))

    def test_run_with_a_cycle(self):
        result = self.client("run", "tests/hw/touch.sh", self.sha, "4", "cycle=500", "tests/hw/after.sh")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("== step 0: tests/hw/touch.sh ==\nok touch 4 100\nserial=38263298\n"
                         "== step 1: cycle 500 ms ==\nbroker: slot 4 test key 38263298 is back\n"
                         "== step 2: tests/hw/after.sh ==\nmarker\n", result.stdout)
        self.assertEqual(["touch 4 100", "cycle 4 500"], self.fixture.sent)
        self.assertEqual(9, self.broker.key_for(4).devnum)
        self.assertEqual(set(), self.broker.workdirs)

    def test_test_cannot_power_the_key(self):
        result = self.client("run", "tests/hw/power.sh", self.sha, "4")
        self.assertEqual(125, result.returncode)
        self.assertIn("cycle is not allowed from inside a test", result.stdout)

    def test_failing_step_stops_the_run(self):
        result = self.client("run", "tests/hw/fail.sh", self.sha, "4", "tests/hw/touch.sh")
        self.assertEqual(3, result.returncode)
        self.assertEqual("== step 0: tests/hw/fail.sh ==\nfailing\n", result.stdout)

    def test_timeout(self):
        result = self.client("run", "--timeout", "1", "tests/hw/sleep.sh", self.sha, "4")
        self.assertEqual(124, result.returncode)
        self.assertIn("broker: the run timed out", result.stdout)

    def test_refusals(self):
        result = self.client("run", "tests/hw/missing.sh", self.sha, "4")
        self.assertEqual(125, result.returncode)
        self.assertIn("is not a file in commit", result.stderr)
        result = self.client("run", "tests/hw/touch.sh", "main", "4")
        self.assertEqual(125, result.returncode)
        self.assertIn("40-character", result.stderr)


if __name__ == "__main__":
    unittest.main()
