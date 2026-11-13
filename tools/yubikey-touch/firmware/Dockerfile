# Toolchain for the touch fixture firmware. Run it through build.sh.
FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates cmake gcc-arm-none-eabi git \
      libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib python3 \
 && rm -rf /var/lib/apt/lists/*

# pico-sdk at a release tag, checked against its commit. The submodules bring TinyUSB.
ARG PICO_SDK_TAG=2.3.1
ARG PICO_SDK_COMMIT=079c6f39023649b154152db30f1d781e884879bc
RUN git clone --depth 1 --branch "$PICO_SDK_TAG" https://github.com/raspberrypi/pico-sdk.git /opt/pico-sdk \
 && test "$(git -C /opt/pico-sdk rev-parse HEAD)" = "$PICO_SDK_COMMIT" \
 && git -C /opt/pico-sdk submodule update --init

# picotool makes the .uf2. Installing it here stops the SDK from fetching it at build time.
ARG PICOTOOL_TAG=2.3.1
ARG PICOTOOL_COMMIT=2041936441b48a3cc53ae3da9e805229fe8f4e18
RUN git clone --depth 1 --branch "$PICOTOOL_TAG" https://github.com/raspberrypi/picotool.git /tmp/picotool \
 && test "$(git -C /tmp/picotool rev-parse HEAD)" = "$PICOTOOL_COMMIT" \
 && cmake -S /tmp/picotool -B /tmp/picotool/build -DPICO_SDK_PATH=/opt/pico-sdk \
      -DPICOTOOL_NO_LIBUSB=1 -DPICOTOOL_FLAT_INSTALL=1 -DCMAKE_INSTALL_PREFIX=/opt \
 && cmake --build /tmp/picotool/build -j"$(nproc)" \
 && cmake --install /tmp/picotool/build \
 && rm -rf /tmp/picotool

ENV PICO_SDK_PATH=/opt/pico-sdk
ENV picotool_DIR=/opt/picotool
