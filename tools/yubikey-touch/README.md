# YubiKey touch fixture (rev F)

A printed holder that presses a pogo pin onto the touch pad of a YubiKey 4 (USB-A) and a
YubiKey 5 NFC (USB-C), so an RP2040-Zero can "touch" each key by grounding its pin. It also
switches each key's power. Use it only with test keys: it removes the user-presence check.

`fixture.scad` is the source. The `stl/` files are rendered from it, already turned the right way up for printing:

| File | What | Print |
|---|---|---|
| `stl/yubikey-touch-test.stl` | North drawer and pin tower only | First, about 45 min: checks the key fit and the pin lift. Print one knob and one bar with it |
| `stl/yubikey-touch-body.stl` | Box, both drawers, towers, insert blocks | Floor on the bed |
| `stl/yubikey-touch-deck.stl` | Board tray above the hub | Flat |
| `stl/yubikey-touch-lid.stl` | Lid with hold-down ribs | Top face on the bed |
| `stl/yubikey-touch-knob.stl` | Square knob that holds the pogo pin | Standing up, one per pin. Use a brim: it is tall and thin |
| `stl/yubikey-touch-bar.stl` | Slide bar that lifts the knob | Flat, one per pin |

`yubikey-touch-fixture.mp4` is an animation of the assembly.

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

Some dimensions come from listings and datasheets, not from the parts in hand. They are
parameters at the top of `fixture.scad`:

- **Pin position under each touch pad:** `pin_ty_yk4` and `pin_ty_yk5`. The test piece showed the pad centre is about 29 mm from the plug tip (YubiKey 4, Security Key and 5C alike). In rev E the pins sit about 7 mm too far from the hub, so move them once the hub's socket faces are measured: pin = plug tip position − 29 mm.
- **Pin height:** `pin_len` (barrel top to tip, plunger out) and `pad_z` (height of the touch disk in the tunnel). Together they set how hard the pin presses.
- **Key tunnel:** 18.3 × 5.2 mm, for a key body of 18 × 3.3 mm.
- **Hub board:** the size, the four mounting holes (`HUB_POSTS`) and the socket positions (`yk4_opening`, `yk5_recess`, `plug_opening`).

## Render

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w openscad/openscad:2021.01 \
  openscad -D 'part="body"' -o stl/yubikey-touch-body.stl fixture.scad
```

The parts are `body`, `deck`, `lid`, `knob`, `bar`, `test`, `assembly` (everything in place, for viewing only) and `test_assembly` (the test piece with its knob and bar; add `-D lift_up=true` to see the pin lifted).

## Assembly order

1. Press in the M2 heat-set inserts with the Pinecil insert tip at about 220 °C. The plastic melts into the knurls and holds them.
3. Plug both adapters into the hub, then lower the hub onto its posts.
4. Fit the deck, the switch boards and the RP2040-Zero, which slides onto the U-turn plug. Then wire the power.
5. Fit each pin lift:
   1. Push the touch wire through its channel from the box until it comes out of the slot on the box side of the tower. Pull out a few centimetres.
   2. On the bench, solder the wire to the **side** of the pin barrel, within 1 mm of its top end. Keep the top end itself clean: the filament presses on it.
   3. Drop the pin into the knob from the top, tip first, with the wire lying in the knob's side slot. The solder joint rests on the floor of the slot, which stops the pin from falling through.
   4. Slide the bar into the sleeve on the tower's west face, pushed south. Drop the knob into the tower with its wire slot facing the box.
   5. Cut 7.5 mm of 1.75 mm filament and push it through the sleeve window, the bar slot and the tower slot into the knob's cross hole, until it stops against the far wall.
   6. Gently pull the extra wire back into the box.
6. Drop the lid in 1 mm south, slide it north so the tab enters the wall slot, and fit the two M2×6 screws.
