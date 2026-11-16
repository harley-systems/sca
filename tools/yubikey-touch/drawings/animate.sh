#!/usr/bin/env bash
# Render the assembly animation, yubikey-touch-fixture.mp4 and .gif, from fixture.scad.
# Needs docker (OpenSCAD 2021.01 image), blender and ffmpeg. Takes a few minutes.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
b="$here/build/anim"
rm -rf "$b" && mkdir -p "$b/stl" "$b/frames" "$b/captions"

items="body deck lid hub sockets adapter uturn usbin rp2040 boards_n boards_s yk4 yk5 disk4 disk5
       knob4 knob5 bar4 bar5 fil4 fil5 pogo4 pogo5"
for i in $items; do
    docker run --rm -u "$(id -u):$(id -g)" -v "$top:/o" -w /o/drawings openscad/openscad:2021.01 \
        openscad -D 'part="none"' -D 'view="none"' -D "item=\"$i\"" -o "build/anim/stl/$i.stl" anim.scad \
        > "$b/stl/$i.log" 2>&1 &
done
wait

blender -b -P "$here/animate.py" -- "$b/stl" "$b/frames" > "$b/blender.log" 2>&1

# captions: start and end in seconds, then the text
font=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
filters=""
n=0
while IFS='|' read -r t0 t1 caption; do
    [ -n "$t0" ] || continue
    n=$((n + 1))
    printf '%s' "$caption" > "$b/captions/$n.txt"
    filters+="drawtext=fontfile=$font:textfile=$b/captions/$n.txt:fontsize=30:fontcolor=0x1f2328:"
    filters+="box=1:boxcolor=white@0.85:boxborderw=12:x=(w-text_w)/2:y=h-64:enable='between(t,$t0,$t1)',"
done <<'CAPTIONS'
0.0|1.0|Rev I: the printed body
1.0|3.9|1. The hub, with the YubiKey 5 adapter and the U-turn, onto its pads
3.9|5.7|The plug for the laptop goes in through the west wall
5.8|7.9|2. The deck
7.9|9.7|3. The switch boards slide into their drawers
9.8|12.6|4. The RP2040-Zero slides onto the U-turn
12.6|16.4|5. Slide bars, then the pin holders with their pogo pins, lifted
16.4|17.9|6. Filament cross pins, from the west
18.0|21.0|7. The keys slide in under the lifted pins
21.3|23.0|8. Bars pushed south: the pins come down on the buttons
23.3|26.4|9. The lid drops in and slides north under the wall
26.4|30.0|YubiKey touch fixture, rev I
CAPTIONS
filters=${filters%,}

ffmpeg -y -loglevel error -framerate 30 -i "$b/frames/f_%04d.png" -vf "$filters" \
    -c:v libx264 -pix_fmt yuv420p -crf 26 -movflags +faststart "$top/yubikey-touch-fixture.mp4"
ffmpeg -y -loglevel error -i "$top/yubikey-touch-fixture.mp4" \
    -vf "fps=10,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
    "$top/yubikey-touch-fixture.gif"
ls -la "$top/yubikey-touch-fixture.mp4" "$top/yubikey-touch-fixture.gif"
