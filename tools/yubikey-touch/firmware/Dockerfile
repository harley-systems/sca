# Build environment for the touch fixture firmware: pico-sdk + arm gcc, pinned.
FROM ubuntu:24.04
ARG PICO_SDK_TAG=2.1.1
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates git cmake make python3 g++ \
      gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib libusb-1.0-0-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${PICO_SDK_TAG} https://github.com/raspberrypi/pico-sdk /opt/pico-sdk \
 && git -C /opt/pico-sdk submodule update --init --depth 1 lib/tinyusb
ENV PICO_SDK_PATH=/opt/pico-sdk
# picotool turns the .elf into a .uf2; build it once here so the firmware build needs no network.
RUN git clone --depth 1 --branch ${PICO_SDK_TAG} https://github.com/raspberrypi/picotool /opt/picotool-src \
 && cmake -S /opt/picotool-src -B /opt/picotool-src/build -DCMAKE_INSTALL_PREFIX=/opt/picotool -DPICOTOOL_FLAT_INSTALL=1 \
 && cmake --build /opt/picotool-src/build -j \
 && cmake --install /opt/picotool-src/build
ENV picotool_DIR=/opt/picotool/picotool
