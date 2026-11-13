cmake_minimum_required(VERSION 3.13)

set(PICO_BOARD waveshare_rp2040_zero CACHE STRING "Board type")
include($ENV{PICO_SDK_PATH}/pico_sdk_init.cmake)

project(yubikey_touch C CXX ASM)
pico_sdk_init()

add_executable(yubikey-touch main.c protocol.c)

target_compile_options(yubikey-touch PRIVATE -Wall -Wextra)
target_compile_definitions(yubikey-touch PRIVATE
    "USBD_MANUFACTURER=\"harley-systems\""
    "USBD_PRODUCT=\"YubiKey touch fixture\""
    # Keeps the build date out of the binary, so rebuilds give the same .uf2.
    PICO_NO_BI_PROGRAM_BUILD_DATE=1
)

target_link_libraries(yubikey-touch pico_stdlib pico_bootrom hardware_gpio)

pico_enable_stdio_usb(yubikey-touch 1)
pico_enable_stdio_uart(yubikey-touch 0)
pico_set_program_name(yubikey-touch "yubikey-touch")
pico_set_program_version(yubikey-touch "1.0.0")
pico_add_extra_outputs(yubikey-touch)
