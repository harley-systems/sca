/*
 * Command protocol of the touch fixture. Pure C with no SDK includes, so the host
 * test (test_protocol.c) can build it against a fake HAL.
 */
#ifndef YK_TOUCH_PROTOCOL_H
#define YK_TOUCH_PROTOCOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define FW_VERSION "1.0.0"

#define PROTO_NKEYS 2           /* 0 = yk4, 1 = yk5 */
#define PROTO_LINE_MAX 64       /* longest accepted command line, in bytes */
#define PROTO_REPLY_MAX 192     /* reply buffer size, including the NUL */
#define PROTO_TOUCH_MS_MAX 10000
#define PROTO_POWER_SETTLE_MS 10 /* touch released this long before power-up */

/* What the caller must do after sending a reply. */
enum proto_action {
    PROTO_NONE = 0,    /* no reply yet */
    PROTO_REPLY,       /* send the reply */
    PROTO_REPLY_BOOTSEL /* send the reply, then reboot into the USB bootloader */
};

/* HAL, implemented by main.c on the board and by the fake in test_protocol.c. */
void hal_touch(int key, bool on); /* on: drive the pogo pin to 0; off: high impedance */
void hal_power(int key, bool on);
uint32_t hal_now_ms(void);
void hal_sleep_ms(uint32_t ms);

/* Line assembler state for proto_feed(). Zero-initialise it. */
struct proto_line {
    char buf[PROTO_LINE_MAX + 1];
    size_t len;
    bool overflow;
};

/* Boot sequence: release both touches, then power both keys. */
void proto_init(void);

/* Release timed touches whose deadline has passed. Call it often. */
void proto_poll(void);

/*
 * Feed one received byte. When a line is complete, writes exactly one reply line
 * (without the newline) to reply and returns PROTO_REPLY or PROTO_REPLY_BOOTSEL.
 * Empty lines get no reply.
 */
enum proto_action proto_feed(struct proto_line *line, char c, char *reply, size_t size);

/* Handle one complete command line (no newline). Same return as proto_feed(). */
enum proto_action proto_handle(const char *cmd, char *reply, size_t size);

#endif
