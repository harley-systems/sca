Automatic installs support apt-based systems (Ubuntu, Debian) only. Without
`apt-get` and `dpkg-query`, `sca install` stops before changing anything and
lists the packages the selected options need, so you can install them with your
own package manager (see the platform tables in
[SSH with a YubiKey](../ssh-yubikey-options.md#packages) and
[YubiKey Setup](../yubikey.md#prerequisites)).

Before installing anything, `sca install` checks that its mode fits the host:

- Online (the default) needs a network. With no default route, or when a TCP
  connection to `archive.ubuntu.com:80` fails within 3 seconds, it stops with
  one message suggesting `sca install --air-gapped`, without running `apt-get`.
- `-a` needs a booted SCA image. Without `/opt/sca/bin/sca` and
  `/opt/sca/packages/` it stops and says the host was not booted from one.
- `-a` on a host that can reach the network prints a warning and goes on: an
  air-gapped appliance should not reach one.

With `-n`, a failing check is printed as `would fail: ...` and the dry run goes
on.

Every package is attempted. If any fails to install, `sca install` lists each
failed package with the command to retry and exits non-zero. With `-a`, the
`.deb` files on the USB stick are installed together, and a failure (or a stick
with no `.deb` files) is reported the same way.

**Examples:**

```bash
# Online installation with YubiKey support
sca install --yubikey-support

# Offline installation (from SCA USB stick)
sca install --air-gapped

# Force reinstall
sca install --force
```

**Installed packages (online mode):**
- `openssl`, `openssh-client` - Core crypto tools
- `datefudge` - For backdating CA certificates
- `opensc`, `pcscd`, `libccid` - Smart card support
- `libengine-pkcs11-openssl`, `pkcs11-provider` - PKCS#11 OpenSSL engine and provider
- `yubico-piv-tool`, `ykcs11`, `yubikey-manager`, `gnupg`, `scdaemon` - YubiKey tools (with `-y`), from the Ubuntu archive
- `xorriso`, `squashfs-tools`, `apt-mirror`, `qemu-system-x86`, `qemu-utils` - USB image creation and testing
