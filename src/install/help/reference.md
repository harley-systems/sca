Automatic installs support apt-based systems (Ubuntu, Debian) only. Without
`apt-get` and `dpkg-query`, `sca install` stops before changing anything and
lists the packages the selected options need, so you can install them with your
own package manager (see the platform tables in
[SSH with a YubiKey](../ssh-yubikey-options.md#packages) and
[YubiKey Setup](../yubikey.md#prerequisites)).

Every package is attempted. If any fails to install (or, with `-a`, its `.deb`
is missing from the USB stick), `sca install` lists each failed package with the
command to retry and exits non-zero.

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
- `libengine-pkcs11-openssl` - PKCS#11 OpenSSL engine
- `yubico-piv-tool` - YubiKey management (with `-y`)
- `squashfs-tools`, `genisoimage`, `qemu-kvm` - USB image creation
