#!/usr/bin/env bash
# Build ../yubikey-touch-explainer.mp4: the assembly frames from fixture.scad, the pictures from film.html, and
# the narration. Needs docker (OpenSCAD 2021.01 image), blender, node, google-chrome and ffmpeg; about 15 minutes.
#   ./build.sh            keep the narration: build/narration.wav if narrate.sh made one, else the video's own sound
#   ./build.sh --narrate  speak the narration again first (see narrate.sh)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
out="$top/yubikey-touch-explainer.mp4"
b="$here/build"
cd "$here"
rm -rf "$b/stl" "$b/anim" "$b/frames" && mkdir -p "$b/stl" "$b/anim"

# 1. the assembly animation, as in drawings/animate.sh, but larger and with no background or captions
items="body deck lid hub sockets adapter uturn usbin rp2040 boards_n boards_s yk4 yk5 disk4 disk5
       knob4 knob5 bar4 bar5 fil4 fil5 pogo4 pogo5"
for i in $items; do
    docker run --rm -u "$(id -u):$(id -g)" -v "$top:/o" -w /o/drawings openscad/openscad:2021.01 \
        openscad -D 'part="none"' -D 'view="none"' -D "item=\"$i\"" -o "../explainer/build/stl/$i.stl" anim.scad \
        > "$b/stl/$i.log" 2>&1 &
done
wait
blender -b -P "$top/drawings/animate.py" -- "$b/stl" "$b/anim" 1600x900 transparent > "$b/blender.log" 2>&1

# 2. every frame of the page
npm ci --silent
node render.js frames

# 3. the sound, then the video
[ "${1:-}" = "--narrate" ] && ./narrate.sh
if [ -f "$b/narration.wav" ]; then
    sound=(-i "$b/narration.wav" -c:a aac -b:a 192k)
else
    sound=(-i "$out" -c:a copy)
fi
ffmpeg -y -loglevel error -framerate 30 -i "$b/frames/f_%05d.jpg" "${sound[@]}" -map 0:v -map 1:a \
    -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart "$b/explainer.mp4"
mv "$b/explainer.mp4" "$out"
ls -la "$out"
