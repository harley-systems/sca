# Air-Gapped Operations

[← Back to README](../README.md)

Guide for creating and using a secure offline environment for root CA operations.

## Overview

For maximum security, root CA private keys should never touch a networked system. SCA provides tools to create a bootable USB stick that runs a complete offline environment with all prerequisites pre-installed.

### Why Air-Gapped?

- **Root CA protection**: The root CA key is the crown jewel of your PKI. If compromised, all certificates become untrustworthy.
- **No network exposure**: An air-gapped system cannot be remotely attacked.
- **Physical security**: Operations require physical presence and access.
- **Audit trail**: All operations happen in a controlled, observable environment.

## Creating the SCA USB Stick

### Prerequisites

The image is built from **Ubuntu 26.04 LTS (`26.04-resolute`)**, and only on
an **Ubuntu 26.04 host**. That is the only supported version, both for the
image and for the build host. On any other host `sca init sca_usb_stick` fails
before downloading anything. The packages bundled on the stick are resolved
with the host's apt sources, so the host's sources must include the `universe`
component (the Ubuntu default).

On your online Ubuntu 26.04 system, install SCA together with the image
creation tools (add `--yubikey-support` if you will use YubiKeys):

```bash
sca install --yubikey-support
```

An online `sca install` also installs:
- `xorriso` - For creating the hybrid BIOS and UEFI ISO image
- `squashfs-tools` - For reading and packing Ubuntu filesystem layers
- `apt-mirror` - For offline package repositories
- `qemu-system-x86`, `qemu-utils` - For testing images

### Create the Bootable Image

```bash
sca init sca_usb_stick [options] [ubuntu_version_id]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-y, --yubikey-support` | Include YubiKey/Yubico packages |
| `-i, --include-apt-mirror` | Mirror apt repositories for offline installation |
| `-x, --exclude-pkcs11-support` | Skip PKCS#11 packages |
| `-t, --test-image` | Create test variant for automated testing |
| `-s, --skip-cleanup` | Keep intermediate files after build |
| `-o, --no-cache-iso` | Remove the downloaded Ubuntu ISO after the build |
| `-n, --no-cache` | Disable all caching (same as `--no-cache-iso`) |

**Supported Ubuntu version:** `26.04-resolute` only, which is also the default.
Any other version id fails with an error that names the supported one. The
latest 26.04 point release is downloaded from `releases.ubuntu.com` (falling
back to `old-releases.ubuntu.com`) and checked against the published
`SHA256SUMS`, whose signature is checked first. A cached ISO in
`~/.sca/downloads/` is reused once it passes the same check. See
[Verifying the Ubuntu ISO](#verifying-the-ubuntu-iso).

### Verifying the Ubuntu ISO

Every key generated on the stick is only as safe as the ISO it was built from,
so `sca init sca_usb_stick` checks the ISO before using it:

1. It downloads `SHA256SUMS` and `SHA256SUMS.gpg` over HTTPS into
   `~/.sca/downloads/` (as `ubuntu-26.04-SHA256SUMS` and
   `ubuntu-26.04-SHA256SUMS.gpg`).
2. It checks the signature with `gpgv` against the **Ubuntu CD Image Automatic
   Signing Key**, which is bundled in sca and pinned by its fingerprint,
   `843938DF228D22F7B3742BC0D94AA3F0EFE21092`. The key is never fetched from a
   keyserver.
3. It checks the ISO against its line in the signed `SHA256SUMS`.

When it is offline, it uses the previously downloaded `SHA256SUMS` and
`SHA256SUMS.gpg`, but only after checking the signature again.

Each failure stops the build before anything is mounted or written, with its
own error:

| Failure | What happens |
|---------|--------------|
| `SHA256SUMS` was modified | "... does not match its signature: it was modified". `SHA256SUMS` and its signature are removed |
| `SHA256SUMS.gpg` can't be downloaded | "could not download ...SHA256SUMS.gpg". Nothing is kept |
| The signature is corrupt or made by an unknown key | "the signature ... could not be checked". Both files are removed |
| The signature is good but made by another key | "... is signed by `<fingerprint>`, not by the ubuntu cd image signing key". Both files are removed |
| A cached `SHA256SUMS` has no signature (from an older sca) | "... has no signature file". It is removed; run again online |
| The downloaded ISO doesn't match | "the downloaded ... does not match the signed SHA256SUMS". The ISO is removed |
| An ISO already in `~/.sca/downloads/` doesn't match | "the local image ... does not match the signed SHA256SUMS". The ISO is left for you to inspect or remove |

An ISO you download yourself can be used by putting it in `~/.sca/downloads/`
under its published name. It is checked like any other.

To check an ISO by hand, with the keyring from the sca source tree
(`src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc`):

```bash
cd ~/.sca/downloads
gpg --dearmor < ubuntu-cdimage-keyring.asc > ubuntu-cdimage-keyring.gpg
gpgv --keyring ./ubuntu-cdimage-keyring.gpg ubuntu-26.04-SHA256SUMS.gpg ubuntu-26.04-SHA256SUMS
# expect: Good signature from "Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>"
#         using RSA key 843938DF228D22F7B3742BC0D94AA3F0EFE21092
sha256sum -c --ignore-missing ubuntu-26.04-SHA256SUMS
# expect: ubuntu-26.04.x-desktop-amd64.iso: OK
```

#### Updating the bundled key

The key lives in `src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc`, and the
build embeds it in `sca`. Its fingerprint is pinned in
`get_ubuntu_cdimage_signing_key_fingerprint` in
`src/init/sca_usb_stick/init_sca_usb_stick.sh`. If Ubuntu renews or replaces
the key:

1. Check the new fingerprint against Ubuntu's own announcement, for example
   <https://ubuntu.com/tutorials/how-to-verify-ubuntu>.
2. Export only the key and its self-signatures:

   ```bash
   export GNUPGHOME=$(mktemp -d)
   gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys <fingerprint>
   gpg --armor --export --export-options export-minimal <fingerprint> \
     > src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc
   gpg --show-keys src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc
   ```

3. Update the pinned fingerprint and the fingerprint in this page, run
   `make check`, and check a freshly downloaded `SHA256SUMS` with the manual
   check above.

### Tools on the stick

| Tool | Package | Version in the 26.04 archive |
|------|---------|------------------------------|
| OpenSSL | `openssl` (in the live image) | 3.5.x |
| PKCS#11 provider for OpenSSL 3 | `pkcs11-provider` | 1.2.0 |
| PKCS#11 engine for OpenSSL | `libengine-pkcs11-openssl` | 0.4.18 |
| OpenSC | `opensc`, `opensc-pkcs11` | 0.27.0 |
| PC/SC daemon and CCID driver | `pcscd`, `libccid` | 2.4.1, 1.7.1 |
| YubiKey PIV tool and PKCS#11 module | `yubico-piv-tool`, `ykcs11` | 2.7.2 |
| YubiKey Manager (`ykman`) | `yubikey-manager` | 5.8.0 |
| GnuPG with smart card daemon | `gnupg`, `scdaemon` | 2.4.8 |
| datefudge | `datefudge` | 1.27 |

The PKCS#11, OpenSC and PC/SC packages are left out with `-x`. The YubiKey and
GnuPG packages are only bundled with `-y`. All of them come from the Ubuntu
archive; the Yubico PPA is not used. Packages that have newer versions in
`resolute-updates` are bundled at that newer version.

### Example: Full Offline Environment

```bash
# Create USB image with YubiKey support and offline packages
sca init sca_usb_stick --yubikey-support --include-apt-mirror
```

This process:
1. Downloads the Ubuntu 26.04 desktop ISO (~6GB) and checks it against the
   signed `SHA256SUMS`
2. Reads the package list of the ISO's live filesystem
3. Adds sca and configuration in a new squashfs layer
   (`casper/minimal.standard.live.sca.squashfs`) on top of the live layer,
   so the original filesystem is not repacked
4. Downloads the packages, and the dependencies, the live session is missing
5. Optionally mirrors apt repositories
6. Patches GRUB to boot straight into the live session with the sca layer
7. Writes `ubuntu-26.04.x-desktop-amd64.sca.iso` with `xorriso`, replaying the
   original BIOS and UEFI boot setup, so the image stays USB-bootable

### Write to USB

After creation, write the image to a USB stick:

```bash
# Identify your USB device (BE CAREFUL - wrong device = data loss)
# a usb stick usually shows TRAN=usb, RM=1
lsblk -do NAME,TRAN,RM,SIZE,MODEL -e 7

# Unmount if mounted
sudo umount /dev/sdX1

# Write image (replace sdX with your device)
sudo dd bs=4M if=~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca.iso of=/dev/sdX conv=fdatasync
```

## Using the Air-Gapped Environment

### Boot Sequence

1. Insert USB stick into air-gapped computer
2. Boot from USB (may need to adjust BIOS/UEFI boot order)
3. System boots directly into Ubuntu live session
4. On first boot, sca automatically installs packages from USB

> **ROCK64 (ARM).** A ROCK64 boots the SCA image from microSD as it is. To boot
> it from a USB stick, U-Boot must first be written to the board's SPI flash.
> See [USB Boot on ARM](usb-boot-on-arm.md).

### First-Time Setup

The live environment automatically:
1. Configures apt to use local package mirror (if included)
2. Installs the packages bundled in `/opt/sca/packages/` (see [Tools on the stick](#tools-on-the-stick))
3. Sets up sca in the live user environment

### Root CA Operations

#### Create Root CA

```bash
# Configure CA parameters
sca config set ca mycompany
sca config set domain .mycompany.com

# Generate root CA key (stays on air-gapped system)
sca create key ca

# Create self-signed root certificate
sca create crt ca
```

#### Sign Sub-CA Certificate

When a sub-CA CSR is brought in (via second USB):

```bash
# Mount the transfer USB
sudo mount /dev/sdb1 /mnt

# Import the CSR
sca import csr subca /mnt/subca-csr.tar.gz

# Review and approve
sca display csr subca
sca approve subca

# Create signed certificate
sca create crt subca

# Export for transfer back
sca export crt subca
cp ~/.sca/transfer/* /mnt/

sudo umount /mnt
```

### Data Transfer

Use separate USB sticks for transferring data:

1. **Transfer USB**: For moving CSRs in and certificates out
2. **SCA USB**: Boot medium (never use for data transfer)
3. **Backup USB**: For backing up the root CA (encrypted, stored securely)

**Never connect the air-gapped system to any network.**

## Directory Structure

On the live USB, sca files are located at:

| Path | Contents |
|------|----------|
| `/opt/sca/bin/sca` | The sca executable |
| `/opt/sca/packages/` | Pre-downloaded .deb packages |
| `/opt/sca/apt-mirror/` | Mirrored apt repositories (if included) |
| `/etc/ssl/sca/` | Default sca configuration, copied from the build machine's `~/.sca/config/` (`*.config`, `*.conventions`, `*.ini`; no backups) |
| `/etc/systemd/user/ubuntu-desktop-installer.service` | Masked (`-> /dev/null`), so the live session does not open the Ubuntu installer wizard (the installer's backend, `subiquity-server`, still runs in the background) |
| `~/.sca/` | Runtime configuration and keys |

## Testing

### Automated Testing

SCA can test the air-gapped image using QEMU:

```bash
sca test [ubuntu_version_id]
```

This:
1. Runs the checks below on this machine
2. Rebuilds the test variant of the USB image for `ubuntu_version_id`
   (`sca init sca_usb_stick --test-image --yubikey-support`), so it carries the
   currently deployed sca (`make deploy` first)
3. Boots it in QEMU with no network (`-net none`; needs KVM and sudo)
4. Runs the same checks inside the VM, which writes `results.txt` and its log
   to a virtual test disk and powers off. `sca test` formats that disk on the
   host with the filesystem label `sca-test-results`; the guest only mounts a
   disk carrying that label and never partitions or formats anything
5. Prints the guest's results and removes the test disk image

Each check prints `PASS <check>` or `FAIL <check>`:

1. `init demo` completes (in `~/.sca/test/demo/`, on a copy of your config, never using a security key)
2. a service key, CSR and certificate issued by the demo sub-CA pass `openssl verify` against the demo chain
3. `openssl version` is 3 or newer
4. the pkcs11 engine and OpenSC module files named in the config exist
5. `pcscd` is installed
6. `ykcs11` is installed (the `ykcs11_module` file exists)
7. `ykman` runs, if it is installed (otherwise reported as `SKIP`)

`sca test` exits with 0 when every check passed, and 1 when any check failed or
the VM left no results (for example, it never booted). Details are in
`~/.sca/log`. Use `sca test --skip-air-gapped-tests` to run only the checks on
this machine.

### Manual Testing

Test the image before real use:

```bash
# Create test image
sca init sca_usb_stick --test-image --yubikey-support

# Boot in QEMU (no network)
sudo qemu-system-x86_64 \
  -boot d \
  -enable-kvm \
  -m 2048 \
  -cpu host \
  -net none \
  -drive format=raw,file=~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca-test.iso
```

To boot the image in UEFI mode, add the OVMF firmware (package `ovmf`):

```bash
sudo qemu-system-x86_64 -boot d -enable-kvm -m 4096 -cpu host -net none \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive format=raw,file=~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca.iso
```

On login the test image looks for a disk with the filesystem label
`sca-test-results`. Without one (as above) it logs that to `~/.sca/log`, runs no
tests, touches no disk and stays up. To have it run the tests, write the
results and shut down, attach a labelled disk:

```bash
qemu-img create /tmp/sca-test-disk.img 10M
mkfs.ext4 -F -L sca-test-results /tmp/sca-test-disk.img
# then add to the qemu command above:
#   -drive format=raw,file=/tmp/sca-test-disk.img,index=1
```

## Security Considerations

### Physical Security

- Store the air-gapped computer in a secure location
- Control physical access to the room
- Consider tamper-evident seals on the computer case

### USB Stick Security

- Use dedicated, new USB sticks
- Label them clearly (SCA Boot, Transfer, Backup)
- Store backup USB in a separate secure location (safe, vault)
- Consider encrypted USB drives for backups

### Operational Security

- Document all operations performed
- Require multiple authorized personnel for root CA operations
- Verify CSRs before signing (check subject, extensions)
- Keep a physical log book

### Key Backup

The root CA private key must be backed up securely:

```bash
# On the air-gapped system
tar -czf /mnt/backup/root-ca-backup-$(date +%Y%m%d).tar.gz ~/.sca/keys/

# Encrypt the backup
gpg --symmetric --cipher-algo AES256 root-ca-backup-*.tar.gz
```

Store multiple encrypted copies in different secure locations.

## Troubleshooting

### USB Not Booting

1. Check BIOS/UEFI boot order
2. Disable Secure Boot if enabled
3. Try different USB port (USB 2.0 ports often more compatible)
4. On a ROCK64, USB boot needs U-Boot in SPI flash first: see [USB Boot on ARM](usb-boot-on-arm.md)

### Packages Not Installing

If packages fail to install offline:

```bash
# Check if packages are present
ls /opt/sca/packages/

# Manual installation
sudo dpkg -i /opt/sca/packages/*.deb
sudo apt-get install -f
```

### YubiKey Not Detected

```bash
# Restart pcscd
sudo systemctl restart pcscd

# Check detection
ykman info
```

---

## See Also

- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [Procedures](procedures.md) - Certificate procedures
- [Command Reference](commands.md) - All sca commands
- [USB Boot on ARM](usb-boot-on-arm.md) - Booting a ROCK64 from USB via SPI flash
