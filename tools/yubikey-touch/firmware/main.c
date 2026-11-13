// YubiKey touch fixture firmware for the RP2040-Zero.
//
// Each key has a pogo pin on its touch pad, wired to a TOUCH GPIO. Driving that GPIO low
// grounds the pad, which the key reads as a finger. Released, the GPIO is a floating input.
// It is never driven high. Each key also has a POWER GPIO driving its high-side switch
// (2N7002 -> AO3401): high = key powered.
//
// The key calibrates its touch sensor when it powers up, so the touch is always released
// before power goes on.
//
// Commands over USB serial, one per line. Keys are named 4 (YubiKey 4) and 5 (YubiKey 5):
//   touch <key> [ms]     touch for ms (default 500, 10..10000), then release
//   hold <key>           touch until released
//   release <key>        release the touch
//   power <key> on|off   switch the key's power (on releases the touch first)
//   cycle <key> [ms]     power off for ms (default 1000), then on
//   status               show the state of both keys
//   help
// Every reply is one line starting with "ok" or "err".

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "ws2812.pio.h"

#define LED_PIN 16
#define TOUCH_DEFAULT_MS 500
#define CYCLE_DEFAULT_MS 1000
#define POWER_SETTLE_MS 50

typedef struct {
    const char *name;
    uint touch_pin;
    uint power_pin;
    bool touching;
    bool powered;
} key_t;

static key_t keys[] = {
    {"4", 0, 2, false, false},
    {"5", 1, 3, false, false},
};
#define NKEYS (sizeof keys / sizeof keys[0])

static PIO led_pio = pio0;
static uint led_sm = 0;

static void led(uint8_t r, uint8_t g, uint8_t b) {
    // This LED takes its colours in G, R, B order, top bits first.
    pio_sm_put_blocking(led_pio, led_sm, ((uint32_t)g << 24) | ((uint32_t)r << 16) | ((uint32_t)b << 8));
}

static void led_idle(void) {
    bool any = false;
    for (size_t i = 0; i < NKEYS; i++) any |= keys[i].touching;
    if (any) led(0, 0, 40);      // blue: touching
    else led(0, 8, 0);           // dim green: ready
}

static void touch_release(key_t *k) {
    gpio_set_dir(k->touch_pin, GPIO_IN);
    k->touching = false;
}

static void touch_press(key_t *k) {
    gpio_put(k->touch_pin, 0);   // output latch low before the pin becomes an output
    gpio_set_dir(k->touch_pin, GPIO_OUT);
    k->touching = true;
}

static void power_set(key_t *k, bool on) {
    if (on) {
        touch_release(k);
        sleep_ms(POWER_SETTLE_MS);
    }
    gpio_put(k->power_pin, on);
    k->powered = on;
}

static key_t *find_key(const char *name) {
    if (!name) return NULL;
    if (tolower((unsigned char)name[0]) == 'y' && tolower((unsigned char)name[1]) == 'k') name += 2;
    for (size_t i = 0; i < NKEYS; i++)
        if (strcmp(keys[i].name, name) == 0) return &keys[i];
    return NULL;
}

static bool parse_ms(const char *s, int def, int lo, int hi, int *out) {
    if (!s) { *out = def; return true; }
    char *end;
    long v = strtol(s, &end, 10);
    if (*end || v < lo || v > hi) return false;
    *out = (int)v;
    return true;
}

static void print_status(void) {
    printf("ok");
    for (size_t i = 0; i < NKEYS; i++)
        printf(" key%s power=%s touch=%s", keys[i].name,
               keys[i].powered ? "on" : "off", keys[i].touching ? "held" : "released");
    printf("\n");
}

static void handle(char *line) {
    char *cmd = strtok(line, " \t");
    char *a1 = strtok(NULL, " \t");
    char *a2 = strtok(NULL, " \t");
    if (!cmd) return;
    for (char *p = cmd; *p; p++) *p = (char)tolower((unsigned char)*p);

    if (!strcmp(cmd, "help")) {
        printf("ok commands: touch <4|5> [ms] | hold <4|5> | release <4|5> | "
               "power <4|5> on|off | cycle <4|5> [ms] | status\n");
        return;
    }
    if (!strcmp(cmd, "status")) { print_status(); return; }

    key_t *k = find_key(a1);
    if (!strcmp(cmd, "touch") || !strcmp(cmd, "hold") || !strcmp(cmd, "release") ||
        !strcmp(cmd, "power") || !strcmp(cmd, "cycle")) {
        if (!k) { printf("err unknown key '%s' (use 4 or 5)\n", a1 ? a1 : ""); return; }
    } else {
        printf("err unknown command '%s' (try help)\n", cmd);
        return;
    }

    int ms;
    if (!strcmp(cmd, "touch")) {
        if (!parse_ms(a2, TOUCH_DEFAULT_MS, 10, 10000, &ms)) { printf("err ms must be 10..10000\n"); return; }
        if (!k->powered) { printf("err key%s is off\n", k->name); return; }
        touch_press(k); led_idle();
        sleep_ms(ms);
        touch_release(k); led_idle();
        printf("ok touched key%s %d ms\n", k->name, ms);
    } else if (!strcmp(cmd, "hold")) {
        if (!k->powered) { printf("err key%s is off\n", k->name); return; }
        touch_press(k); led_idle();
        printf("ok key%s held\n", k->name);
    } else if (!strcmp(cmd, "release")) {
        touch_release(k); led_idle();
        printf("ok key%s released\n", k->name);
    } else if (!strcmp(cmd, "power")) {
        if (!a2 || (strcmp(a2, "on") && strcmp(a2, "off"))) { printf("err use: power <4|5> on|off\n"); return; }
        power_set(k, !strcmp(a2, "on")); led_idle();
        printf("ok key%s power %s\n", k->name, a2);
    } else { // cycle
        if (!parse_ms(a2, CYCLE_DEFAULT_MS, 100, 10000, &ms)) { printf("err ms must be 100..10000\n"); return; }
        power_set(k, false); led_idle();
        sleep_ms(ms);
        power_set(k, true); led_idle();
        printf("ok key%s power cycled\n", k->name);
    }
}

int main(void) {
    // Touch pins first: floating inputs, no pulls, so nothing touches a pad at power-up.
    for (size_t i = 0; i < NKEYS; i++) {
        gpio_init(keys[i].touch_pin);
        gpio_disable_pulls(keys[i].touch_pin);
        touch_release(&keys[i]);
        gpio_init(keys[i].power_pin);
        gpio_put(keys[i].power_pin, 0);
        gpio_set_dir(keys[i].power_pin, GPIO_OUT);
    }

    uint off = pio_add_program(led_pio, &ws2812_program);
    ws2812_program_init(led_pio, led_sm, off, LED_PIN);

    stdio_init_all();

    // Keys start powered, touch released.
    for (size_t i = 0; i < NKEYS; i++) power_set(&keys[i], true);
    led_idle();

    char line[96];
    size_t n = 0;
    for (;;) {
        int c = getchar_timeout_us(100000);
        if (c == PICO_ERROR_TIMEOUT) continue;
        if (c == '\r' || c == '\n') {
            line[n] = 0;
            if (n) handle(line);
            n = 0;
        } else if (n < sizeof line - 1) {
            line[n++] = (char)c;
        }
    }
}
