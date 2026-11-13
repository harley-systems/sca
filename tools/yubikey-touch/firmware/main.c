/*
 * RP2040-Zero firmware of the YubiKey touch fixture: implements the HAL of protocol.c
 * with the pico-sdk and serves the commands over USB CDC serial.
 */
#include <stdio.h>

#include "hardware/gpio.h"
#include "pico/bootrom.h"
#include "pico/stdlib.h"

#include "pins.h"
#include "protocol.h"

static const uint touch_pins[PROTO_NKEYS] = { PIN_TOUCH_YK4, PIN_TOUCH_YK5 };
static const uint power_pins[PROTO_NKEYS] = { PIN_POWER_YK4, PIN_POWER_YK5 };

/*
 * A touch pin is only ever an input with pulls off or an output driving 0: driving the
 * pad high could inject current into the key's sensor. The output latch is set to 0 once
 * and the pad's output is also forced low by the output override, so changing the
 * direction is the only thing touch and release do. Never gpio_put() a touch pin.
 */
void hal_touch(int key, bool on)
{
    gpio_set_dir(touch_pins[key], on ? GPIO_OUT : GPIO_IN);
}

void hal_power(int key, bool on)
{
    gpio_put(power_pins[key], on == (bool)POWER_ACTIVE_HIGH);
}

uint32_t hal_now_ms(void)
{
    return to_ms_since_boot(get_absolute_time());
}

void hal_sleep_ms(uint32_t ms)
{
    sleep_ms(ms);
}

static void init_pins(void)
{
    int k;

    for (k = 0; k < PROTO_NKEYS; k++) {
        uint t = touch_pins[k];
        uint p = power_pins[k];

        gpio_init(t);
        gpio_disable_pulls(t); /* the reset default pull-down would load the pad */
        gpio_put(t, 0);
        gpio_set_outover(t, GPIO_OVERRIDE_LOW);
        gpio_set_dir(t, GPIO_IN);

        gpio_init(p);
        hal_power(k, false);
        gpio_set_dir(p, GPIO_OUT);
    }
}

int main(void)
{
    struct proto_line line = { 0 };
    char reply[PROTO_REPLY_MAX];

    init_pins();
    stdio_init_all();
    proto_init();

    for (;;) {
        int c = getchar_timeout_us(1000);

        if (c != PICO_ERROR_TIMEOUT) {
            enum proto_action action = proto_feed(&line, (char)c, reply, sizeof(reply));

            if (action != PROTO_NONE) {
                puts(reply);
                fflush(stdout);
            }
            if (action == PROTO_REPLY_BOOTSEL) {
                sleep_ms(100); /* let the reply leave before USB goes away */
                reset_usb_boot(0, 0);
            }
        }
        proto_poll();
    }
}
