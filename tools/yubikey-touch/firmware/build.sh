#!/bin/sh
# Build yktouch.uf2 in Docker. Output: build/yktouch.uf2
set -e
cd "$(dirname "$0")"
docker build -q -t yktouch-build . >/dev/null
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/src -w /src yktouch-build \
  sh -c 'cmake -S . -B build >/dev/null && cmake --build build -j'
ls -l build/yktouch.uf2
