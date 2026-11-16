cmake_minimum_required(VERSION 3.13)
set(PICO_BOARD waveshare_rp2040_zero)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(yktouch C CXX ASM)
pico_sdk_init()

add_executable(yktouch main.c)
pico_generate_pio_header(yktouch ${CMAKE_CURRENT_LIST_DIR}/ws2812.pio)
target_link_libraries(yktouch pico_stdlib hardware_pio)
target_compile_definitions(yktouch PRIVATE
  USBD_PRODUCT="YubiKey touch"
  USBD_MANUFACTURER="harley-systems")
pico_enable_stdio_usb(yktouch 1)
pico_enable_stdio_uart(yktouch 0)
pico_add_extra_outputs(yktouch)
