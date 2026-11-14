#!/bin/bash
# install: a package that fails to install, a missing .deb, or a system without
# apt must make sca install fail and say which packages are affected.
#
# apt-get, dpkg-query and sudo are stubbed as exported shell functions (see
# test_security_key_init.sh for why functions rather than scripts on PATH).
# the network probe reads /proc/net under SCA_INSTALL_ROOT, a fake root in
# $HOME/root, and its tcp connect goes through the timeout stub.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# nothing is installed yet, unless ALL_INSTALLED is set; apt-get records what
# it was asked to install and fails for any package named in APT_FAIL
dpkg-query() {
  [ -n "${ALL_INSTALLED:-}" ] && echo "install ok installed"
  [ -n "${ALL_INSTALLED:-}" ]
}
apt-get() {
  echo "$*" >> "$HOME/apt-get.log"
  local arg
  for arg in "$@"; do
    [[ " ${APT_FAIL:-} " == *" ${arg} "* ]] && return 100
  done
  return 0
}
apt-add-repository() {
  return 0
}
# sudo records each call in ~/sudo.log and on stderr, so a test can see both
# whether it ran and what was printed just before it
sudo() {
  echo "$*" >> "$HOME/sudo.log"
  echo "sudo: $*" >&2
  "$@"
}
# the probe's tcp connect: recorded in ~/probe.log, fails when PROBE_FAIL is set
timeout() {
  echo "$*" >> "$HOME/probe.log"
  [ -z "${PROBE_FAIL:-}" ]
}
export -f dpkg-query apt-get apt-add-repository sudo timeout
export SCA_INSTALL_ROOT="$HOME/root"

# sca refuses most commands, install with options included, until a config
# exists, so each case starts from a fresh home with the default config, and
# a fake root with an ipv4 default route and no /opt/sca
reset_home() {
  rm -rf "${HOME:?}"/* "${HOME}"/.[!.]*
  sca config create all > /dev/null 2>&1 || fail "config create all"
  mkdir -p "$SCA_INSTALL_ROOT/proc/net"
  no_route
  printf 'eth0\t00000000\t010011AC\t0003\t0\t0\t0\t00000000\t0\t0\t0\n' \
    >> "$SCA_INSTALL_ROOT/proc/net/route"
  # the unreachable ::/0 route the kernel keeps on lo is not a way out
  echo '00000000000000000000000000000000 00 00000000000000000000000000000000 00 00000000000000000000000000000000 ffffffff 00000001 00000000 00200200       lo' \
    > "$SCA_INSTALL_ROOT/proc/net/ipv6_route"
}
# no_route - leaves the fake root without a default route
no_route() {
  printf 'Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n' \
    > "$SCA_INSTALL_ROOT/proc/net/route"
}
# sca_image - adds the /opt/sca layout of a booted sca image to the fake root
sca_image() {
  mkdir -p "$SCA_INSTALL_ROOT/opt/sca/bin" "$SCA_INSTALL_ROOT/opt/sca/packages"
  touch "$SCA_INSTALL_ROOT/opt/sca/bin/sca"
}

# a successful run installs sca and exits 0, as before
reset_home
assert_succeeds sca install --yubikey-support
assert_file_exists "$HOME/bin/sca" "sca copied to ~/bin"
grep -q 'install -y ykcs11' "$HOME/apt-get.log" 2>/dev/null \
  || fail "ykcs11 was not installed with --yubikey-support"
grep -q 'install -y yubikey-manager' "$HOME/apt-get.log" 2>/dev/null \
  || fail "yubikey-manager was not installed with --yubikey-support"
grep -q 'install -y gnupg' "$HOME/apt-get.log" 2>/dev/null \
  || fail "gnupg was not installed with --yubikey-support"
grep -q 'install -y libfido2-1' "$HOME/apt-get.log" 2>/dev/null \
  && fail "fido2 packages are only installed with --fido2"

# --openpgp and --fido2 install their package sets and yubikey-manager, once
reset_home
assert_succeeds sca install --openpgp --fido2
for package in gnupg scdaemon pcscd openssh-client libfido2-1 yubikey-manager; do
  grep -q "install -y ${package}\$" "$HOME/apt-get.log" 2>/dev/null \
    || fail "${package} was not installed with --openpgp --fido2"
done
[ "$(grep -c 'install -y yubikey-manager$' "$HOME/apt-get.log")" -eq 1 ] \
  || fail "yubikey-manager is installed once"
grep -q 'install -y ykcs11' "$HOME/apt-get.log" \
  && fail "PIV packages are only installed with --yubikey-support"
[ ! -e "$HOME/.gnupg/scdaemon.conf" ] \
  || fail "scdaemon.conf is not written without --configure-scdaemon"

# --fido2 warns when OpenSSH is older than 8.2
reset_home
output="$(ssh() { echo 'OpenSSH_7.6p1 Ubuntu-4, OpenSSL 1.0.2n' >&2; }
  export -f ssh; sca install --fido2 2>&1)" || fail "old OpenSSH is a warning only"
[[ "${output}" == *"OpenSSH 7.6 is installed"*"need OpenSSH 8.2 or later"* ]] \
  || fail "old OpenSSH is warned about: ${output}"
output="$(ssh() { echo 'OpenSSH_9.6p1 Ubuntu-3ubuntu13' >&2; }
  export -f ssh; sca install --fido2 --force 2>&1)"
[[ "${output}" != *"need OpenSSH 8.2"* ]] || fail "no warning on OpenSSH 9.6: ${output}"

# --openpgp with PIV support only prints the scdaemon.conf lines. pcsc-shared
# is offered even though gpgconf doesn't list it, as on gnupg 2.4.8
gpgconf() {
  [ "$*" = '--list-options scdaemon' ] && echo 'disable-ccid:16:1:...'
  return 0
}
export -f gpgconf
reset_home
output="$(sca install --openpgp --yubikey-support 2>&1)" \
  || fail "install --openpgp --yubikey-support: ${output}"
[[ "${output}" == *"disable-ccid"*"pcsc-shared"*"--configure-scdaemon"* ]] \
  || fail "scdaemon.conf lines are offered: ${output}"
[ ! -e "$HOME/.gnupg/scdaemon.conf" ] \
  || fail "scdaemon.conf is not written without --configure-scdaemon"

# --configure-scdaemon appends what is missing, keeps the rest, and is idempotent
reset_home
mkdir -p "$HOME/.gnupg"
printf 'reader-port Yubico\ndisable-ccid\n' > "$HOME/.gnupg/scdaemon.conf"
assert_succeeds sca install --openpgp --configure-scdaemon
assert_succeeds sca install --openpgp --configure-scdaemon --force
assert_eq "$(printf 'reader-port Yubico\ndisable-ccid\npcsc-shared')" \
  "$(cat "$HOME/.gnupg/scdaemon.conf")" "scdaemon.conf after two runs"
# a last line without a trailing newline is kept intact
reset_home
mkdir -p "$HOME/.gnupg"
printf 'reader-port Yubico' > "$HOME/.gnupg/scdaemon.conf"
assert_succeeds sca install --openpgp --configure-scdaemon
assert_eq "$(printf 'reader-port Yubico\ndisable-ccid\npcsc-shared')" \
  "$(cat "$HOME/.gnupg/scdaemon.conf")" "scdaemon.conf without a trailing newline"
# --dry-run says what it would add and leaves scdaemon.conf alone
reset_home
mkdir -p "$HOME/.gnupg"
printf 'reader-port Yubico\n' > "$HOME/.gnupg/scdaemon.conf"
output="$(sca install --openpgp --configure-scdaemon --dry-run 2>&1)" \
  || fail "install --openpgp --configure-scdaemon --dry-run: ${output}"
[[ "${output}" == *"would add to "*"scdaemon.conf: disable-ccid pcsc-shared"* ]] \
  || fail "dry run names the scdaemon.conf lines: ${output}"
assert_eq 'reader-port Yubico' "$(cat "$HOME/.gnupg/scdaemon.conf")" \
  "scdaemon.conf after a dry run"
unset -f gpgconf

# --configure-scdaemon without --openpgp is refused before anything is installed
reset_home
assert_fails sca install --configure-scdaemon
[ ! -e "$HOME/apt-get.log" ] || fail "nothing is installed for --configure-scdaemon alone"

# one package fails: the rest are still attempted, the run fails and names it
reset_home
output="$(APT_FAIL="ykcs11 opensc" sca install --yubikey-support 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "install exits non-zero when a package fails"
[[ "${output}" == *"ykcs11 - retry with: sudo apt-get install -y ykcs11"* ]] \
  || fail "failure message names ykcs11 and the retry command: ${output}"
[[ "${output}" == *"opensc - retry with: sudo apt-get install -y opensc"* ]] \
  || fail "all failures are reported together: ${output}"
grep -q 'install -y apt-mirror' "$HOME/apt-get.log" 2>/dev/null \
  || fail "packages after the failed one are still attempted"

# every package is listed, and its name is printed right before sudo runs
reset_home
output="$(sca install 2>&1)"
[[ "${output}" == *"checking prerequisite packages:"* ]] \
  || fail "the package checks are announced: ${output}"
[[ "${output}" == *"  openssl: not installed, installing (sudo apt-get install -y openssl)"$'\n'"sudo: apt-get install -y openssl"* ]] \
  || fail "the package is named before sudo runs: ${output}"

# sca already installed and every package present: the packages are listed as
# skipped, the message says the checks go on, and sudo is never run
reset_home
sca install > /dev/null 2>&1
rm -f "$HOME/sudo.log"
output="$(ALL_INSTALLED=1 sca install 2>&1)"
status=$?
assert_eq 0 "${status}" "install on a provisioned host exits 0"
[[ "${output}" == *"skipping the sca script step"*"prerequisite checks continue."* ]] \
  || fail "already-installed message says the checks continue: ${output}"
[[ "${output}" == *"  openssl: already installed, skipping"* ]] \
  || fail "skipped packages are listed: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "sudo is not run on a provisioned host: $(cat "$HOME/sudo.log")"

# --dry-run: the missing packages are listed as would-install, exit 0, and
# nothing is run with sudo or written to ~/bin and ~/.bashrc
reset_home
output="$(sca install --dry-run --yubikey-support 2>&1)"
status=$?
assert_eq 0 "${status}" "dry run exits 0"
[[ "${output}" == *"  ykcs11: not installed, would install (sudo apt-get install -y ykcs11)"* ]] \
  || fail "dry run lists the missing package: ${output}"
[[ "${output}" == *"dry run: nothing was installed or changed."* ]] \
  || fail "dry run says nothing changed: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "dry run runs no sudo: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "dry run does not touch ~/bin"
[ ! -e "$HOME/.bashrc" ] || fail "dry run does not edit ~/.bashrc"

# -n works offline too: a host without the sca image layout and a missing .deb
# do not fail the dry run
reset_home
output="$(sca install -n --air-gapped 2>&1)"
status=$?
assert_eq 0 "${status}" "offline dry run exits 0: ${output}"
[[ "${output}" == *"would fail: sca install: this host was not booted from an sca image"* ]] \
  || fail "offline dry run reports the missing layout: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "offline dry run runs no sudo: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "offline dry run does not touch ~/bin"

# online with no default route: one message naming --air-gapped, no tcp probe,
# no package attempts, and ~/bin and ~/.bashrc are left alone
online_no_network="no network is reachable, so packages can't be installed \
from the repositories. on an air-gapped sca image, run 'sca install \
--air-gapped' instead. nothing was installed."
reset_home
no_route
output="$(sca install 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "online install without a route exits non-zero"
[[ "${output}" == *"${online_no_network}"* ]] \
  || fail "no network names --air-gapped: ${output}"
[[ "${output}" != *"checking prerequisite packages"* ]] \
  || fail "no package is attempted without a network: ${output}"
[ ! -e "$HOME/probe.log" ] || fail "no tcp probe without a default route"
[ ! -e "$HOME/sudo.log" ] || fail "no sudo without a network: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "nothing is written to ~/bin without a network"
[ ! -e "$HOME/.bashrc" ] || fail "nothing is written to ~/.bashrc without a network"
# an ipv6 default route on a real interface counts as a route
reset_home
no_route
echo '00000000000000000000000000000000 00 00000000000000000000000000000000 00 fe800000000000000000000000000001 00000400 00000001 00000000 00450003     eth0' \
  >> "$SCA_INSTALL_ROOT/proc/net/ipv6_route"
assert_succeeds sca install
assert_file_exists "$HOME/probe.log" "an ipv6 default route is probed"

# online with a route but a failed tcp connect: the same, after a capped probe
reset_home
output="$(PROBE_FAIL=1 sca install 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "online install with a failed probe exits non-zero"
[[ "${output}" == *"${online_no_network}"* ]] \
  || fail "failed probe names --air-gapped: ${output}"
grep -q '^3 bash -c : > /dev/tcp/archive.ubuntu.com/80$' "$HOME/probe.log" 2>/dev/null \
  || fail "the tcp probe is capped at 3 seconds: $(cat "$HOME/probe.log" 2>/dev/null)"
[ ! -e "$HOME/sudo.log" ] || fail "no sudo after a failed probe: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "nothing is written to ~/bin after a failed probe"

# dry runs of both report would fail and exit 0
reset_home
no_route
output="$(sca install -n 2>&1)"
status=$?
assert_eq 0 "${status}" "online dry run without a route exits 0: ${output}"
[[ "${output}" == *"would fail: sca install: ${online_no_network}"* ]] \
  || fail "online dry run without a route says would fail: ${output}"
reset_home
output="$(PROBE_FAIL=1 sca install -n 2>&1)"
status=$?
assert_eq 0 "${status}" "online dry run with a failed probe exits 0: ${output}"
[[ "${output}" == *"would fail: sca install: ${online_no_network}"* ]] \
  || fail "online dry run with a failed probe says would fail: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "online dry run runs no sudo: $(cat "$HOME/sudo.log")"

# offline on a host that was not booted from an sca image: fails, naming the
# missing paths, before sudo runs
reset_home
output="$(sca install --air-gapped 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "offline install without /opt/sca exits non-zero"
[[ "${output}" == *"this host was not booted from an sca image"*"${SCA_INSTALL_ROOT}/opt/sca/bin/sca"*"${SCA_INSTALL_ROOT}/opt/sca/packages/"*"nothing was installed."* ]] \
  || fail "missing sca image layout is named: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "no sudo without the sca image: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "nothing is written to ~/bin without the sca image"

# offline on an sca image that can reach the network: warns on stderr, and the
# install goes on and succeeds
reset_home
sca_image
touch "$SCA_INSTALL_ROOT/opt/sca/packages/openssl.deb"
output="$(sca install --air-gapped 2>&1 > /dev/null)"
status=$?
assert_eq 0 "${status}" "offline install with a network exits 0: ${output}"
[[ "${output}" == *"sca install: warning: this host can reach the network. an air-gapped sca appliance should not."* ]] \
  || fail "a reachable network is warned about on stderr: ${output}"
grep -q 'openssl.deb' "$HOME/apt-get.log" 2>/dev/null \
  || fail "the install goes on after the warning"
# offline on an sca image with no network: no warning
reset_home
sca_image
touch "$SCA_INSTALL_ROOT/opt/sca/packages/openssl.deb"
no_route
output="$(sca install --air-gapped 2>&1)"
status=$?
assert_eq 0 "${status}" "offline install without a network exits 0: ${output}"
[[ "${output}" != *"warning"* ]] || fail "no warning without a network: ${output}"

# offline: a sca usb stick without its packages is an error
offline_packages="${SCA_INSTALL_ROOT}/opt/sca/packages/"
reset_home
sca_image
output="$(sca install --air-gapped 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "offline install exits non-zero when the .deb files are missing"
[[ "${output}" == *"no .deb files in ${offline_packages}"* ]] \
  || fail "missing .deb files are reported: ${output}"
# the openpgp and fido2 sets must be installed after the stick's .deb files
reset_home
sca_image
output="$(sca install --air-gapped --openpgp 2>&1)"
[[ "${output}" == *"scdaemon - not installed and not among the .deb files in ${offline_packages}"* \
  && "${output}" == *"yubikey-manager - not installed"* ]] \
  || fail "missing openpgp packages are named: ${output}"
# a package the live image already ships is not a failure
reset_home
sca_image
output="$(dpkg-query() {
    [ "${*: -1}" = openssh-client ] && echo 'install ok installed' && return 0
    return 1
  }
  export -f dpkg-query; sca install --air-gapped --fido2 2>&1)"
[[ "${output}" == *"libfido2-1 - not installed"* ]] \
  || fail "missing fido2 package is named: ${output}"
[[ "${output}" != *"openssh-client - not installed"* ]] \
  || fail "an installed package is not reported missing offline: ${output}"

# no apt-get / dpkg-query: fail before touching ~/bin, listing the packages.
# PATH is a folder linking every tool except those two.
reset_home
no_apt_bin="$(mktemp -d "${TMPDIR:-/tmp}/sca-test-bin.XXXXXX")" || exit 2
# shellcheck disable=SC2154 # test_home is set by lib.sh
trap 'rm -rf "${test_home}" "${no_apt_bin}"' EXIT
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin; do
  for tool in "${dir}"/*; do
    case "${tool##*/}" in apt-get | dpkg-query ) continue ;; esac
    [ -e "${no_apt_bin}/${tool##*/}" ] || ln -s "${tool}" "${no_apt_bin}/${tool##*/}"
  done
done
output="$(unset -f apt-get dpkg-query; PATH="${no_apt_bin}" sca install --yubikey-support 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "install exits non-zero without apt-get"
[ ! -e "$HOME/bin" ] || fail "\$HOME/bin is not touched without apt-get"
[[ "${output}" == *"ykcs11"* && "${output}" == *"opensc"* && "${output}" == *"datefudge"* ]] \
  || fail "required packages are listed: ${output}"
[[ "${output}" == *"docs/ssh-yubikey-options.md"* ]] \
  || fail "platform docs are referenced: ${output}"
[ ! -e "$HOME/apt-get.log" ] || fail "nothing is installed without apt-get"

test_done
