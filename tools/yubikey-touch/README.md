# YubiKey touch fixture

A small printed box that lets a computer touch two YubiKeys. A pogo pin rests on each key's touch disk,
and an RP2040-Zero grounds it on command, which the key reads as a finger. That lets the YubiKey
operations that wait for a touch run in tests with nobody at the desk: a PIV key with a touch policy
(see [Enable Touch Policy](../../docs/yubikey.md#enable-touch-policy)), FIDO, and OTP. It holds a
YubiKey 4 (USB-A) and a YubiKey 5C NFC (USB-C), and can also switch each key's power, so a test can
unplug and replug a key without anyone touching it.

> **Test keys only.** The touch is how a YubiKey knows a person is present. This fixture fakes it, so
> never put a key that protects anything real in it.

![The assembled fixture with its lid on, plugged into a laptop](photos/fixture-closed.jpg)

![The same fixture with the lid off: the RP2040-Zero, the switch boards and the wiring](photos/fixture-open.jpg)

The fixture as built, closed and with the lid off. The YubiKey 4 lies in the drawer on the left; each tower
holds the pogo pin over a key's touch disk.

![Plan and cut of the fixture, with the measurements](layout.svg)

![Assembly animation](yubikey-touch-fixture.gif)

The animation is also in full size as [yubikey-touch-fixture.mp4](yubikey-touch-fixture.mp4).

**Explainer video:** [yubikey-touch-explainer.mp4](yubikey-touch-explainer.mp4) tells in two minutes why the
fixture exists, how it works, how it was built and what it costs
([subtitles](yubikey-touch-explainer.srt)).

## Status (rev I, November 2026)

| Part | State |
|---|---|
| Touch | **Works.** With the YubiKey 4 in the rev G test piece and its pin wired to GP0, `yktouch touch 4 500` was accepted 6 times out of 6: a FIDO registration that waits for a touch went through about 0.4 s after the touch began, and nothing registered in the 3 s before each touch. A finger on the bare wire works too. In the assembled rev I fixture `yktouch touch 4 500` makes the key type its one-time code every time. |
| Printed parts | Rev I is printed and assembled, see the photos above. It fixes the five faults of the printed rev H (a mirror-image lid, a slide bar with no room, thin tower walls, RP2040 supports that were too high, switch boards with nothing to hold them), see [Rev I](#rev-i-from-the-printed-rev-h-parts). The lid and deck changed once more to print cleanly, see [Rev I2](#rev-i2-from-the-first-rev-i-lid-and-deck); the lid in the photos is the first rev I shape. The rev I lid, deck and slide bar also fit a rev H body. |
| YubiKey 5 touch | Same design and wiring as the YubiKey 4 side. |
| Power switching | **Works.** `yktouch power 4 off` takes the key off USB and `power 4 on` brings it back; built as in [Wiring](#wiring). |

## How it works

- **Touch.** A pogo pin is held on each key's touch disk and wired to a GPIO of the RP2040-Zero. To touch,
  the GPIO goes low and grounds the disk; to let go, it becomes a floating input. It is never driven high.
- **Pin lift.** A pin resting on the disk would jam the key on its way in or out, so a slide bar lifts the
  pin 2.5 mm first. See [Pin lift](#pin-lift).
- **Power.** Each key's 5 V goes through a switch (an AO3401 driven by a 2N7002) that the RP2040 opens and
  closes. A key calibrates its touch sensor when it powers up, so the touch is always released first.
- **Host side.** The RP2040 shows up as a serial port named "YubiKey touch"; the `yktouch` script sends it
  commands such as `touch 4 500`. See [Firmware](#firmware).

## Wiring

![Wiring: laptop, hub, adapters, keys, RP2040 and the power switches](wiring.svg)

Everything hangs off one 4-port USB 2.0 hub board. The RP2040-Zero plugs into one of its ports through
the U-turn adapter, so it shares the keys' ground and needs no ground wire for the touch. Its GP0 and
GP1 go straight to the two pogo pins.

For power switching, the hub's 5 V trace to each key's socket has to be cut, and an AO3401 put across
the cut: source on the hub side, drain on the socket side, with 10k from gate to source so it stays off on
its own. A 2N7002 pulls the gate to ground when the RP2040 drives GP2 or GP3 high. Each transistor sits
on a small SOT-23 board whose pads are numbered 1 (gate), 2 (source) and 3 (drain). In the
built fixture the socket's 5 V leg is lifted off its pad instead of the trace being cut, with the switch
wired between the pad and the leg.

## Parts

Prices as paid on AliExpress in October and November 2026, converted to US dollars at 3.21 ILS per USD
(the rate on 14 November 2026) and rounded. Most parts come in packs, so a second fixture costs little more. Listings change and disappear; the description says what to look for.

| Part | For | Used | Bought | USD |
|---|---|---|---|---|
| [RP2040-Zero](https://www.aliexpress.com/item/1005010768723373.html) (Waveshare layout) | Runs the firmware | 1 | 4 | 6.15 |
| [USB 2.0 hub board, 4 x USB-A, USB-C in](https://www.aliexpress.com/item/1005009184792924.html) | Everything plugs into it | 1 | 1 | 2.24 |
| [Pogo pins P75-D2](https://www.aliexpress.com/item/1005010463299946.html) | Rest on the touch disks | 2 | 100 | 7.97 |
| [USB adapters, Xinrongbao](https://www.aliexpress.com/item/1005006733624983.html), one listing, three versions | "A-C U Forward" (U-turn): hub to the RP2040; plugged into the hub it bends up over the board ("A-C U Reverse" bends down, into the board). "C-A Forward": YubiKey 5 to the hub. "A-C Forward": the laptop's USB-A port to the hub's USB-C input | 3 | 3 | 7.48 |
| [AO3401A P-channel MOSFET, SOT-23](https://www.aliexpress.com/item/4001278105988.html) | Power switches | 2 | 100 | 1.80 |
| [2N7002 N-channel MOSFET, SOT-23](https://www.aliexpress.com/item/1005006127106855.html) | Drive the AO3401 gates | 2 | 100 | 1.62 |
| [SOT-23 to SIP3 boards](https://www.aliexpress.com/item/1005006626188055.html) | Carry the transistors; 7.5 x 10 x 1.4 mm | 4 | 20 | 1.62 |
| [Resistor kit, 1/4 W, 30 values](https://www.aliexpress.com/item/1005006186890215.html) | 10k gate resistors | 2 | 600 | 2.43 |
| [Wire, 30 AWG, UL1423 PTFE, silver-plated](https://www.aliexpress.com/item/1005005321856209.html) | Touch and power wiring | about 1 m | 3 x 5 m | 4.94 |
| [Heat-shrink tube set](https://www.aliexpress.com/item/1005012934091641.html) | Insulating joints | | 8 m | 2.52 |
| [M2 brass heat-set inserts, 3 mm long](https://www.aliexpress.com/item/1005008897571758.html) | Lid screws | 2 | 100 | 2.86 |
| [M2 x 6 socket head screws](https://www.aliexpress.com/item/1005004531602992.html) | Lid | 2 | 50 | 1.25 |
| PLA, 1.75 mm | The printed parts (about 46 g) and two 9 mm pieces as cross pins | | | |
| [NNBILI USB-C male to male adapter](https://www.aliexpress.com/item/1005012016929409.html) | Optional: for a laptop with only USB-C ports, instead of "A-C Forward" | 0 or 1 | 1 | 1.55 |
| YubiKey 4, YubiKey 5C NFC | Test keys | 2 | | |

The parts above came to about $43. Tools used for this build:

| Tool | For | USD |
|---|---|---|
| [Pinecil V2](https://www.aliexpress.com/item/1005012505708387.html) soldering iron | Soldering | 53.67 |
| [Heat-set insert tips for the Pinecil (TS100 fit)](https://www.aliexpress.com/item/1005012157318263.html) | Pressing in the inserts | 7.28 |
| [Solder, 0.6 mm rosin core](https://www.aliexpress.com/item/1005006280566767.html), [flux NC-559](https://www.aliexpress.com/item/1005011861136037.html), [desoldering wick](https://www.aliexpress.com/item/1005007514789306.html) | Soldering | 9.18 |
| [Wire stripper, Pro'sKit 8PK-3001D](https://www.aliexpress.com/item/1005007370026286.html) | 30 AWG wire | 13.82 |
| [Digital calipers, 150 mm](https://www.aliexpress.com/item/1005011855690153.html) | Measuring the parts | 3.83 |
| [Anti-static tweezers](https://www.aliexpress.com/item/1005013152490978.html) | Small parts, pulling the wire through the tower | 2.61 |
| [7 inch digital microscope](https://www.aliexpress.com/item/1005009301431172.html), [helping hands](https://www.aliexpress.com/item/4001365281239.html), [iron stand](https://www.aliexpress.com/item/1005002842145055.html) | SOT-23 soldering | 56.37 |
| [Hand drill (pin vise), 0.2 to 3.4 mm](https://www.aliexpress.com/item/1005007092447606.html) | Clearing small holes | 3.18 |
| [Hex keys](https://www.aliexpress.com/item/1005002688809650.html) | The M2 screws | 3.48 |
| 3D printer (Prusa MK3S, smooth PEI sheet) | The printed parts | |

## Files

`fixture.scad` is the source. The `stl/` files are rendered from it, already turned the right way up for printing:

| File | What | Print |
|---|---|---|
| `stl/yubikey-touch-test.stl` | North end: wall, hub seat, YubiKey 4 drawer and tower | First: put the hub in, plug the YubiKey 4 in and check the pin lands on the button. Print one knob and one bar with it |
| `stl/yubikey-touch-body.stl` | Box, hub seat, both drawers, towers, insert blocks | Floor on the bed |
| `stl/yubikey-touch-deck.stl` | Deck above the hub, with a drawer for each switch board | Flat, before the lid |
| `stl/yubikey-touch-lid.stl` | Lid with its hold-down column | Top face on the bed, after the deck |
| `stl/yubikey-touch-knob.stl` | Square knob that holds the pogo pin | Standing up, one per pin. Use a brim: it is tall and thin |
| `stl/yubikey-touch-bar.stl` | Slide bar that lifts the knob | Flat, one per pin, no brim. No glue on a smooth PEI sheet: let it cool and flex the sheet |

| Other files | What |
|---|---|
| `layout.svg`, `wiring.svg` | The drawings above, made by `drawings/make.sh` (see [Render](#render)) |
| `photos/` | Photos of the built fixture |
| `yubikey-touch-fixture.mp4`, `.gif` | The assembly animation, made by `drawings/animate.sh` |
| `yubikey-touch-explainer.mp4`, `.srt` | The explainer video and its subtitles |
| `explainer/` | What the explainer video is built from, see [Explainer video](#explainer-video) |
| `firmware/` | The RP2040-Zero program |
| `yktouch` | Host script that sends commands to the RP2040 |
| `70-yktouch.rules` | udev rule so your user can open the serial port |

## Print settings (Prusa, PLA)

- 0.4 mm nozzle. 0.15 mm layers for the body, the test piece, the knobs and the bars, for cleaner small holes; 0.2 mm for the lid and the deck, whose steps are all multiples of 0.2 mm
- No supports. The tunnel roofs and wall openings bridge, and the insert blocks, the lid ledges, the lips of the deck's drawers and the lid's tabs have 45° undersides.
- 3 perimeters and 20 % infill for the body and the test piece (PrusaSlicer's stock profile has 2 and 15 %). 4 perimeters and 100 % infill for the lid, the deck, the knobs and the bars: they are small and their thin parts carry the load
- A 4 mm brim for the knobs; none is needed for the rest
- The deck and the lid go on one plate but print one after the other, the deck first (PrusaSlicer: *Complete individual objects*, the two parts 50 mm apart), with the nozzle kept inside the part when it moves (*Avoid crossing perimeters*). Above its plate each of them is one closed outline, so the nozzle then hardly ever crosses open air, which is where strings form
- PLA on the smooth PEI sheet needs no glue; glue stick makes small parts very hard to remove

## Pin lift

A pogo pin resting on the key jams it: the pin tip drops into the dip around the gold touch disk, and pulling
the key pushes sideways on the tip, so the spring never compresses. So the pin is lifted before a key goes in
or out:

- The pin is pressed into a square knob that slides straight up and down in a square hole in the tower. It
  can't turn, so the wire can't twist.
- A short piece of 1.75 mm filament crosses the knob just above the top of the pin and sticks out through a
  slot in the tower's west wall into a slanted slot in the slide bar.
- Push the bar **north** (away from the box for the YubiKey 4 drawer, toward it for the YubiKey 5): the knob rises
  `pin_lift` (2.5 mm) and the key slides freely. Push it **south**: the pin presses onto the disk with
  `pin_press` (1 mm) of spring travel. The slot is flat at both ends, so the bar stays where you leave it.
- The knob sticks out 1.5 mm above the tower when the pin is down and 4 mm when it is up, so you can see which.
- The bar is loose in its sleeve on purpose: 0.65 mm across and 0.5 mm up and down. The pin's spring holds the bar
  up against the roof of the sleeve while the pin is down, and the bar rests on the sleeve's floor while the pin is
  up. The slot in the bar is placed for those two positions, so the play costs no press and no lift.
- The bar is the same turned end for end. Turned over, face for face, it works the other way round: if pushing it
  south lifts the pin, take it out and turn it over.
- The touch wire is soldered to the pin on the bench, never in place (there is no room in the tower, and the
  iron would melt it). It leaves the knob through a side slot facing the box, runs down a slot in the tower's
  box-side wall that is open at the top, and goes through a channel in the sloped rib into the box.

## Rev I, from the printed rev H parts

- **The lid was a mirror image.** The model turned the lid over for printing with a mirror, and a mirror makes the
  opposite-handed part: its ribs landed on the RP2040 and its screw holes missed the inserts. The lid is now turned
  over with a rotation. Rule for `fixture.scad`: after `out()`, only `rotate()` and `translate()`.
- **The slide bar had no room.** It was 8.5 mm tall in an 8.8 mm opening and 2.4 mm thick in a 2.65 mm one, and a
  part's first layer spreads by about that much. The bar is now 15 × 8.3 × 2.0 mm with chamfered edges; the sleeve
  opening is unchanged.
- **Thin places on the towers broke.** The towers are 9 mm square (walls 2.55 mm, were 1.55), the sleeve's walls and
  roof are 1.6 mm (were 0.8), and the sloped rib is built around the wire channel: the channel had under 0.4 mm of
  plastic around it for most of its length and now has 1.2 mm all the way. The channel is 2 mm across (was 1.6) and
  the slots the filament moves in are 2.4 mm wide (were 2.0), so they need no clearing after printing.
- **Nothing held the switch boards.** Each board now slides into a drawer on the deck: two rails with lips over its
  long edges, an end stop with a lip, and a low sill its tail drops behind. The lid's four long board ribs are gone.
- **The RP2040 supports were several mm too high**, so the board sat at an angle. Its height (`mcu_z`) has to be
  measured again; until then the deck has no supports (`mcu_support = false`) and the RP2040 hangs on its plug.
- The lid has two short tabs near the ends of the wall slot in place of one long one, 0.8 mm long (was 1.0), with
  sloped tops that print cleanly; that leaves 0.5 mm to spare as the lid drops in (was 0.3).

## Rev I2, from the first rev I lid and deck

Only the lid and the deck changed; the body, the knobs and the bars are as in rev I.

- **The lid and the deck came out covered in strings, and the lid's two tall posts came out lumpy.** The lid had
  four posts. The two that held the deck down were 2 mm square and 17 mm tall, and for the top 12 mm of the print
  they were all that was left: each layer took 1.7 s, too short for the plastic to set, and the nozzle hopped the
  34 mm between them twice per layer. Over the whole print the nozzle crossed open air 478 times, many of them
  across the deck's drawers. The filament may have been damp as well.
- **The lid has one hold-down**: a cross-shaped column, 11 × 9 mm with 1.8 mm walls, over the hub socket that
  nothing plugs into, where the deck rests. It stops 0.3 mm above the deck. It keeps the deck on the sockets and,
  through the deck, the hub on its pads; nothing else holds either of them down.
- **The deck's centre rail runs through** and joins the two drawer blocks, so the deck is one piece above its
  plate. Each wire slot is now two shorter ones, either side of the rail.
- The two short posts over the RP2040 are gone until its height is measured (`mcu_support`). The column then gets
  an arm that reaches over the RP2040's far end.
- Printed one after the other with the nozzle kept inside the outlines (see [Print settings](#print-settings-prusa-pla)),
  the two parts need 15 moves over open air, none of them above the deck's height, and the column gets 4.9 s per layer.

## Rev H, from the printed rev G body

- The hub with its adapters was a hard push into the box: the inside was exactly as long as they are, and the
  fences were 0.15 mm from the board. Now the inside is 1 mm longer (`slack`) and 1 mm wider, and the fences
  are 0.5 mm from the board (`fit`). Each pin sits over the middle of its button with the hub in the middle
  of its 1 mm of travel. The end walls have 1 mm pockets around the key openings, so each key still plugs all
  the way in when the hub rests against the other wall.
- The YubiKey 5 adapter hung from its socket at no set height, so the key had to find it blind. A cradle at
  the south wall (`yk5_cradle`) now holds the adapter's USB-C end where the key, lying on its floor, plugs in
  straight.
- The deck pockets and lid ribs fit the switch boards as they came (7.5 × 10 × 1.4, rev G guessed 7 × 9).

## Layout (rev G and H, measured)

The hub, the adapters and the keys were measured with calipers. `fixture.scad` places everything from these
numbers:

| What | Measured | Used for |
|---|---|---|
| Hub board | 32.3 (along the USB-C edge) × 35.5, no mounting holes | Corner pads and fences (`hub_seat`) |
| A sockets | Stick out 2.85 past the board edge, top 3.6 above the board, near ones centred 9.2 from the USB-C edge | Hub position: the north socket faces touch the inside of the north wall |
| YubiKey 5 adapter | Its USB-C face is 63.0 from the north socket face | Inside of the south wall (plus `slack`); the adapter face bears on it |
| YubiKey 5 adapter body | 14.5 wide × 7.0 tall; in the rev G body, with the key flat, its top was 19.8 below the wall top | Cradle seat at 3.95 above the bed, 0.4 clear each side |
| Switch boards (AO3401, 2N7002) | 7.5 × 10.0, 1.4 thick, SOT-23 transistor 2.9 × 1.4 | Deck drawers (`brd`, `BOARDS`, `board_drawer`) |
| U-turn adapter | 25.1 tall, reaches 2.5 below its plug | Box height (lid 0.8 above it) |
| RP2040 | Board bottom 15.4 above the hub board (to be measured again, see below), lined up with the hub's east edge | Deck supports and the lid's arm over the RP2040 (both off until it is measured) |
| YubiKey 4 in the hub | Socket face to button start 12.8, button 10 across | `pin_ty_yk4` (button centre 17.8 out from the socket face) |
| YubiKey 5 in its adapter | Adapter face to button start 14.7 | `pin_ty_yk5` (19.7 out from the adapter face) |

Still estimated (marked MEASURE in `fixture.scad`):

- `yk4_plug_gap`: the gap under the YubiKey 4's plug when the key lies flat. It sets the hub height, so the key lies on its tunnel floor.
- `yk5_plug_gap`: the same for the YubiKey 5 in its adapter. It sets how much the south drawer is raised.
- `hub_t` (board thickness, 1.6 assumed) and `yk5_neck` (the hole in the south wall for the plug end of the YubiKey 5).
- `mcu_z` and `mcu_t`: how far the RP2040's underside is above the hub board, and how thick its board is. The rev H supports, built to 15.4, held the board several mm too high. Measure, set both, and set `mcu_support = true` to get the supports on the deck and the arm on the lid's column. The deck's supports are still two thin posts in the model; make them one wall joined to a drawer rail first, or they will print as badly as the lid's posts did.
- `pad_z` and `pin_press`: if the pin doesn't press, or presses too hard, set `bar_trim` and reprint only the bar (+0.3 moves the slot 0.3 mm down in the bar and presses that much harder).

## Render

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w openscad/openscad:2021.01 \
  openscad -D 'part="body"' -o stl/yubikey-touch-body.stl fixture.scad
```

The parts are `body`, `deck`, `lid`, `knob`, `bar`, `test`, `assembly` (everything in place, for viewing only) and `test_assembly` (the test piece with its knob and bar; add `-D lift_up=true` to see the pin lifted).

After changing `fixture.scad`, check the parts and regenerate the drawings, so their measurements follow:

```bash
drawings/check.sh     # every printable part is the assembled part turned over or moved, never mirrored
drawings/make.sh      # layout.svg and wiring.svg (needs docker and python3)
drawings/animate.sh   # yubikey-touch-fixture.mp4 and .gif (also needs blender and ffmpeg; a few minutes)
```

## Explainer video

`explainer/build.sh` builds `yubikey-touch-explainer.mp4`. It needs docker, blender, node, google-chrome and
ffmpeg, and takes about 15 minutes.

| File | What |
|---|---|
| `explainer/film.html` | The video as a page: `window.setTime(t)` draws second `t`. All the text, layout and timing is here |
| `explainer/render.js` | Takes a picture of every frame with headless Chrome. `node render.js stills 12,50` makes single pictures, to check a change |
| `explainer/narration/s1.txt` to `s6.txt` | What is said, one file per scene. Words are spelled the way they should sound ("S C A") |
| `explainer/narrate.sh` | Speaks the narration with `spark-tts` in a cloned voice and fits it into two minutes |
| `explainer/build.sh` | Renders the assembly frames from `fixture.scad`, then the pictures, and adds the sound |

```bash
explainer/build.sh             # new pictures, the narration as it is
explainer/build.sh --narrate   # speak the narration again first (needs spark-tts and the voice)
```

The pictures follow `fixture.scad` and the numbers in `film.html`, so after the fixture or its prices change,
update `film.html` and run `build.sh`. The picture timing follows the speech: after `narrate.sh` makes new
speech, set the scene starts it prints in `film.html` (`SC`), move the `data-in` times to the new words, and
update the subtitles by hand.

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
2. Plug both adapters (the YubiKey 5 adapter and the U-turn) into the hub, then lower the hub onto its corner pads between the fences, north sockets toward the north wall. The YubiKey 5 adapter's USB-C end drops into the cradle at the south wall.
3. Fit the deck, the switch boards and the RP2040-Zero, which slides onto the U-turn plug. Then wire the power, as in [Wiring](#wiring).
   Solder the wires to a board's three pads (2, 3, 1) first, from the top. Then slide the board into its drawer from
   the middle of the deck, transistor end first: put its nose down beside the centre rail, push it home under the lips,
   and press its tail down behind the sill. The pads stay at the mouth, by the wire slots. To take a board out, lift
   its tail over the sill and pull.
4. Fit each pin lift. Solder before the pin goes in: once it is in the tower you can't reach it.
   1. Slide the bar into the sleeve on the tower's west face, with the low end of its slot to the north, and push it south.
   2. Push the touch wire through its channel from the box until it comes out in the tower, then pull it up out of the top of the tower, a few centimetres (tweezers help).
   3. Hold the pin above the fixture and solder the wire to the **side** of the barrel, within 1 mm of its top end. Keep the top end itself clean: the filament presses on it.
   4. Drop the pin into the knob from the top, tip first, with the wire lying in the knob's side slot. The solder joint rests on the floor of the slot, which stops the pin from falling through.
   5. Lower the knob into the tower with its side slot facing the box. The wire slides down the open slot in the tower's box-side wall; pull the extra wire gently back into the box as you go.
   6. With the key in its drawer, press the knob down until its cross hole lines up with the bar slot. Cut 9 mm of 1.75 mm filament and push it through the sleeve window, the bar slot and the tower slot into the knob's cross hole, until it stops against the far wall.
5. Drop the lid in 1 mm south, slide it north so its two tabs enter the wall slot, and fit the two M2×6 screws.
   Its column comes down over the empty corner of the deck, north of the RP2040, and stops just above the deck.
