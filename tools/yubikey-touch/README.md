# YubiKey touch fixture (rev E)

A printed holder that presses a pogo pin onto the touch pad of a YubiKey 4 (USB-A) and a
YubiKey 5 NFC (USB-C), so an RP2040-Zero can "touch" each key by grounding its pin. It also
switches each key's power. Use it only with test keys: it removes the user-presence check.

`fixture.scad` is the source. The `stl/` files are rendered from it, already turned the right way up for printing:

| File | What | Print |
|---|---|---|
| `stl/yubikey-touch-test.stl` | North drawer and pin tower only | First, about 40 min: checks the key fit, pin bore, floor hole and solder window |
| `stl/yubikey-touch-body.stl` | Box, both drawers, towers, insert blocks | Floor on the bed |
| `stl/yubikey-touch-deck.stl` | Board tray above the hub | Flat |
| `stl/yubikey-touch-lid.stl` | Lid with hold-down ribs | Top face on the bed |

`yubikey-touch-fixture.mp4` is an animation of the assembly.

## Print settings (Prusa, PLA)

- 0.4 mm nozzle, 0.2 mm layers (0.15 mm for the test piece and body, for cleaner small holes)
- No supports. The tunnel roofs and wall openings bridge, and the insert blocks and lid ledges have 45° undersides.
- 3 perimeters and 20 % infill
- If the 1.2 mm pin bore comes out tight, ream it with a 1.1 mm drill in the pin vise.

## Check before printing the body

Some dimensions come from listings and datasheets, not from the parts in hand. They are
parameters at the top of `fixture.scad`:

- **Pin position under each touch pad:** `pin_ty_yk4` and `pin_ty_yk5`. The test piece showed the pad centre is about 29 mm from the plug tip (YubiKey 4, Security Key and 5C alike). In rev E the pins sit about 7 mm too far from the hub, so move them once the hub's socket faces are measured: pin = plug tip position − 29 mm.
- **Key tunnel:** 18.3 × 5.2 mm, for a key body of 18 × 3.3 mm.
- **Hub board:** the size, the four mounting holes (`HUB_POSTS`) and the socket positions (`yk4_opening`, `yk5_recess`, `plug_opening`).

## Render

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w openscad/openscad:2021.01 \
  openscad -D 'part="body"' -o stl/yubikey-touch-body.stl fixture.scad
```

The parts are `body`, `deck`, `lid`, `test` and `assembly` (all three in place, for viewing only).

## Assembly order

1. Press each pogo pin up through the hole in the drawer floor and the bore until it stops at the chamber ceiling.
2. Press in the M2 heat-set inserts with the Pinecil insert tip at about 220 °C. The plastic melts into the knurls and holds them.
3. Plug both adapters into the hub, then lower the hub onto its posts.
4. Fit the deck, the switch boards and the RP2040-Zero, which slides onto the U-turn plug. Then wire the power.
5. Thread each touch wire through its channel and solder it to the pin through the side window. The joint is too wide to slip down the bore, so it also stops the pin from dropping out.
6. Drop the lid in 1 mm south, slide it north so the tab enters the wall slot, and fit the two M2×6 screws.

## Firmware

`firmware/` holds the RP2040-Zero program and `firmware/yk-touch`, a small host script that
sends it commands. Use the fixture only with test keys: whatever key sits in it can be
"touched" by any program that can open the serial port.

### Pins

The map lives in `firmware/pins.h`. Change it there and in this table.

| GPIO | Function |
|---|---|
| GP2 | YubiKey 4 touch (pogo pin) |
| GP3 | YubiKey 5 touch (pogo pin) |
| GP4 | YubiKey 4 power switch |
| GP5 | YubiKey 5 power switch |

GP16 is the onboard WS2812 LED and stays unused.

**Power polarity:** `POWER_ACTIVE_HIGH 1`. GPIO high turns the 2N7002 on, which pulls the
AO3401 gate low and powers the key. During reset the pins sit at their pull-down default,
so the keys stay off until the firmware runs.

**Touch:** a touch drives the pogo pin low (to GND), a release makes it a high-impedance
input with the pulls off. The firmware never drives a touch pin high: its output latch is
0 and the pad's output is forced low, so only the direction changes.

### Build

```bash
tools/yubikey-touch/firmware/build.sh
```

It needs Docker and works from any directory. It builds the toolchain image (Ubuntu 24.04
pinned by digest, pico-sdk 2.3.1 and picotool 2.3.1 pinned by commit), runs the host test
of the command protocol (`test_protocol.c`) and writes
`tools/yubikey-touch/firmware/build/yubikey-touch.uf2`, owned by you.

### Flash

- **First time:** hold the BOOT button while plugging the RP2040-Zero in. It shows up as a
  drive named `RPI-RP2`. Copy `yubikey-touch.uf2` onto it and the board reboots into the
  firmware.
- **Later:** run `yk-touch bootsel` and copy the `.uf2` the same way, without opening the
  lid. Opening the port at 1200 baud does the same.

### Use

The board is a USB serial device named `YubiKey touch fixture`. On Linux, `yk-touch` finds it
under `/dev/serial/by-id/`. On macOS, pass its `/dev/cu.usbmodem*` device with `-d`, or set
`YK_TOUCH_DEV`.

```bash
firmware/yk-touch status            # OK yk4 power=on touch=released yk5 power=on touch=released
firmware/yk-touch touch yk5 500     # touch the YubiKey 5 for half a second
firmware/yk-touch power yk4 off
```

| Command | Effect |
|---|---|
| `touch <key> <ms>` | Touch for 1 to 10000 ms. Returns at once; a new `touch` restarts the time |
| `hold <key>` | Touch until `release` |
| `release <key\|all>` | Release the touch, cancelling a timed one |
| `power <key\|all> on\|off` | Switch the key's power |
| `status` | Power and touch of each key |
| `version`, `help` | Firmware version, command list |
| `bootsel` | Reboot into the USB bootloader |

Keys are `yk4` and `yk5`. The protocol is one ASCII line per command (at most 64 bytes, `\n`
or `\r\n`), answered by one line: `OK …` or `ERR <reason>`. `yk-touch` exits 0 on `OK`, 1 on
`ERR`, and 2 on a timeout or a missing device.

**Boot state:** both touches released, then both keys powered, as if plugged in directly.

**Release before power-up:** a key calibrates its touch sensor when it powers up, so a pin
held down then would be taken as the untouched state. `power on` therefore releases the
key's touch and waits 10 ms before switching the power on, and `power off` releases it
before cutting the power. `touch` and `hold` on a key that is off fail with `ERR key off`.
