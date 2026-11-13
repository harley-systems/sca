# YubiKey touch fixture (rev G)

A printed holder that presses a pogo pin onto the touch pad of a YubiKey 4 (USB-A) and a
YubiKey 5 NFC (USB-C), so an RP2040-Zero can "touch" each key by grounding its pin. It also
switches each key's power. Use it only with test keys: it removes the user-presence check.

`fixture.scad` is the source. The `stl/` files are rendered from it, already turned the right way up for printing:

| File | What | Print |
|---|---|---|
| `stl/yubikey-touch-test.stl` | North drawer, pin tower and the north strip of the box, with its hub pads and fences | First: sit the hub on it with a YubiKey 4 to check the socket-face seat, the key height, the pin over the button and the pin lift. Print one knob and one bar with it |
| `stl/yubikey-touch-body.stl` | Box, both drawers, towers, insert blocks | Floor on the bed |
| `stl/yubikey-touch-deck.stl` | Board tray above the hub | Flat |
| `stl/yubikey-touch-lid.stl` | Lid with hold-down ribs | Top face on the bed |
| `stl/yubikey-touch-knob.stl` | Square knob that holds the pogo pin | Standing up, one per pin. Use a brim: it is tall and thin |
| `stl/yubikey-touch-bar.stl` | Slide bar that lifts the knob | Flat, one per pin |

`yubikey-touch-fixture.mp4` is an animation of the assembly. It still shows rev F.

## Print settings (Prusa, PLA)

- 0.4 mm nozzle, 0.2 mm layers (0.15 mm for the test piece and body, for cleaner small holes)
- No supports. The tunnel roofs and wall openings bridge, and the insert blocks and lid ledges have 45° undersides.
- 3 perimeters and 20 % infill

## Pin lift

A pogo pin resting on the key jams it: the pin tip drops into the dip around the gold touch disk, and pulling
the key pushes sideways on the tip, so the spring never compresses. So the pin is lifted before a key goes in
or out:

- The pin is pressed into a square knob that slides straight up and down in a square hole in the tower. It
  can't turn, so the wire can't twist.
- A short piece of 1.75 mm filament crosses the knob just above the top of the pin and sticks out through a
  slot in the tower's west wall into a slanted slot in the slide bar.
- Push the bar **north** (toward the drawer's open end, for the YubiKey 4 drawer): the knob rises
  `pin_lift` (2.5 mm) and the key slides freely. Push it **south**: the pin presses onto the disk with
  `pin_press` (1 mm) of spring travel. The slot is flat at both ends, so the bar stays where you leave it.
- The knob sticks out 1.5 mm above the tower when the pin is down and 4 mm when it is up, so you can see which.

## Check before printing the body

Rev G is laid out from parts measured with calipers. Every position is derived from a few datums at the
top of `fixture.scad`, so a correction is one line. These are still assumed, not measured:

- **A1** The hub board is 32.3 mm along the socket edges (x) and 35.5 mm along the USB-C edge (`hub_w`, `hub_l`).
- **A2** "3.6 above the board" is the top of the A socket shell above the board's top face, with a 7.0 mm
  shell (`sock_above`, `sock_h`), so the socket centre sits about at the board plane.
- **A3** "RP2040 15.4 above the board" is the RP2040-Zero's PCB underside above the hub board top (`rp_above`).
  Its total height to the top of its USB-C socket is taken as 4.4 mm (`rp_h`).
- **A4** "Reaches 2.5 below its plug" is measured from the underside of the U-turn's A plug (`uturn_below`).
- **A5** The U-turn is taken as 12 mm wide (`uturn_w`), centred on the far south socket (`uturn_x`, x 25.4).
  Its depth in ty isn't measured: the deck notch (x 18.9 to 31.9) runs 8.5 mm south of the south socket face,
  and the RP2040's north edge is at ty 16.8 (`rp_t0`). The RP2040, its cradle posts and the lid's hold-down
  are centred on the U-turn; the lid rib over the south-west switch board stops 0.5 mm short of the RP2040.
- **A6** The north edge has one A socket (the YubiKey 4's) and the south edge two, the far one mirrored
  (`sock_x2`); shells 13.1 mm wide (`sock_w`). The corner pads must stay clear of them.
- **Board thickness:** `hub_t` (1.6 mm). RP2040-Zero PCB thickness: `rp_pcb_t` (1.0 mm).
- **Hub USB-C input:** taken as centred on the board's west edge (`usbc_ty`) and on the board's mid-plane
  (`usbc_z`). They place the plug opening in the west wall and the gap in the west lid ledge.
- **Key height in the tunnel:** `yk4_dz` and `yk5_dz`, the key body centre above its connector centre (0).
  With `pin_len` and `pin_press` they set how hard the pin presses.

The test piece checks A1, A2 and the key height before the full body is printed. Rendering fails with an
`assert` message if a change puts the U-turn or the RP2040 within 1 mm of the lid, the U-turn within 0.5 mm
of the floor, a pad over a socket, a socket off the board, the deck notch on the U-turn, a lid rib on the
RP2040, a wire channel outside the box, or a bar wall under 1.8 mm.

## Render

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w openscad/openscad:2021.01 \
  openscad -D 'part="body"' -o stl/yubikey-touch-body.stl fixture.scad
```

The parts are `body`, `deck`, `lid`, `knob`, `bar`, `test`, `assembly` (everything in place, for viewing only) and `test_assembly` (the test piece with its knob and bar; add `-D lift_up=true` to see the pin lifted). Each render
echoes the derived pin positions, hub and socket heights, box height and filament length.

## Firmware

`firmware/` is the RP2040-Zero program (C, pico-sdk). It shows up on USB as a serial port named
"YubiKey touch".

| RP2040 pin | Goes to |
|---|---|
| GP0 | YubiKey 4 pogo pin (touch) |
| GP1 | YubiKey 5 pogo pin (touch) |
| GP2 | YubiKey 4 power switch (2N7002 gate) |
| GP3 | YubiKey 5 power switch (2N7002 gate) |
| GND | Hub ground (shared with the keys) |

A touch drives the pin low, which grounds the pad like a finger. Released, the pin floats; it is never
driven high. Both keys power up at boot with the touch released, because a key calibrates its touch
sensor at power-up. The on-board LED is dim green when ready and blue while touching.

Build and install:

```bash
firmware/build.sh            # builds firmware/build/yktouch.uf2 in Docker
```

Hold BOOT while plugging the board in (or, once it runs this firmware, open its port at 1200 baud) and
copy `yktouch.uf2` onto the `RPI-RP2` drive. To let your user open the serial port without the
`dialout` group:

```bash
sudo cp 70-yktouch.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger
```

Commands (one line each, every reply starts with `ok` or `err`):

```bash
./yktouch touch 5            # touch the YubiKey 5 for 500 ms
./yktouch touch 4 1500       # touch the YubiKey 4 for 1.5 s
./yktouch hold 5             # touch until released
./yktouch release 5
./yktouch power 4 off        # also: power 4 on
./yktouch cycle 5 [ms]       # power off for ms (default 1000), then on
./yktouch status
```

## Assembly order

1. Press in the M2 heat-set inserts with the Pinecil insert tip at about 220 °C. The plastic melts into the knurls and holds them.
2. Plug both adapters into the hub, then set the hub on its pads inside the fences.
3. Fit the deck, the switch boards and the RP2040-Zero, which slides onto the U-turn plug. Then wire the power.
4. Fit each pin lift:
   1. Push the touch wire through its channel from the box until it comes out of the slot on the box side of the tower. Pull out a few centimetres.
   2. On the bench, solder the wire to the **side** of the pin barrel, within 1 mm of its top end. Keep the top end itself clean: the filament presses on it.
   3. Drop the pin into the knob from the top, tip first, with the wire lying in the knob's side slot. The solder joint rests on the floor of the slot, which stops the pin from falling through.
   4. Slide the bar into the sleeve on the tower's west face, pushed south. Drop the knob into the tower with its wire slot facing the box.
   5. Cut 8.3 mm of 1.75 mm filament and push it through the sleeve window, the bar slot and the tower slot into the knob's cross hole, until it stops against the far wall.
   6. Gently pull the extra wire back into the box.
5. Drop the lid in 1 mm south, slide it north so the tab enters the wall slot, and fit the two M2×6 screws.
