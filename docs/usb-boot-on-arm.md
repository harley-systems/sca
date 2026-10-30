# USB Boot on ARM: ROCK64

[← Back to README](../README.md) · [Air-Gapped Operations](air-gapped-operations.md)

A PINE64 ROCK64 boots the SCA image from **microSD** as it is. It does **not**
boot from a USB stick until U-Boot has been written to the board's on-board SPI
flash. This page explains why, how to write SPI by hand, and how to recover a
board if the write goes wrong.

> **You do not need any of this to boot from microSD.** Write the image to a
> microSD card, put the card in the board and power on. Read on only if you want
> the board to boot from a USB stick instead.

> **Testing status.** This is a draft. The facts about the boot ROM, the SPI
> chip (`/proc/mtd` on a v2.0 board) and the serial console come from the
> hardware. The flashing and recovery commands have **not yet been run on a
> ROCK64** for this page. Steps marked **(unverified)** must be checked on a real
> board before you rely on them. See [Tested on](#tested-on) at the bottom.

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

### Option 1: from the Armbian U-Boot package (recommended)

The Armbian image that SCA uses ships U-Boot as a Debian package,
`linux-u-boot-rock64-<branch>`. On Rockchip boards whose Armbian build supports
SPI boot, the package includes an SPI image named `rkspi_loader.img`
**(unverified for the ROCK64 package)**:

```bash
dpkg -l 'linux-u-boot-*'
find /usr/lib/linux-u-boot-* -name 'rkspi_loader.img'
```

Verify it the Debian way. The package came from a signed apt repository, and
`dpkg` can check its files against the package's checksums:

```bash
dpkg --verify "$(dpkg -S rkspi_loader.img | cut -d: -f1)"
```

No output means every file matches. Record the image's checksum for your own
notes:

```bash
sha256sum /usr/lib/linux-u-boot-*/rkspi_loader.img
```

### Option 2: build mainline U-Boot

Mainline U-Boot has a `rock64-rk3328_defconfig`. Builds for Rockchip boards
with SPI boot support produce `u-boot-rockchip-spi.bin`
**(unverified for rock64)**. The build also needs ARM Trusted Firmware (TF-A)
for the RK3328 (`bl31.elf`). Follow the Rockchip page of the U-Boot
documentation (`doc/board/rockchip/rockchip.rst` in the source tree) for the
exact steps.

Build from a **signed release tag** (`git tag -v v20XX.YY`) so that you can
say what you built, and record the `sha256sum` of the result.

### Check the size

The image must fit in the SPI chip:

```bash
stat -c %s rkspi_loader.img     # must be ≤ 16777216 (16 MB)
```

## 5. Route A: write SPI from Armbian on microSD

You boot the board normally from microSD, then write SPI from Linux.

| | |
|---|---|
| **Needs** | A working microSD boot, and `mtd0` visible in `/proc/mtd` |
| **Pros** | No extra host or tools. The commands are the usual Linux ones. You can read SPI back to check the write. |
| **Cons** | Cannot help a board that no longer boots. If the write is interrupted, see [section 7](#7-recovering-from-a-bad-spi-write). |

Armbian's own installer can do this for you. Run `sudo armbian-install` and pick
**"Install/Update the bootloader on SPI Flash"**, if your image offers it
**(unverified for the ROCK64)**. The manual steps below do the same thing, and
let you back up and check each step.

All steps are **(unverified)**.

1. **Install the tools.** `flashcp` is in `mtd-utils`:

   ```bash
   sudo apt-get install mtd-utils
   ```

2. **Back up the current SPI contents.** A blank chip reads as all `0xff`;
   keep the backup anyway:

   ```bash
   sudo dd if=/dev/mtd0 of=spi-backup.img bs=4096
   sha256sum spi-backup.img
   ```

   Copy `spi-backup.img` off the board.

3. **Write the image.** `flashcp` erases the blocks it needs, writes and
   verifies:

   ```bash
   sudo flashcp -v rkspi_loader.img /dev/mtd0
   ```

   The alternative is to write through the block device:

   ```bash
   sudo dd if=rkspi_loader.img of=/dev/mtdblock0 bs=4096 conv=fsync
   ```

   Prefer `flashcp`. `mtdblock` emulates a block device on top of flash and
   does not verify. Do not power the board off during the write.

4. **Read it back and compare.** `cmp` with no output means the SPI contents
   match the image:

   ```bash
   sudo cmp -n "$(stat -c %s rkspi_loader.img)" rkspi_loader.img /dev/mtd0
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

All steps are **(unverified)**.

1. **Install `rkdeveloptool`** on the host. Debian and Ubuntu package it as
   `rkdeveloptool`; otherwise build it from
   <https://github.com/rockchip-linux/rkdeveloptool>.

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

5. **Load the loader into RAM, select SPI, write and reset:**

   ```bash
   sudo rkdeveloptool db rk3328_loader_v*.bin   # download the loader to RAM
   sudo rkdeveloptool cs 9                      # select SPI NOR as the target
   sudo rkdeveloptool wl 0 rkspi_loader.img     # write from sector 0
   sudo rkdeveloptool rd                        # reset the board
   ```

   `cs` (change storage) needs a recent `rkdeveloptool` and a loader that
   supports SPI. Without it, `wl` writes to the loader's default storage,
   which is usually the eMMC. Check that `cs 9` succeeds before you run `wl`.

6. **Test** as in step 5 of Route A.

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
     image, or erase SPI after `db` and `cs 9` with:

     ```bash
     sudo rkdeveloptool ef
     ```

3. **Corrupted eMMC.** The eMMC disable header does the same job for the eMMC:
   close it at power-on so that the boot ROM skips the eMMC, boot from microSD
   or into maskrom, and rewrite the eMMC from there.

An erased SPI chip puts the board back to how it left the factory: it boots
from eMMC or microSD as before.

## Tested on

Not yet run on hardware for this page. Before you rely on the procedure, a
person with a ROCK64 must record here:

- board revision;
- U-Boot image: source, version and `sha256sum`;
- route used (A or B), with `rkdeveloptool` and loader versions for Route B;
- result of booting from a USB stick, and of the recovery path in section 7.

---

## See Also

- [Air-Gapped Operations](air-gapped-operations.md) - Building and booting the SCA image
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
