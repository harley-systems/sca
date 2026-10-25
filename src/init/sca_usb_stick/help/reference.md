Creates a bootable Ubuntu live USB with sca pre-installed for air-gapped root CA operations.

**Example:**

```bash
# Create USB image with YubiKey support
sca init sca_usb_stick --yubikey-support

# Write to USB (replace sdX with your device)
sudo dd bs=4M if=~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso of=/dev/sdX conv=fdatasync
```

See [Air-Gapped Operations](../air-gapped-operations.md) for complete workflow documentation.
