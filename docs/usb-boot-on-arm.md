# USB Boot on ARM: ROCK64

[← Back to README](../README.md) · [Air-Gapped Operations](air-gapped-operations.md)

A PINE64 ROCK64 boots the SCA image from **microSD** as it is. It does **not**
boot from a USB stick until U-Boot has been written to the board's on-board SPI
flash. This page explains why, how to write SPI by hand, and how to recover a
board if the write goes wrong.

> **You do not need any of this to boot from microSD.** Write the image to a
> microSD card, put the card in the board and power on. Read on only if you want
> the board to boot from a USB stick instead.

> **Testing status.** This is a draft. The read-only checks have been run on a
> real ROCK64: the SPI chip is visible to Linux, the `mtd-utils` tools are
> present, and the Armbian U-Boot package ships **no SPI image**. Building an SPI
> image from upstream U-Boot has also been run on a ROCK64, and the image's
> layout checked (see [section 4](#4-get-and-verify-the-u-boot-image)). Writing
> that image to SPI, booting from it, and the recovery routes have **not been
> run** on any board: nothing has been written to SPI for this page. Steps
> marked **(unverified)** must be checked on a real board before you rely on
> them. See [Tested on](#tested-on) at the bottom.

> **You need root.** Every step that writes or erases SPI needs `sudo`.
> Reading the chip back through `/dev/mtdblock0` works without `sudo` if your
> user is in group `disk`; `/dev/mtd0` is readable by root only.

**Contents**

1. [Why USB boot needs SPI](#1-why-usb-boot-needs-spi)
2. [Board revisions](#2-board-revisions)
3. [Serial console](#3-serial-console)
4. [Get and verify the U-Boot image](#4-get-and-verify-the-u-boot-image)
5. [Route A: write SPI from Armbian on microSD](#5-route-a-write-spi-from-armbian-on-microsd)
6. [Route B: write SPI over USB in maskrom mode](#6-route-b-write-spi-over-usb-in-maskrom-mode)
7. [Recovering from a bad SPI write](#7-recovering-from-a-bad-spi-write)
8. [Tested on](#tested-on)

## 1. Why USB boot needs SPI

The RK3328's boot ROM, the code burned into the chip, looks for a bootloader
on three kinds of storage only: the on-board **SPI** flash, the **eMMC** module
and the **microSD** card. It has no USB mass-storage driver. If it finds no
bootloader, it falls into Rockchip **maskrom** mode. That mode waits for a
host computer on the USB-OTG port to send it code. It is a download mode, not a
way to boot from a USB stick.

So a factory-fresh ROCK64 with a USB stick and no microSD card does nothing
useful.

Once U-Boot is in SPI, the boot ROM finds it there first. U-Boot has USB
drivers, and it then looks for an operating system in this order:

```
SPI (U-Boot itself) → eMMC → microSD → USB → PXE (network)
```

From then on, a USB stick with the SCA image boots as long as no eMMC module or
microSD card with a bootable system is present, because those come first.

This is a **one-time step per board**. The U-Boot in SPI stays there until you
erase or overwrite it.

**Should you do it?** For an air-gapped CA, microSD is a perfectly good boot
medium. USB boot is worth the effort when you want the same USB stick to boot
both an x86 machine and the ROCK64, or when you prefer USB sticks to microSD
cards. If neither applies, stay on microSD.

## 2. Board revisions

| Revision | SPI flash | Status |
|----------|-----------|--------|
| v2.0 | 128 Mbit (16 MB), seen as `mtd0 "spi0.0"` | SPI confirmed present and readable; flashing **(unverified)** |
| v3.0 | 128 Mbit | Expected to work the same way **(unverified)** |
| v1.x (early boards) | | Not covered |

The revision is printed on the board's silkscreen. To check that your board's
SPI flash is visible, boot Armbian from microSD and run:

```bash
cat /proc/mtd
```

```
dev:    size   erasesize  name
mtd0: 01000000 00001000 "spi0.0"
```

`01000000` is 16 MB. If `mtd0` is missing, Linux cannot see the SPI chip; use
[Route B](#6-route-b-write-spi-over-usb-in-maskrom-mode) instead of Route A, or stop here.

## 3. Serial console

When the board does nothing visible, the serial console is how you find out
why. Set it up **before** you write SPI. You will want it if something goes
wrong.

| ROCK64 Pi-2 header pin | Signal | Connect to adapter |
|------------------------|--------|--------------------|
| 6 | GND | GND |
| 8 | UART2 TX | RX |
| 10 | UART2 RX | TX |

- Use a **3.3 V** USB-serial adapter. Do not connect its VCC pin.
- TX on the board goes to RX on the adapter, and RX to TX.
- The speed is **1500000 baud** (1.5 Mbaud), 8N1, no flow control. Many cheap
  adapters (CH340, PL2303) cannot run at that speed reliably. FTDI FT232R and
  Silicon Labs CP2102N adapters can.

```bash
picocom -b 1500000 /dev/ttyUSB0
# or
screen /dev/ttyUSB0 1500000
```

At power-on you should see the boot ROM hand over to U-Boot, and U-Boot print
its version and the devices it scans.

## 4. Get and verify the U-Boot image

You need a U-Boot image **built for SPI on the ROCK64**. An image built for
microSD or eMMC has a different layout and will not boot from SPI. Never write
an image you cannot trace back to its source.

### The Armbian package has no SPI image

The Armbian image that SCA uses ships U-Boot as a Debian package,
`linux-u-boot-rock64-<branch>`. For the ROCK64 that package (checked at
`26.11.0-trunk.108`) contains exactly one U-Boot image,
`/usr/lib/linux-u-boot-<branch>-rock64/u-boot-rockchip.bin`. It has **no SPI
image**: nothing in it is built for SPI. Installing or
updating the package does not change that.

The SPI image is a feature of **upstream** U-Boot, not something Armbian adds.
The stock `configs/rock64-rk3328_defconfig` in upstream U-Boot v2026.04 already
sets:

```
CONFIG_ROCKCHIP_SPI_IMAGE=y
CONFIG_SYS_SPI_U_BOOT_OFFS=0x60000
```

so every build produces an SPI image. Armbian's packaging
(`UBOOT_TARGET_BINS`) collects only `u-boot-rockchip.bin`, so the SPI image is
built and then left out of the package. Armbian's defconfig differs from the
stock one in three cosmetic lines only (`CONFIG_LOCALVERSION`,
`# CONFIG_LOCALVERSION_AUTO is not set` and `CONFIG_BOOTDELAY=0`). A stock
upstream build is therefore equivalent to the image Armbian would package.

A packaged, ready-to-flash ROCK64 SPI image is tracked in
[#108](https://github.com/harley-systems/sca/issues/108). Until then, you have
to build one yourself.

> **Do not write `u-boot-rockchip.bin` to SPI.** It is the only U-Boot image on
> the board, so it is the obvious thing to reach for, but it is the SD/eMMC
> layout. The SPI layout puts U-Boot proper at
> `CONFIG_SYS_SPI_U_BOOT_OFFS=0x60000` (384 KB), so the SD/eMMC image will not
> boot from SPI. If you have already written it, see
> [section 7](#7-recovering-from-a-bad-spi-write).

### Build U-Boot with the SPI image

The steps below were run natively on a ROCK64 (aarch64, no cross-compiler)
with U-Boot tag `v2026.04`. Other tags may need other steps.

#### What you need

Upstream U-Boot, plus ARM Trusted Firmware (TF-A) `bl31.elf` for the RK3328
from the distribution. **Building the image needs no Rockchip blob:**

- **BL31** comes from the Ubuntu package `arm-trusted-firmware` (universe,
  tested with `2.12.1+dfsg-1`). `+dfsg` means it is built from source, not
  taken from Rockchip's `rkbin` repository.
- **TPL**, the first stage that sets up the RAM, is built by U-Boot itself. The
  RK3328 DDR init is open source, so there is no DDR blob to fetch.
- **OP-TEE** is optional. The build prints this message, which is expected and
  harmless:

  ```
  Image 'simple-bin-spi' is missing optional external blobs but is still functional: tee-os
  ```

Install the build tools:

```bash
sudo apt install -y build-essential bison flex libssl-dev swig python3-dev \
    python3-setuptools python3-pyelftools git
```

#### Get BL31

Download the package and extract it without installing it:

```bash
mkdir -p ~/uboot-build && cd ~/uboot-build
apt-get download arm-trusted-firmware
dpkg-deb -f arm-trusted-firmware_*.deb Version     # record the version
dpkg-deb -x arm-trusted-firmware_*.deb atf
cp atf/usr/lib/arm-trusted-firmware/rk3328/bl31.elf bl31.elf
sha256sum bl31.elf                                 # record the checksum
```

#### Get the source

```bash
cd ~/uboot-build
git clone --depth 1 --branch v2026.04 https://github.com/u-boot/u-boot.git
cd u-boot
git tag -v v2026.04
```

Clone from the GitHub mirror. A clone from `source.denx.de` redirects to
`git.u-boot-project.org`, and the shallow clone then fails with
`fatal: your current branch appears to be broken`. Because the mirror is not
the canonical source, check the tag signature with `git tag -v` so that you can
say what you built. A shallow clone may not fetch the signed tag object, and
`git tag -v` needs the U-Boot maintainers' key in your keyring **(unverified)**.

#### Build

```bash
make rock64-rk3328_defconfig
make -j"$(nproc)" BL31="$HOME/uboot-build/bl31.elf"
```

The build writes `u-boot-rockchip-spi.bin` to the top of the source tree, next
to `u-boot-rockchip.bin` (the SD/eMMC image) and `idbloader-spi.img`.

On an x86 host, a cross build should work the same way with
`CROSS_COMPILE=aarch64-linux-gnu-` added to both `make` commands
**(unverified)**.

#### Two build errors that don't name their cause

- **`ModuleNotFoundError: No module named 'setuptools'`** from
  `scripts/dtc/pylibfdt/setup.py`. The host's Python has no `setuptools`.
  Install `python3-setuptools`. On a host without root, putting the
  `setuptools` and `pyelftools` wheels on a build-only `PYTHONPATH` also works.
- **`fatal error: gnutls/gnutls.h`** while building `tools/mkeficapsule`. That
  is an EFI capsule host tool the ROCK64 does not need. Disable it after
  `make rock64-rk3328_defconfig` and before the build:

  ```bash
  ./scripts/config --disable TOOLS_MKEFICAPSULE && make olddefconfig
  ```

  This changes no binary that goes on the board. Installing `libgnutls28-dev`
  is the alternative.

#### Record the result

```bash
sha256sum u-boot-rockchip-spi.bin
```

Keep this checksum with a note of the U-Boot tag and the BL31 package version.
U-Boot embeds the build date, so your checksum will **not** match the one in
[Tested on](#tested-on). A different value is expected and is not a sign of
tampering.

### Check the size and layout

The image must fit in the SPI chip:

```bash
stat -c %s u-boot-rockchip-spi.bin     # must be ≤ 16777216 (16 MB)
```

The reference build is 1346048 bytes: `0x60000` plus U-Boot proper. The image
is laid out like this:

| Offset | Contents |
|--------|----------|
| `0x00000`–`0x07fff` | `0xff` padding |
| `0x08000` | `idbloader-spi.img` (TPL and SPL), copied verbatim |
| `0x60000` | `u-boot.itb` (U-Boot proper, a FIT image) |

Run these checks from the source tree:

```bash
# The first 32 KB are 0xff: prints nothing
cmp -n 32768 u-boot-rockchip-spi.bin <(head -c 32768 /dev/zero | tr '\0' '\377')

# idbloader-spi.img starts at 0x8000 (32768): prints nothing
cmp -i 32768:0 -n "$(stat -c %s idbloader-spi.img)" u-boot-rockchip-spi.bin idbloader-spi.img

# U-Boot proper starts at 0x60000 (393216) with the FIT magic d0 0d fe ed
od -A x -t x1 -j 393216 -N 4 u-boot-rockchip-spi.bin
```

```
060000 d0 0d fe ed
060004
```

Finally, check that you have the SPI image and not the SD/eMMC one. The two
files must differ:

```bash
cmp u-boot-rockchip-spi.bin u-boot-rockchip.bin     # must report a difference
```

> **A correct layout does not mean the image boots.** No image built this way
> has been written to SPI or boot-tested yet. A valid but broken SPI image
> stops the board from booting from microSD, and the way out
> ([Route B](#6-route-b-write-spi-over-usb-in-maskrom-mode)) is itself
> unverified. Run Route B's read-back test (steps 1 to 5) before you write
> anything to SPI.

## 5. Route A: write SPI from Armbian on microSD

You boot the board normally from microSD, then write SPI from Linux.

| | |
|---|---|
| **Needs** | A working microSD boot, and `mtd0` visible in `/proc/mtd` |
| **Pros** | No extra host or tools. The commands are the usual Linux ones. You can read SPI back to check the write. |
| **Cons** | Cannot help a board that no longer boots. If the write is interrupted, see [section 7](#7-recovering-from-a-bad-spi-write). |

Armbian's own installer, `sudo armbian-install`, has an **"Install/Update the
bootloader on SPI Flash"** entry on some boards. It installs from the same
U-Boot package, which has no SPI image for the ROCK64 (see
[section 4](#4-get-and-verify-the-u-boot-image)), so it is not expected to
offer that option here **(unverified)**. Use the manual steps below.

All write steps are **(unverified)**.

1. **Install the tools.** `flashcp` is in `mtd-utils`:

   ```bash
   sudo apt-get install mtd-utils
   ```

2. **Back up the current SPI contents.** A blank chip reads as all `0xff`;
   keep the backup anyway. Reading through `/dev/mtdblock0` works without
   `sudo` for a user in group `disk`; with `sudo` it works for anyone:

   ```bash
   dd if=/dev/mtdblock0 of=spi-backup.img bs=4096
   sha256sum spi-backup.img
   ```

   Copy `spi-backup.img` off the board.

   If you are counting on [Route B](#6-route-b-write-spi-over-usb-in-maskrom-mode)
   to recover the board, run its SPI read-back test (steps 1 to 5) before you
   go on.

3. **Write the image.** `flashcp` erases the blocks it needs, writes and
   verifies **(unverified)**:

   ```bash
   sudo flashcp -v u-boot-rockchip-spi.bin /dev/mtd0
   ```

   Do not power the board off during the write.

4. **Read it back and compare.** `cmp` with no output means the SPI contents
   match the image. As in step 2, a user in group `disk` does not need `sudo`:

   ```bash
   cmp -n "$(stat -c %s u-boot-rockchip-spi.bin)" u-boot-rockchip-spi.bin /dev/mtdblock0
   ```

5. **Test.** Power off, remove the microSD card, insert the USB stick with the
   SCA image, and power on with the serial console attached. U-Boot should
   report its version, find no eMMC or microSD system, scan USB and boot from
   the stick.

## 6. Route B: write SPI over USB in maskrom mode

You connect the board to the build host with a USB cable and write SPI from the
host with `rkdeveloptool`. The ROCK64's **top USB 2.0 port is the USB-OTG port**.
That is the one the boot ROM listens on in maskrom mode.

| | |
|---|---|
| **Needs** | A USB-A to USB-A cable, `rkdeveloptool` on the host, and the RK3328 loader blob from Rockchip's `rkbin` repository |
| **Pros** | Works on a board that does not boot at all. It is the route that recovers corrupted SPI or eMMC. |
| **Cons** | More tools and moving parts. The loader blob is a Rockchip binary. Getting the board into maskrom can take a few tries. |

All steps are **(unverified)**. Steps 1 to 5 only read from the board, so you
can use them to prove this route works before you need it.

1. **Install `rkdeveloptool`** on the host. Selecting SPI NOR as the target
   (`cs`), and so writing (`wl`) or erasing (`ef`) SPI NOR, is reported to be
   missing from upstream <https://github.com/rockchip-linux/rkdeveloptool> and
   from the Debian/Ubuntu `rkdeveloptool` package built from it. The support is
   reported to be in the <https://github.com/amouiche/rkdeveloptool> fork
   (`v1.32+change_storage`) **(unverified)**. Before you go on, check that the
   help of your build lists a `cs` (change storage) command:

   ```bash
   rkdeveloptool -h
   ```

   If it does not, this route cannot reach SPI NOR.

2. **Get the RK3328 loader**, `rk3328_loader_v*.bin`, from
   <https://github.com/rockchip-linux/rkbin> (under `bin/rk33/`, or build it
   with that repository's `boot_merger`). Record its `sha256sum`.

3. **Put the board in maskrom mode.** The boot ROM enters maskrom when it finds
   no bootloader on SPI, eMMC or microSD:
   - remove the microSD card;
   - remove the eMMC module, or close the 2-pin **eMMC disable** header next to
     it;
   - if SPI already holds a bootloader, see [section 7](#7-recovering-from-a-bad-spi-write)
     for how to keep the boot ROM from reading it;
   - connect the **top USB 2.0 port** to the host with the USB-A to USB-A
     cable, then power the board on.

   Holding the **Recovery** button at power-on is the other way in. Whether it
   gives maskrom or the bootloader's own USB download mode depends on what is
   already on the board **(unverified)**. `rkdeveloptool` can use either
   mode.

   If you closed the eMMC disable header, open it again once the board is in
   maskrom, so that the eMMC is reachable later.

4. **Check that the host sees the board:**

   ```bash
   sudo rkdeveloptool ld
   # DevNo=1 Vid=0x2207,Pid=0x320c,LocationID=...  Maskrom
   ```

5. **Load the loader into RAM, select SPI and read SPI back.** Do this before
   you write anything. It proves that the host can reach SPI NOR, which is also
   what the [recovery path](#7-recovering-from-a-bad-spi-write) depends on:

   ```bash
   sudo rkdeveloptool db rk3328_loader_v*.bin          # download the loader to RAM
   sudo rkdeveloptool cs 9                             # select SPI NOR as the target
   sudo rkdeveloptool rl 0 32768 spi-readback.img      # read 16 MB (32768 × 512-byte sectors)
   sha256sum spi-readback.img
   ```

   `cs` (change storage) needs an `rkdeveloptool` that supports it (see
   step 1) and a loader that supports SPI. Without it, `rl` and `wl` use the
   loader's default storage, which is usually the eMMC. A blank chip reads back
   as all `0xff`. Stop here if `cs 9` fails or the read-back does not look like
   your SPI contents.

6. **Write and reset** **(unverified)**:

   ```bash
   sudo rkdeveloptool wl 0 u-boot-rockchip-spi.bin     # write from sector 0
   sudo rkdeveloptool rd                               # reset the board
   ```

7. **Test** as in step 5 of Route A.

## 7. Recovering from a bad SPI write

A bad write is recoverable. It feels worse than it is. The danger is a SPI chip
holding something the boot ROM accepts as a bootloader but which then hangs.
The boot ROM reads SPI first, so it never gets to microSD. The serial console
shows how far the boot gets.

The fix is to **keep the boot ROM from reading SPI** for one boot, then erase or
rewrite it. All steps are **(unverified)**.

1. **Disable SPI for one boot.** Short SPI clock to ground on the Pi-2
   header, **pin 23 (SPI CLK) to pin 25 (GND)**, with a jumper wire, while you
   power on. The boot ROM cannot read SPI and moves on to eMMC and microSD.
   Remove the short once the serial console shows the boot has moved past SPI.

2. **Then choose:**
   - **With a bootable microSD card inserted**, the board boots Armbian. Erase
     SPI or write a good image with [Route A](#5-route-a-write-spi-from-armbian-on-microsd):

     ```bash
     sudo flash_erase /dev/mtd0 0 0      # erase the whole chip
     # or restore the backup:
     sudo flashcp -v spi-backup.img /dev/mtd0
     ```

   - **With no microSD card and the eMMC disabled** (2-pin header closed or
     module removed), the boot ROM drops into maskrom. Use
     [Route B](#6-route-b-write-spi-over-usb-in-maskrom-mode) to write a good
     image, or erase SPI with the command below. Run it only after `db`,
     `cs 9` and the read-back in Route B step 5 have succeeded; otherwise it
     may erase the eMMC instead:

     ```bash
     sudo rkdeveloptool ef
     ```

3. **Corrupted eMMC.** The eMMC disable header does the same job for the eMMC:
   close it at power-on so that the boot ROM skips the eMMC, boot from microSD
   or into maskrom, and rewrite the eMMC from there.

An erased SPI chip puts the board back to how it left the factory: it boots
from eMMC or microSD as before.

## Tested on

**Read-only checks, run on hardware:**

- Board: PINE64 ROCK64, revision not recorded.
- OS: Armbian_community 26.11.0-trunk.108, kernel 6.18.57-current-rockchip64,
  booted from microSD.
- `/proc/mtd` shows `mtd0`, 16 MB, `"spi0.0"`.
- `flashcp`, `flash_erase` and `mtdinfo` are present (`/usr/sbin`).
- All 16 MB of SPI read back as `0xff`: the chip was blank.
- The `linux-u-boot-rock64-current` package ships only `u-boot-rockchip.bin`,
  no SPI image.

**Built, not flashed:**

- U-Boot: upstream tag `v2026.04`, cloned from the GitHub mirror, stock
  `rock64-rk3328_defconfig` with `TOOLS_MKEFICAPSULE` disabled.
- BL31: `arm-trusted-firmware` `2.12.1+dfsg-1` (Ubuntu universe),
  `rk3328/bl31.elf`. No OP-TEE.
- Built natively on the ROCK64 (aarch64). `setuptools` and `pyelftools` came
  from wheels on a build-only `PYTHONPATH`, not from the `python3-setuptools`
  and `python3-pyelftools` packages in section 4.
- `u-boot-rockchip-spi.bin`: 1346048 bytes, sha256
  `19fac1ee433a65bbd16e154e5a06226c76bb8c145e9e89003ef0d8e40d7698fa`.
- Layout checks passed: `0xff` padding up to `0x7fff`, `idbloader-spi.img`
  verbatim at `0x8000`, FIT magic `d00dfeed` at `0x60000`.
- The idbloader's first bytes match those of Armbian's own
  `u-boot-rockchip.bin`.
- `u-boot-rockchip-spi.bin` and `u-boot-rockchip.bin` differ.
- The image has **not** been written to SPI or boot-tested.

**Not yet run on hardware:** the flashing routes (A and B) and the recovery
path. Before you rely on them, a person with a ROCK64 must record here:

- board revision;
- U-Boot image: source, version and `sha256sum`;
- route used (A or B), with `rkdeveloptool` and loader versions for Route B;
- result of booting from a USB stick, and of the recovery path in section 7.

---

## See Also

- [Air-Gapped Operations](air-gapped-operations.md) - Building and booting the SCA image
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
