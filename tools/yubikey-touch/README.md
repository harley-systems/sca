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
