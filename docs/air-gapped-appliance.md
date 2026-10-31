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
arguably more dangerous than an obviously wrong one: nobody notices it.

The DS3231 keeps time to about 2 ppm, roughly a minute a year. See
[Wiring the DS3231](#41-wiring-the-ds3231). On a Rev3 board, the on-board RTC
with the Pine64 CR2032 holder is the alternative.

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
| DS3231 RTC module (ZS-042) | AliExpress | approx. ILS 6.25 | 39 x 23 x 14 mm, 2 ppm (about 1 min/year) |
| CR2032 cell | Local | A few ILS | **Buy it separately.** Listings saying "with battery CR2032" usually mean the holder |
| microSD card, 4 GB or more | **A local shop that takes returns** | — | Counterfeit and worn cards are common; test with `f3write`/`f3read` before trusting one |
| F-F Dupont jumper wires | AliExpress | approx. ILS 5-10 | Buy the 40-way ribbon |
| USB-C to 3.5 x 1.35 mm barrel cable, 5 V PD | AliExpress | — | The ROCK64 jack is 3.5 x 1.35 mm, centre-positive; there is no USB-C on v2.0 |
| USB power bank with USB-C output | — | — | 72 x 61 x 27 mm in the reference build |
| 3.3 V USB-TTL serial adapter | AliExpress | — | Optional, for bring-up. **3.3 V only**: 5 V can damage the SoC |
| eMMC-to-microSD carrier | pine64.com | — | Optional, for writing the eMMC from another machine. Maskrom over the OTG port is an alternative, see [#111](https://github.com/harley-systems/sca/issues/111) |

A YubiKey is needed too; see [YubiKey Setup](yubikey.md).

## 4. Assembly and details

### 4.1 Wiring the DS3231

Connect the module to the ROCK64's Pi-2 header:

| DS3231 pin | ROCK64 header pin |
|------------|-------------------|
| VCC | **1 (3.3 V)** |
| SDA | 3 |
| SCL | 5 |
| GND | 9 |
| 32K, SQW | Not connected |

**Use 3.3 V, not 5 V.** The ZS-042 module has a diode-and-resistor charging
circuit for its cell. At 3.3 V it puts roughly 2.6-2.8 V on the cell, below a
CR2032's 3.0 V, so the circuit is inert and an ordinary CR2032 is safe. **At
5 V it is not**: that path charges the cell, and then the module needs a
rechargeable LIR2032 instead.

**The module does not fit on the header inside the case.** The header is
8.5 mm tall and the module 14 mm, against roughly 20 mm of clearance under the
lid. Mount the module flat and connect it with soldered wires instead.

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
