#!/usr/bin/env bash
# Builds the touch fixture firmware in Docker: runs the host test of the protocol, then
# writes build/yubikey-touch.uf2 next to this script. Works from any directory.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
image="sca-yubikey-touch-firmware"

docker build -t "$image" "$here"

# Run as the calling user so build/ isn't root-owned.
docker run --rm -u "$(id -u):$(id -g)" -v "$here":/src -w /src "$image" bash -euo pipefail -c '
    mkdir -p build/test
    cc -std=c99 -Wall -Wextra -Werror -o build/test/test_protocol test_protocol.c protocol.c
    build/test/test_protocol
    cmake -S . -B build/fw -DCMAKE_BUILD_TYPE=Release
    cmake --build build/fw -j"$(nproc)"
    cp build/fw/yubikey-touch.uf2 build/yubikey-touch.uf2
'

echo "Built $here/build/yubikey-touch.uf2"
