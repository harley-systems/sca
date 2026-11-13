/*
 * Host test of protocol.c against a fake HAL. build.sh runs it before building the
 * firmware. Build by hand with:
 *   cc -std=c99 -Wall -Wextra -Werror -o test_protocol test_protocol.c protocol.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "protocol.h"

/* ---- fake HAL ---- */

static uint32_t now;
static bool pin_touch[PROTO_NKEYS];
static bool pin_power[PROTO_NKEYS];
static uint32_t released_at[PROTO_NKEYS];
static int hal_calls;
static int violations;

void hal_touch(int key, bool on)
{
    hal_calls++;
    if (on && !pin_power[key]) {
        printf("  violation: touching unpowered key %d\n", key);
        violations++;
    }
    if (!on && pin_touch[key])
        released_at[key] = now;
    pin_touch[key] = on;
}

void hal_power(int key, bool on)
{
    hal_calls++;
    if (on && !pin_power[key]) {
        if (pin_touch[key]) {
            printf("  violation: powering key %d while touched\n", key);
            violations++;
        }
        if (now - released_at[key] < PROTO_POWER_SETTLE_MS) {
            printf("  violation: powering key %d %lu ms after release\n", key,
                   (unsigned long)(now - released_at[key]));
            violations++;
        }
    }
    if (!on && pin_touch[key]) {
        printf("  violation: cutting power of key %d while touched\n", key);
        violations++;
    }
    pin_power[key] = on;
}

uint32_t hal_now_ms(void)
{
    return now;
}

void hal_sleep_ms(uint32_t ms)
{
    now += ms;
}

/* ---- helpers ---- */

static int failures;
static char reply[PROTO_REPLY_MAX];

#define CHECK(cond)                                                         \
    do {                                                                    \
        if (!(cond)) {                                                      \
            printf("  FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);        \
            failures++;                                                     \
        }                                                                   \
    } while (0)

static void reset(void)
{
    memset(pin_touch, 0, sizeof(pin_touch));
    memset(pin_power, 0, sizeof(pin_power));
    memset(released_at, 0, sizeof(released_at));
    now = 1000; /* released_at = 0 counts as released long ago */
    proto_init();
    hal_calls = 0;
}

static enum proto_action cmd(const char *line)
{
    reply[0] = '\0';
    return proto_handle(line, reply, sizeof(reply));
}

static bool ok(const char *line)
{
    return cmd(line) == PROTO_REPLY && strncmp(reply, "OK", 2) == 0;
}

static bool err(const char *line, const char *reason)
{
    return cmd(line) == PROTO_REPLY && strncmp(reply, "ERR ", 4) == 0 &&
           (reason == NULL || strcmp(reply + 4, reason) == 0);
}

static void advance(uint32_t ms)
{
    now += ms;
    proto_poll();
}

static void status(char *out, size_t size)
{
    cmd("status");
    snprintf(out, size, "%s", reply);
}

/* ---- tests ---- */

static void test_boot(void)
{
    reset();
    CHECK(pin_power[0] && pin_power[1]);
    CHECK(!pin_touch[0] && !pin_touch[1]);
    CHECK(ok("status"));
    CHECK(strcmp(reply, "OK yk4 power=on touch=released yk5 power=on touch=released") == 0);
}

static void test_timed_touch(void)
{
    reset();
    CHECK(ok("touch yk5 500"));
    CHECK(pin_touch[1] && !pin_touch[0]);
    CHECK(ok("status"));
    CHECK(strstr(reply, "yk5 power=on touch=timed") != NULL);
    advance(499);
    CHECK(pin_touch[1]);
    advance(1);
    CHECK(!pin_touch[1]);
    CHECK(ok("status"));
    CHECK(strstr(reply, "yk5 power=on touch=released") != NULL);
}

static void test_touch_restarts_deadline(void)
{
    reset();
    CHECK(ok("touch yk4 500"));
    advance(300);
    CHECK(ok("touch yk4 500"));
    advance(300);
    CHECK(pin_touch[0]);
    advance(200);
    CHECK(!pin_touch[0]);
}

static void test_release_cancels(void)
{
    reset();
    CHECK(ok("touch yk4 100"));
    CHECK(ok("release yk4"));
    CHECK(!pin_touch[0]);
    /* A later hold must not be ended by the cancelled deadline. */
    CHECK(ok("hold yk4"));
    advance(200);
    CHECK(pin_touch[0]);
    CHECK(ok("status"));
    CHECK(strstr(reply, "yk4 power=on touch=held") != NULL);
    CHECK(ok("hold yk5"));
    CHECK(ok("release all"));
    CHECK(!pin_touch[0] && !pin_touch[1]);
}

static void test_unpowered_key(void)
{
    char before[PROTO_REPLY_MAX], after[PROTO_REPLY_MAX];

    reset();
    CHECK(ok("power yk5 off"));
    CHECK(!pin_power[1] && pin_power[0]);
    status(before, sizeof(before));
    hal_calls = 0;
    CHECK(err("touch yk5 100", "key off"));
    CHECK(err("hold yk5", "key off"));
    CHECK(hal_calls == 0);
    CHECK(!pin_touch[1]);
    status(after, sizeof(after));
    CHECK(strcmp(before, after) == 0);
}

static void test_power_releases_first(void)
{
    reset();
    /* power on while held: released, then powered at least PROTO_POWER_SETTLE_MS later */
    CHECK(ok("hold yk4"));
    CHECK(ok("power yk4 on"));
    CHECK(!pin_touch[0] && pin_power[0]);

    /* power off while a timed touch runs: released before the cut, deadline cleared */
    CHECK(ok("touch yk4 1000"));
    CHECK(ok("power yk4 off"));
    CHECK(!pin_touch[0] && !pin_power[0]);
    CHECK(ok("power yk4 on"));
    CHECK(ok("hold yk4"));
    advance(2000);
    CHECK(pin_touch[0]);

    /* power on of a key that was off, right after its touch was released */
    CHECK(ok("hold yk5"));
    CHECK(ok("power all off"));
    CHECK(!pin_power[0] && !pin_power[1]);
    CHECK(ok("power all on"));
    CHECK(pin_power[0] && pin_power[1]);
    CHECK(!pin_touch[0] && !pin_touch[1]);
}

static void test_invalid_input(void)
{
    static const char *const bad[] = {
        "frobnicate",
        "touch",
        "touch yk4",
        "touch yk3 100",
        "touch all 100",
        "touch yk4 0",
        "touch yk4 10001",
        "touch yk4 99999999999999999999",
        "touch yk4 -5",
        "touch yk4 +5",
        "touch yk4 5ms",
        "touch yk4 100 extra",
        "TOUCH yk4 100",
        "hold",
        "hold all",
        "hold yk9",
        "release",
        "release yk9",
        "power yk4",
        "power yk4 maybe",
        "power yk9 off",
        "power yk4 off now",
        "status now",
        "version 2",
        "bootsel please",
        "a b c d e",
    };
    char before[PROTO_REPLY_MAX], after[PROTO_REPLY_MAX];
    size_t i;

    reset();
    CHECK(ok("hold yk5"));
    status(before, sizeof(before));
    hal_calls = 0;
    for (i = 0; i < sizeof(bad) / sizeof(bad[0]); i++) {
        if (!err(bad[i], NULL))
            printf("  accepted: \"%s\" -> \"%s\"\n", bad[i], reply);
        CHECK(strncmp(reply, "ERR ", 4) == 0);
    }
    CHECK(hal_calls == 0);
    status(after, sizeof(after));
    CHECK(strcmp(before, after) == 0);
    CHECK(err("touch yk4 10001", "ms must be 1 to 10000"));
    CHECK(err("touch yk3 100", "unknown key"));
    CHECK(err("frobnicate", "unknown command"));
    CHECK(ok("touch yk4 10000"));
    CHECK(ok("touch yk4 1"));
}

static enum proto_action feed(struct proto_line *line, const char *s)
{
    enum proto_action last = PROTO_NONE;

    reply[0] = '\0';
    for (; *s; s++) {
        enum proto_action a = proto_feed(line, *s, reply, sizeof(reply));

        if (a != PROTO_NONE)
            last = a;
    }
    return last;
}

static void test_line_handling(void)
{
    struct {
        struct proto_line line;
        char canary[16];
    } g;
    char s[2048];
    int replies;
    size_t i;

    reset();
    memset(&g, 0, sizeof(g));

    /* \r\n gives one reply, the empty line after \r gives none */
    replies = 0;
    for (i = 0; i < strlen("status\r\n"); i++)
        if (proto_feed(&g.line, "status\r\n"[i], reply, sizeof(reply)) != PROTO_NONE)
            replies++;
    CHECK(replies == 1);
    CHECK(strncmp(reply, "OK yk4", 6) == 0);
    CHECK(feed(&g.line, "\n\n  \n") == PROTO_NONE);

    /* exactly PROTO_LINE_MAX bytes is accepted */
    memset(s, ' ', PROTO_LINE_MAX);
    memcpy(s, "version", 7);
    s[PROTO_LINE_MAX] = '\n';
    s[PROTO_LINE_MAX + 1] = '\0';
    CHECK(feed(&g.line, s) == PROTO_REPLY && strncmp(reply, "OK ", 3) == 0);

    /* one more byte, or a lot more, is rejected without touching anything */
    hal_calls = 0;
    memset(s, ' ', PROTO_LINE_MAX + 1);
    memcpy(s, "hold yk4", 8);
    s[PROTO_LINE_MAX + 1] = '\n';
    s[PROTO_LINE_MAX + 2] = '\0';
    CHECK(feed(&g.line, s) == PROTO_REPLY && strcmp(reply, "ERR line too long") == 0);
    memset(s, 'x', sizeof(s) - 2);
    s[sizeof(s) - 2] = '\n';
    s[sizeof(s) - 1] = '\0';
    CHECK(feed(&g.line, s) == PROTO_REPLY && strcmp(reply, "ERR line too long") == 0);
    CHECK(hal_calls == 0);
    for (i = 0; i < sizeof(g.canary); i++)
        CHECK(g.canary[i] == 0);

    /* the assembler recovers after an overlong line */
    CHECK(feed(&g.line, "hold yk4\n") == PROTO_REPLY && strcmp(reply, "OK yk4 held") == 0);
    CHECK(pin_touch[0]);
}

static void test_misc_commands(void)
{
    reset();
    CHECK(ok("version"));
    CHECK(strcmp(reply, "OK yubikey-touch " FW_VERSION) == 0);
    CHECK(ok("help"));
    CHECK(strlen(reply) < sizeof(reply) - 1);
    CHECK(cmd("bootsel") == PROTO_REPLY_BOOTSEL && strncmp(reply, "OK", 2) == 0);
    CHECK(cmd("") == PROTO_NONE);
    CHECK(ok("  status\t"));
}

int main(void)
{
    static const struct {
        const char *name;
        void (*fn)(void);
    } tests[] = {
        { "boot", test_boot },
        { "timed touch", test_timed_touch },
        { "touch restarts deadline", test_touch_restarts_deadline },
        { "release cancels", test_release_cancels },
        { "unpowered key", test_unpowered_key },
        { "power releases first", test_power_releases_first },
        { "invalid input", test_invalid_input },
        { "line handling", test_line_handling },
        { "misc commands", test_misc_commands },
    };
    size_t i;

    for (i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
        int before = failures + violations;

        tests[i].fn();
        printf("%s %s\n", failures + violations == before ? "ok  " : "FAIL", tests[i].name);
    }
    if (failures || violations) {
        printf("%d check(s) failed, %d safety violation(s)\n", failures, violations);
        return EXIT_FAILURE;
    }
    printf("all protocol tests passed\n");
    return EXIT_SUCCESS;
}
