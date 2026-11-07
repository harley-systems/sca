Creates a bootable Ubuntu live USB with sca pre-installed for air-gapped root CA operations.

**Ubuntu version:** `26.04-resolute` only (the default). The image is built on an
Ubuntu 26.04 host only; any other version id or host fails with an error. The
stick bundles OpenSSL 3.5, pkcs11-provider 1.2, OpenSC 0.27, pcscd/libccid,
yubico-piv-tool and ykcs11 2.7, yubikey-manager 5.8, and GnuPG with scdaemon
2.4, all from the Ubuntu 26.04 archive. See
[Tools on the stick](../air-gapped-operations.md#tools-on-the-stick).

**The sca on the stick:** the stick ships `~/bin/sca` and generates its bash
completion from it, so it works after either `make deploy` (default
`INSTALL_DIR`) or `sca install`. If `~/bin/sca` is missing, the command fails
before downloading anything. `make deploy` writes the host's completion to
`$(COMPLETION_DIR)/sca` (default `~/.local/share/bash-completion/completions/sca`),
`sca install` to `~/bin/sca_completion`; neither file is used by the stick.

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

**ARM boards:** `--board rock64` builds the image for a PINE64 ROCK64 from
the latest Armbian minimal image of the same Ubuntu release, checked against
its published sha256 and its detached signature by the Armbian image signing
key (`DF00 FAF1 C577 104B 50BF 1D00 93D6 889F 9F0E 78D5`, bundled in sca). The
image boots from a microSD card as written; booting it from a USB stick needs
U-Boot in the board's SPI flash first, see
[USB Boot on ARM](../usb-boot-on-arm.md). The image also gets the appliance
settings of [the air-gapped appliance](../air-gapped-appliance.md):
`fake-hwclock` masked, a persistent journal and `armbian-ramlog` disabled.
`--test-image` and `--include-apt-mirror` are not supported with it.

```bash
# Create the ROCK64 image with YubiKey support
sca init sca_usb_stick --yubikey-support --board rock64

# Write it to a microSD card (replace sdX with your card's device)
sudo dd bs=4M if=~/.sca/downloads/Armbian_community_26.11.0-trunk.108_Rock64_resolute_current_6.18.57_minimal.sca.img of=/dev/sdX conv=fdatasync
```

See [Air-Gapped Operations](../air-gapped-operations.md) for complete workflow documentation.
