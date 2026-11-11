# YubiKey touch fixture (rev F)

A printed holder that presses a pogo pin onto the touch pad of a YubiKey 4 (USB-A) and a
YubiKey 5 NFC (USB-C), so an RP2040-Zero can "touch" each key by grounding its pin. It also
switches each key's power. Use it only with test keys: it removes the user-presence check.

Each pin sits in a square knob that slides up and down in its tower. A slide bar on the tower's
west side lifts the pin 2.5 mm off the key, so the key slides in and out freely, and lowers it
back onto the touch disk. Nothing turns, so the pin and its wire never twist.

`fixture.scad` is the source. The `stl/` files are rendered from it, already turned the right way up for printing:

| File | What | Print |
|---|---|---|
| `stl/yubikey-touch-test.stl` | North drawer and pin tower only | First, with a knob and a bar: checks the key fit, pin bore, floor hole, solder window and the lift mechanism |
| `stl/yubikey-touch-body.stl` | Box, both drawers, towers, insert blocks | Floor on the bed |
| `stl/yubikey-touch-knob.stl` | Pin knob, one per drawer (print two) | Upright, as in the file, so the pin bore comes out round |
| `stl/yubikey-touch-bar.stl` | Slide bar, one per drawer (print two; the same part fits both) | Flat, as in the file |
| `stl/yubikey-touch-deck.stl` | Board tray above the hub | Flat |
| `stl/yubikey-touch-lid.stl` | Lid with hold-down ribs | Top face on the bed |

`yubikey-touch-fixture.mp4` is an animation of the rev E assembly, before the lift mechanism.

## Print settings (Prusa, PLA)

- 0.4 mm nozzle, 0.2 mm layers (0.15 mm for the test piece and body, for cleaner small holes)
- No supports. The tunnel roofs and wall openings bridge, and the insert blocks and lid ledges have 45° undersides.
- 3 perimeters and 20 % infill
- If the 1.2 mm pin bore comes out tight, ream it with a 1.1 mm drill in the pin vise. The same goes for
  the 1.75 mm filament hole in the knob: the filament should be a press fit.

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

The parts are `body`, `deck`, `lid`, `test`, `knob`, `bar` and `assembly` (everything in place, for
viewing only; add `-D 'lifted=true'` to see the pins lifted).

## Assembly order

1. Fit the lift mechanism in each drawer:
   1. Drop the knob into the square hole in the tower, its solder slot facing the box and the drawer mouth.
   2. Slide the bar into the channel on the tower's west side from the drawer-mouth end, grip outwards.
   3. Lift the knob until its cross hole lines up with the tower's side slots, then push an 11 mm piece of
      1.75 mm filament from the west through the channel's slot, the bar's slot, the knob and out of the
      east slot. Its west end should sit flush with the bar.
   4. Push the bar in and pull it out a few times: it should hold at both ends.
   5. Press the pogo pin up through the hole in the drawer floor and the bore into the knob until it
      stops on the ceiling of the solder slot.

   **Bar pushed in towards the box: pin pressed onto the key. Bar pulled out towards the drawer mouth: pin lifted.**
2. Press in the M2 heat-set inserts with the Pinecil insert tip at about 220 °C. The plastic melts into the knurls and holds them.
3. Plug both adapters into the hub, then lower the hub onto its posts.
4. Fit the deck, the switch boards and the RP2040-Zero, which slides onto the U-turn plug. Then wire the power.
5. Thread each touch wire through its channel from the box. It comes out in the tower's box-side window.
   Solder it to the pin through the window on the drawer-mouth side. The joint is too wide to slip down
   the bore, so it also stops the pin from dropping out. Leave a small slack loop in the window: the wire
   flexes 2.5 mm every time the bar moves, so use stranded, silicone-insulated 30 AWG.
6. Drop the lid in 1 mm south, slide it north so the tab enters the wall slot, and fit the two M2×6 screws.
