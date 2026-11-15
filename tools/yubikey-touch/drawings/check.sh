#!/usr/bin/env bash
# Check that every printable part in fixture.scad is the assembled part turned over or moved, not mirrored.
# Needs docker (OpenSCAD 2021.01 image) and python3. Run it after changing how a part is laid out for printing.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
b="$here/build/check"
rm -rf "$b" && mkdir -p "$b"
scad() {
    docker run --rm -u "$(id -u):$(id -g)" -v "$top:/o" -w /o/drawings openscad/openscad:2021.01 openscad "$@"
}
parts="body deck lid knob bar"
for p in $parts; do
    scad -D "part=\"$p\"" -o "build/check/$p-print.stl" ../fixture.scad > "$b/$p-print.log" 2>&1 &
    scad -D 'part="none"' -D "which=\"$p\"" -o "build/check/$p-assembled.stl" check.scad > "$b/$p-assembled.log" 2>&1 &
done
wait
for p in $parts; do echo "$p $b/$p-print.stl $b/$p-assembled.stl"; done | python3 -I "$here/check.py"
