Creates a bootable Ubuntu live USB with sca pre-installed for air-gapped root CA operations.

**Ubuntu version:** `26.04-resolute` only (the default). The image is built on an
Ubuntu 26.04 host only; any other version id or host fails with an error. The
stick bundles OpenSSL 3.5, pkcs11-provider 1.2, OpenSC 0.27, pcscd/libccid,
yubico-piv-tool and ykcs11 2.7, yubikey-manager 5.8, and GnuPG with scdaemon
2.4, all from the Ubuntu 26.04 archive. See
[Tools on the stick](../air-gapped-operations.md#tools-on-the-stick).

**Reusing a built image:** an existing image is reused only if its
`<image>.options` file matches the `-y`, `-i` and `-x` options requested;
otherwise the command fails (see the syntax above). To build a new one, remove
both files:

```bash
rm -f ~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca.iso{,.options}
```

**Example:**

```bash
# Create USB image with YubiKey support
sca init sca_usb_stick --yubikey-support

# Write to USB (replace sdX with your device)
sudo dd bs=4M if=~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca.iso of=/dev/sdX conv=fdatasync
```

See [Air-Gapped Operations](../air-gapped-operations.md) for complete workflow documentation.
