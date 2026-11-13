/*
 * Command protocol of the touch fixture: parses command lines, keeps the per-key state
 * and drives the HAL. Safety rules (see ../README.md):
 *   - a key is only touched while it is powered;
 *   - a key's touch is released at least PROTO_POWER_SETTLE_MS before it powers up,
 *     because the key calibrates its touch sensor at power-up;
 *   - invalid input changes nothing.
 */
#include "protocol.h"

#include <stdio.h>
#include <string.h>

#define ALL_KEYS (-1)
#define MAX_ARGS 4

static const char *const key_names[PROTO_NKEYS] = { "yk4", "yk5" };

static struct {
    bool power;
    bool touch;
    bool timed;
    uint32_t deadline;
} keys[PROTO_NKEYS];

static void release(int k)
{
    keys[k].touch = false;
    keys[k].timed = false;
    hal_touch(k, false);
}

static void set_power(int first, int last, bool on)
{
    int k;

    for (k = first; k <= last; k++)
        release(k);
    if (on)
        hal_sleep_ms(PROTO_POWER_SETTLE_MS);
    for (k = first; k <= last; k++) {
        keys[k].power = on;
        hal_power(k, on);
    }
}

void proto_init(void)
{
    memset(keys, 0, sizeof(keys));
    set_power(0, PROTO_NKEYS - 1, true);
}

void proto_poll(void)
{
    uint32_t now = hal_now_ms();
    int k;

    for (k = 0; k < PROTO_NKEYS; k++)
        if (keys[k].timed && (int32_t)(now - keys[k].deadline) >= 0)
            release(k);
}

/* Returns the key index, ALL_KEYS for "all" when allowed, or -2 when unknown. */
static int parse_key(const char *s, bool allow_all)
{
    int k;

    if (allow_all && strcmp(s, "all") == 0)
        return ALL_KEYS;
    for (k = 0; k < PROTO_NKEYS; k++)
        if (strcmp(s, key_names[k]) == 0)
            return k;
    return -2;
}

/* Parses a decimal duration in 1..PROTO_TOUCH_MS_MAX. Returns false when invalid. */
static bool parse_ms(const char *s, uint32_t *ms)
{
    uint32_t v = 0;

    if (*s == '\0')
        return false;
    for (; *s; s++) {
        if (*s < '0' || *s > '9')
            return false;
        v = v * 10 + (uint32_t)(*s - '0');
        if (v > PROTO_TOUCH_MS_MAX)
            return false;
    }
    if (v < 1)
        return false;
    *ms = v;
    return true;
}

static const char *touch_state(int k)
{
    if (!keys[k].touch)
        return "released";
    return keys[k].timed ? "timed" : "held";
}

static enum proto_action reply_err(char *reply, size_t size, const char *reason)
{
    snprintf(reply, size, "ERR %s", reason);
    return PROTO_REPLY;
}

static enum proto_action reply_ok(char *reply, size_t size, const char *text)
{
    snprintf(reply, size, "OK %s", text);
    return PROTO_REPLY;
}

enum proto_action proto_handle(const char *cmd, char *reply, size_t size)
{
    char copy[PROTO_LINE_MAX + 1];
    char *argv[MAX_ARGS];
    int argc = 0;
    char *p;
    int k;

    if (strlen(cmd) > PROTO_LINE_MAX)
        return reply_err(reply, size, "line too long");
    strcpy(copy, cmd);

    for (p = strtok(copy, " \t"); p; p = strtok(NULL, " \t")) {
        if (argc == MAX_ARGS)
            return reply_err(reply, size, "too many arguments");
        argv[argc++] = p;
    }
    if (argc == 0)
        return PROTO_NONE;

    if (strcmp(argv[0], "touch") == 0) {
        uint32_t ms;

        if (argc != 3)
            return reply_err(reply, size, "usage: touch <key> <ms>");
        k = parse_key(argv[1], false);
        if (k < 0)
            return reply_err(reply, size, "unknown key");
        if (!parse_ms(argv[2], &ms))
            return reply_err(reply, size, "ms must be 1 to 10000");
        if (!keys[k].power)
            return reply_err(reply, size, "key off");
        keys[k].touch = true;
        keys[k].timed = true;
        keys[k].deadline = hal_now_ms() + ms;
        hal_touch(k, true);
        snprintf(reply, size, "OK %s touch %lu ms", key_names[k], (unsigned long)ms);
        return PROTO_REPLY;
    }

    if (strcmp(argv[0], "hold") == 0) {
        if (argc != 2)
            return reply_err(reply, size, "usage: hold <key>");
        k = parse_key(argv[1], false);
        if (k < 0)
            return reply_err(reply, size, "unknown key");
        if (!keys[k].power)
            return reply_err(reply, size, "key off");
        keys[k].touch = true;
        keys[k].timed = false;
        hal_touch(k, true);
        snprintf(reply, size, "OK %s held", key_names[k]);
        return PROTO_REPLY;
    }

    if (strcmp(argv[0], "release") == 0) {
        if (argc != 2)
            return reply_err(reply, size, "usage: release <key|all>");
        k = parse_key(argv[1], true);
        if (k == -2)
            return reply_err(reply, size, "unknown key");
        if (k == ALL_KEYS) {
            for (k = 0; k < PROTO_NKEYS; k++)
                release(k);
            return reply_ok(reply, size, "all released");
        }
        release(k);
        snprintf(reply, size, "OK %s released", key_names[k]);
        return PROTO_REPLY;
    }

    if (strcmp(argv[0], "power") == 0) {
        bool on;

        if (argc != 3)
            return reply_err(reply, size, "usage: power <key|all> on|off");
        k = parse_key(argv[1], true);
        if (k == -2)
            return reply_err(reply, size, "unknown key");
        if (strcmp(argv[2], "on") == 0)
            on = true;
        else if (strcmp(argv[2], "off") == 0)
            on = false;
        else
            return reply_err(reply, size, "usage: power <key|all> on|off");
        if (k == ALL_KEYS)
            set_power(0, PROTO_NKEYS - 1, on);
        else
            set_power(k, k, on);
        snprintf(reply, size, "OK %s power=%s",
                 k == ALL_KEYS ? "all" : key_names[k], on ? "on" : "off");
        return PROTO_REPLY;
    }

    if (argc != 1)
        return reply_err(reply, size, "too many arguments");

    if (strcmp(argv[0], "status") == 0) {
        size_t n = (size_t)snprintf(reply, size, "OK");

        for (k = 0; k < PROTO_NKEYS && n < size; k++)
            n += (size_t)snprintf(reply + n, size - n, " %s power=%s touch=%s", key_names[k],
                                  keys[k].power ? "on" : "off", touch_state(k));
        return PROTO_REPLY;
    }
    if (strcmp(argv[0], "version") == 0)
        return reply_ok(reply, size, "yubikey-touch " FW_VERSION);
    if (strcmp(argv[0], "help") == 0)
        return reply_ok(reply, size,
                        "commands: touch <key> <ms>, hold <key>, release <key|all>, "
                        "power <key|all> on|off, status, version, help, bootsel; "
                        "keys: yk4 yk5");
    if (strcmp(argv[0], "bootsel") == 0) {
        reply_ok(reply, size, "rebooting to BOOTSEL");
        return PROTO_REPLY_BOOTSEL;
    }

    return reply_err(reply, size, "unknown command");
}

enum proto_action proto_feed(struct proto_line *line, char c, char *reply, size_t size)
{
    enum proto_action action;

    /* Accept \n, \r\n and a bare \r: the empty line after \r\n gets no reply. */
    if (c != '\n' && c != '\r') {
        if (line->len < PROTO_LINE_MAX)
            line->buf[line->len++] = c;
        else
            line->overflow = true;
        return PROTO_NONE;
    }

    if (line->overflow)
        action = reply_err(reply, size, "line too long");
    else {
        line->buf[line->len] = '\0';
        action = proto_handle(line->buf, reply, size);
    }
    line->len = 0;
    line->overflow = false;
    return action;
}
