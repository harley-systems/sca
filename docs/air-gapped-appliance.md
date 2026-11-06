# The Air-Gapped CA Appliance

[← Back to README](../README.md) · [Air-Gapped Operations](air-gapped-operations.md)

`sca init sca_usb_stick` builds the boot media for an offline CA. This page
describes the machine that media is meant for: a small, battery-powered,
radio-less ARM board with the CA keys on a YubiKey and the CA bookkeeping on
encrypted storage. It records what to buy, how it fits together and why each
choice was made, so that you can build the same appliance, or make a different
choice knowingly.

> **Prices and stock.** The prices below were found in **2026-10**. Check them,
> and check stock, before you order. Pine64 stock in particular moves.

**Contents**

1. [Board revisions](#1-board-revisions)
2. [Design decisions](#2-design-decisions)
3. [Bill of materials](#3-bill-of-materials)
4. [Assembly and details](#4-assembly-and-details)

## 1. Board revisions

The reference board is a **PINE64 ROCK64 v2.0** (4 GB, RK3328). Some guidance
on this page differs by revision. The revision is printed on the board's
silkscreen.

| Topic | v2.0 | Rev3 (v3.0) |
|-------|------|-------------|
| RTC battery | No connector, no crystal or battery provision. Use a DS3231 ([2.4](#24-the-clock)) | Has an RTC battery connector; the Pine64 CR2032 holder fits |
| SPI flash, USB boot | 16 MB SPI confirmed present and readable; see [USB Boot on ARM](usb-boot-on-arm.md) | Expected to work the same way, **not verified**; see [USB Boot on ARM](usb-boot-on-arm.md#2-board-revisions) |
| Power input | 3.5 x 1.35 mm barrel jack, 5 V; no USB-C | Not covered here |

Early v1.x boards are not covered.

## 2. Design decisions

Each decision below had an alternative. Both are stated so that you can make
the trade yourself.

### 2.1 No radios

**Chosen: a ROCK64.** It has no WiFi and no Bluetooth hardware. The air gap is
then "this device has no wireless hardware", not "I trust that the radios are
off".

**Alternative: a Raspberry Pi.** It is far easier to buy, and it boots from USB
natively, without the SPI step in [USB Boot on ARM](usb-boot-on-arm.md). But it
has WiFi and Bluetooth on board. You can disable both in firmware, in
`config.txt`:

```
dtoverlay=disable-wifi
dtoverlay=disable-bt
```

The radios are then switched off, but they are still physically present, and
the air gap depends on that configuration staying in place.

| | ROCK64 | Raspberry Pi |
|---|---|---|
| Radios | None | Present, disabled in firmware |
| Availability | Limited; Pine64 stock moves | Widely available |
| USB boot | Needs U-Boot in SPI flash first | Native |
| Gives up | Easy sourcing and easy USB boot | A hardware-level air gap |

### 2.2 Keys in hardware, bookkeeping on disk

**Chosen: CA keys on the YubiKey, CA state on persistent storage.** The CA
private keys never leave the YubiKey. But a CA must also keep its bookkeeping
between sessions. Under `~/.sca/keys/<name>/`, for the CA and each sub-CA:

| File | What it is |
|------|------------|
| `*-db.txt` | The certificate index: every certificate issued |
| `*-srl.txt` | The certificate serial counter |
| `*-crl-srl.txt` | The CRL number counter |

Losing the serial counter means issuing a serial number twice. Duplicate
serials break revocation: a CRL entry then revokes the wrong certificate, or
two.

**Alternative: a purely amnesiac live boot**, where nothing survives power-off.
That is the right property for secrets, but not for a CA: its index and
counters would vanish with every session. So the appliance needs persistent
storage. Amnesia alone is not enough.

### 2.3 Encrypted storage, unlocked per session

**Chosen: LUKS on the partition that holds `~/.sca`, unlocked per session.**
sca keeps the YubiKey PIN, PUK and management key as cleartext files:

- `private/*-yubikey-pin.txt`
- `private/*-yubikey-puk.txt`
- `private/*-yubikey-key.txt`

On an amnesiac boot they vanish with the session. On a persistent disk they do
not, so that disk must be encrypted. Unlock it when you start a CA session and
lock it when you finish, rather than at boot:

```bash
sudo cryptsetup open /dev/<partition> sca
sudo mount /dev/mapper/sca ~/.sca
# ... CA work ...
sudo umount ~/.sca
sudo cryptsetup close sca
```

**Alternatives:** an unencrypted persistent partition leaves the PIN, PUK and
management key readable by anyone who takes the storage out of the case.
Unlocking at boot keeps the volume open for as long as the board runs, which is
longer than any CA operation needs.

### 2.4 The clock

**Chosen: a DS3231 RTC module on the I2C header** (on v2.0).

The ROCK64 v2.0 has no battery-backed RTC. The kernel does see `rk808-rtc`,
the clock in the RK805 PMIC, but the board has no crystal and no battery
provision to keep it running without power. The RTC battery connector is
documented for **Rev3 only**, so the Pine64 CR2032 holder does not fit a v2.0.

**Alternative: Armbian's `fake-hwclock`.** It restores the time of the last
shutdown at boot, so dates come back plausible but stale. For a CA, which
stamps validity periods into every certificate, a plausible but wrong clock is
arguably more dangerous than an obviously wrong one: nobody notices it. Worse,
its `load` can also move the clock **backwards**, over a correct RTC. Armbian
installs and enables it by default, so once the RTC is in, it must be masked;
see [The DS3231 RTC](#41-the-ds3231-rtc).

The DS3231 datasheet gives an accuracy of about 2 ppm, roughly a minute a year.
That figure has **not been measured** on this appliance: what has been verified
is that it keeps correct time across a power cut. See
[The DS3231 RTC](#41-the-ds3231-rtc). On a Rev3 board, the on-board RTC with
the Pine64 CR2032 holder is the alternative.

Whatever the clock, check the date before you sign anything:

```bash
date -u
```

### 2.5 Off, not asleep

**Chosen: power off between sessions.**

**Alternative: suspend to RAM.** It is unreliable on these boards. It is also
not wanted: a suspended device keeps its RAM, including anything a CA session
left there. A powered-off device holds nothing in RAM, which is the right
property for a CA used in short sessions.

### 2.6 Battery outside the case

**Chosen: a USB power bank next to the case, not inside it.**

**Alternative: a lithium cell inside the case.** The aluminium case is designed
to conduct the SoC's heat into its walls. Sealing a lithium cell in there is a
bad idea. Outside, the bank can also be charged or swapped without opening
anything.

## 3. Bill of materials

Prices as found in **2026-10**. Verify prices and stock before ordering.

| Part | Source | Price | Note |
|------|--------|-------|------|
| ROCK64 v2.0, 4 GB, RK3328 | — | — | The reference board; 85 x 56 x 18.8 mm |
| eMMC module, 16 GB | pine64.com | $15.95 | 8 GB $11.95, 32 GB $24.95. Buy **Pine64's own**: Odroid and Radxa modules look alike and are not pin-compatible |
| ROCK64 Premium Aluminum Casing | pine64.com | $12.99 | Finned lid with a thermal pad onto the SoC, microSD cutout in the end panel; approx. 92 x 61 x 27 mm |
| DS3231 RTC module (ZS-042) | AliExpress | approx. ILS 6.25 | 39 x 23 x 14 mm; datasheet 2 ppm (about 1 min/year), not measured |
| CR2032 cell | Local | A few ILS | **Buy it separately.** Listings saying "with battery CR2032" usually mean the holder |
| microSD card, 4 GB or more | **A local shop that takes returns** | — | Counterfeit and worn cards are common; test with `f3write`/`f3read` before trusting one |
| F-F Dupont jumper wires | AliExpress | approx. ILS 5-10 | Buy the 40-way ribbon |
| USB-C to 3.5 x 1.35 mm barrel cable, 5 V PD | AliExpress | — | The ROCK64 jack is 3.5 x 1.35 mm, centre-positive; there is no USB-C on v2.0 |
| USB power bank with USB-C output | — | — | 72 x 61 x 27 mm in the reference build |
| 3.3 V USB-TTL serial adapter | AliExpress | — | Optional, for bring-up. **3.3 V only**: 5 V can damage the SoC |
| eMMC-to-microSD carrier | pine64.com | — | Optional, for writing the eMMC from another machine. Maskrom over the OTG port is an alternative, see [#111](https://github.com/harley-systems/sca/issues/111) |

A YubiKey is needed too; see [YubiKey Setup](yubikey.md).

## 4. Assembly and details

### 4.1 The DS3231 RTC

The steps below are in the order you do them. Four of them are traps that
leave no useful error message; each is headed by what you see when you hit it.

#### Wiring

Connect the module to the ROCK64's Pi-2 header. Pin 1 is the one nearest the
RK3328, and all four wires go on the **odd row**:

| DS3231 pin | ROCK64 header pin |
|------------|-------------------|
| VCC | **1 (3.3 V)** |
| SDA | 3 |
| SCL | 5 |
| GND | 9 |
| 32K, SQW | Not connected |

**Use 3.3 V, not 5 V.** Pins 2 and 4 are 5 V, and they are on the other row.
The module's own 4.7 kΩ pull-ups tie SDA and SCL to whatever VCC is, so VCC on
pin 2 or 4 would drive 5 V into the RK3328's 3.3 V I2C pins. With all four
wires on the odd row, VCC cannot reach 5 V. On the reference build the module's
spare VCC/GND holes measured **3.32 V**.

**The module does not fit on the header inside the case.** The header is
8.5 mm tall and the module 14 mm, against roughly 20 mm of clearance under the
lid. Mount the module flat and connect it with soldered wires instead.

#### The cell

The ZS-042 carries a trickle charger (a diode and a `201` resistor) meant for a
rechargeable LIR2032. Charging a non-rechargeable CR2032 is the usual warning
about this module, so it was measured: with the holder empty and the board
powered, the charge node read **3.00 V** against a 3.32 V rail. A fresh CR2032
sits at about 3.2 V, above that node, so the charge path is reverse-biased and
no current flows. **On 3.3 V an ordinary CR2032 is safe, and no rework is
needed.**

**On 5 V it is not**: the same module then charges the cell, which is why the
warning exists. A LIR2032 is the wrong choice here for the same reason the
CR2032 is safe: a 3.00 V node can never charge a 3.6 V cell.

#### Module invisible, no error: enable I2C0

Header pins 3 and 5 are **I2C0** (`i2c@ff150000`, GPIO2_D0/GPIO2_D1), not I2C1,
and I2C0 is **disabled by default**. A correctly wired module is simply
invisible:

```
i2c@ff150000  status=disabled   i2c0, GPIO2_D0/GPIO2_D1  <- header pins 5/3
i2c@ff160000  status=okay       i2c1, GPIO2_A4/GPIO2_A5  <- header pins 28/27
```

Enable it in `/boot/armbianEnv.txt`, then reboot:

```
overlays=rk3328-i2c0
```

Armbian's own `README.rockchip-overlays` confirms `I2C0 pins (SCL, SDA):
GPIO2_D0, GPIO2_D1`. Then check the bus (`i2cdetect` is in the `i2c-tools`
package):

```bash
sudo i2cdetect -y 0
```

It should show `68`, the DS3231, and `57`, the module's AT24C32 EEPROM. The
`rtc_ds1307` driver is **built into** this kernel, so there is nothing to
install.

> **Do not move the module to pins 27/28.** When it does not show up on 3/5,
> the enabled bus, `i2c-1`, looks like the easy fix. It would work, but `i2c-1`
> is the **PMIC bus**: it carries the `rk805` PMIC at `0x18`. That puts a
> third-party module on the power-management bus of a device meant to sit
> unattended in a safe. Enable I2C0 instead.

#### RTC registered but ignored: the overlay

Without a device-tree alias, everything looks right and the DS3231 is still
not used. The PMIC probes first and takes `rtc0`, so the DS3231 lands on
`rtc1`, and the kernel sets the system time at boot from `rtc0`, the
batteryless PMIC clock. Check with:

```bash
for r in /sys/class/rtc/rtc*; do echo "$(basename "$r") -> $(cat "$r/name")  hctosys=$(cat "$r/hctosys")"; done
```

```
rtc0 -> rk808-rtc           hctosys=1   <- no battery
rtc1 -> rtc-ds1307 0-0068   hctosys=0   <- the one with the battery
```

This overlay declares the DS3231 and fixes the ordering. Save it as
`rock64-ds3231.dts`:

```dts
/dts-v1/;
/plugin/;

/ {
	fragment@0 {
		target = <&i2c0>;
		__overlay__ {
			#address-cells = <1>;
			#size-cells = <0>;
			status = "okay";

			rtc@68 {
				compatible = "maxim,ds3231";
				reg = <0x68>;
				status = "okay";
			};
		};
	};

	fragment@1 {
		target-path = "/aliases";
		__overlay__ {
			rtc0 = "/i2c@ff150000/rtc@68";
			rtc1 = "/i2c@ff160000/pmic@18";
		};
	};
};
```

Install it with `armbian-add-overlay`, which is already on the image, then
reboot:

```bash
sudo armbian-add-overlay rock64-ds3231.dts
sudo reboot
```

**The aliases are literal paths, not `&label` references, on purpose.** Path
fixups are not applied to `/aliases` entries in an overlay, so a reference
there silently resolves wrong. The paths are those of the RK3328 v2.0 device
tree on the kernel below.

`trickle-resistor-ohms` is **deliberately omitted**, so the DS3231's internal
charger also stays off.

After the reboot, the same check shows:

```
rtc0 -> rtc-ds1307 0-0068  hctosys=1
```

#### Clock walks backwards at boot: remove `fake-hwclock`

With the RTC working, the kernel reads it correctly and then
`fake-hwclock-load.service` overwrites it with a stale saved value:

```
[14.331]  kernel: rtc-ds1307 0-0068: setting system clock to 2026-11-06T12:23:29 UTC
[14.396]  Starting fake-hwclock-load.service - Restore the current clock...
[15.078]  systemd-timesyncd: System clock time advanced to recorded timestamp: 14:15:10 IST
```

The RTC's 12:23 UTC is 14:23 IST. `fake-hwclock` stepped the clock back from
there; `systemd-timesyncd` then moved it forward to its own recorded timestamp,
14:15 IST, which was still behind. timesyncd's restore only moves the clock
forward and is not the problem; leave it alone.

The cause is in `/usr/sbin/fake-hwclock` line 59, package
`fake-hwclock 0.14build1`:

```sh
if [ "$FORCE"x = "false"x ] || [ $NOW_SEC -le $SAVED_SEC ] ; then
    date -u -s "$SAVED"
```

`FORCE=false` by default, so the first clause is always true and `load` sets
the clock unconditionally, backwards included. The refusal branch is only
reachable when `force` *is* passed: the exact inverse of its own message and
of the man page ("Otherwise it will only move it forwards"). This is
[Debian #1093227](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1093227),
filed 2025-01 and still present.

For a CA this is not cosmetic: a clock walked backwards at every boot puts
**wrong `notBefore` dates on everything the CA issues**. `fake-hwclock` exists
for boards with no RTC; once there is one, it must go:

```bash
sudo systemctl disable --now fake-hwclock-save.timer fake-hwclock-save.service fake-hwclock-load.service
sudo systemctl mask fake-hwclock-load.service fake-hwclock-save.service fake-hwclock-save.timer
```

#### Acceptance test

1. Power the board off and leave it off for a while.
2. **Disconnect the network**, so nothing can set the clock but the RTC.
3. Boot, and before reconnecting anything, run:

   ```bash
   date -u
   ```

**Result, 2026-11-06:** the time was correct after the power cut. That is all
that was verified: the RTC survived a power cut with no network. Its drift
over weeks or months has not been measured.

#### Tested on

- Board: PINE64 ROCK64 v2.0 (silkscreen `ROCK64_V2.0 2017-0713`).
- OS: Armbian `26.11.0-trunk.108`, kernel `6.18.57-current-rockchip64`.
- Module: ZS-042 (`DS3231SN` + `AT24C32`, silkscreen `V858`), with a CR2032.
- Date: 2026-11-06.

This procedure is verified on **v2.0 only**. Rev3 has its own RTC battery
connector ([1](#1-board-revisions)), and nothing here was tried on it.

### 4.2 Serial console

For bring-up and debugging, connect a 3.3 V USB-TTL adapter to UART2:

| ROCK64 header pin | Signal | Adapter |
|-------------------|--------|---------|
| 6 | GND | GND |
| 8 | TX | RX |
| 10 | RX | TX |

The speed is **1500000 baud**, not 115200. A wrong speed is the usual reason
people see garbage and blame the cable. See
[USB Boot on ARM](usb-boot-on-arm.md#3-serial-console) for adapters that
manage that speed and the terminal commands.

### 4.3 Boot order

The RK3328 boot ROM reads **eMMC, then SPI, then SD**, then falls into USB OTG
download mode (maskrom). Maskrom is for writing to the board from a host, not
for booting it.

> **Not confirmed on hardware.** [USB Boot on ARM](usb-boot-on-arm.md#1-why-usb-boot-needs-spi)
> describes SPI as read first, ahead of eMMC. Neither order has been recorded
> from a real board's serial console yet. Booting a rescue microSD past a
> bootable eMMC, below, works either way while SPI is blank.

The board has a **2-pin eMMC disable header**. Close it with a jumper at
power-on and the boot ROM skips the eMMC, so you can boot a rescue microSD
card past a bootable eMMC without unplugging the module. Open it again once
the board has booted if you need the eMMC.

Booting from a USB stick needs U-Boot in SPI flash. That procedure is in
[USB Boot on ARM](usb-boot-on-arm.md).

### 4.4 Power

| Load | Draw |
|------|------|
| ROCK64, idle | Roughly 2-3 W |
| YubiKey | About 0.25 W |

A 10000 mAh power bank gives around 31 Wh usable, so eight to ten hours of
running. A CA session takes minutes, so that is dozens of sessions per charge.

### 4.5 Assembled size

The case and the power bank stacked come to about **92 x 61 x 54 mm**: roughly
a deck of cards in footprint, and three decks thick.

---

## See Also

- [Air-Gapped Operations](air-gapped-operations.md) - Building and booting the SCA image
- [USB Boot on ARM](usb-boot-on-arm.md) - Booting a ROCK64 from USB via SPI flash
- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [Configuration Reference](configuration.md) - Where sca keeps its files
