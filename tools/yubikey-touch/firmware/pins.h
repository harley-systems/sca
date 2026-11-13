/*
 * GPIO map of the touch fixture. This is the only file that names pins.
 * Keep it in step with the pin table in ../README.md.
 */
#ifndef YK_TOUCH_PINS_H
#define YK_TOUCH_PINS_H

/* Pogo pin wires. Touch = output driving 0, release = input with pulls off. */
#define PIN_TOUCH_YK4 2
#define PIN_TOUCH_YK5 3

/* Gates of the AO3401 + 2N7002 power switch boards. */
#define PIN_POWER_YK4 4
#define PIN_POWER_YK5 5

/*
 * 1: GPIO high powers the key (GPIO drives the 2N7002, which pulls the AO3401 gate low).
 * 0: GPIO low powers the key. Then the pull-down the pin has during reset powers the key
 *    before the firmware runs, so prefer wiring for 1.
 */
#define POWER_ACTIVE_HIGH 1

/* GP16 is the onboard WS2812 LED: do not use it. */

#endif
