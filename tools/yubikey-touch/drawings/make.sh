#!/usr/bin/env bash
# Regenerate the fixture drawings (layout.svg, wiring.svg); layout.svg takes its measurements from fixture.scad.
# Needs docker (OpenSCAD 2021.01 image) and python3.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
top=$(dirname "$here")
mkdir -p "$here/build"
scad() {
    docker run --rm -u "$(id -u):$(id -g)" -v "$top:/o" -w /o/drawings openscad/openscad:2021.01 \
        openscad -D 'part="none"' "$@" views.scad
}
views="top_body top_floor top_hub top_adapter top_uturn top_rp2040 top_usbin top_keys top_lift cut_body cut_cover cut_hub cut_adapter cut_keys cut_lift side_uturn side_rp2040"
for v in $views; do
    scad -D "view=\"$v\"" -o "build/$v.svg" > "$here/build/$v.log" 2>&1 &
done
scad -D 'view="echo"' -o build/echo.stl > "$here/build/echo.log" 2>&1 &
wait
grep -h 'ECHO: "DIM ' "$here/build/echo.log" | sed 's/^ECHO: "DIM //; s/"$//' > "$here/build/dims.txt"
python3 -I "$here/compose.py" "$here/build" "$top/layout.svg"
python3 -I "$here/wiring.py" "$top/wiring.svg"
echo "wrote $top/layout.svg $top/wiring.svg"

