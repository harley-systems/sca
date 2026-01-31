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

On your online system, install the image creation tools:

```bash
sca install prerequisites
```

This installs:
- `squashfs-tools` - For unpacking/packing Ubuntu filesystem
- `genisoimage` - For creating ISO images
- `syslinux-utils` - For making bootable USB images
- `apt-mirror` - For offline package repositories
- `qemu-kvm` - For testing images

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
| `-n, --no-cache` | Do not cache squashfs (slower but uses less disk) |

**Supported Ubuntu versions:**
- 18.04.1-bionic (default)
- 16.04.x-xenial
- 14.04.x-trusty

### Example: Full Offline Environment

```bash
# Create USB image with YubiKey support and offline packages
sca init sca_usb_stick --yubikey-support --include-apt-mirror
```

This process:
1. Downloads Ubuntu live ISO (~2GB)
2. Extracts the squashfs filesystem
3. Adds sca and configuration
4. Downloads required packages for offline installation
5. Optionally mirrors apt repositories
6. Creates modified ISO with auto-boot to live session
7. Makes the ISO USB-bootable (isohybrid)

### Write to USB

After creation, write the image to a USB stick:

```bash
# Identify your USB device (BE CAREFUL - wrong device = data loss)
lsblk

# Unmount if mounted
sudo umount /dev/sdX1

# Write image (replace sdX with your device)
sudo dd bs=4M if=~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso of=/dev/sdX conv=fdatasync
```

## Using the Air-Gapped Environment

### Boot Sequence

1. Insert USB stick into air-gapped computer
2. Boot from USB (may need to adjust BIOS/UEFI boot order)
3. System boots directly into Ubuntu live session
4. On first boot, sca automatically installs packages from USB

### First-Time Setup

The live environment automatically:
1. Configures apt to use local package mirror (if included)
2. Installs PKCS#11 and YubiKey packages
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
| `/etc/ssl/sca/` | Default sca configuration |
| `~/.sca/` | Runtime configuration and keys |

## Testing

### Automated Testing

SCA can test the air-gapped image using QEMU:

```bash
sca test [ubuntu_version_id]
```

This:
1. Creates a test variant of the USB image
2. Boots it in QEMU with no network
3. Runs the test suite
4. Collects results via a virtual disk

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
  -drive format=raw,file=~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca-test.iso
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
