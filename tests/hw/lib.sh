#!/bin/bash
################################################################################
# helpers for tests/hw/*.sh, the hardware tests the fixture broker runs
#
# a test runs inside the broker's test container (tools/yubikey-touch/broker/),
# which sees one test key; YUBIKEY_FIXTURE_SLOT and YUBIKEY_FIXTURE_SERIAL name
# it. these tests may reset the key: never run them against a key you use.

set -u

if [ -z "${YUBIKEY_FIXTURE_SERIAL:-}" ] || [ -z "${YUBIKEY_FIXTURE_SLOT:-}" ]; then
  echo "error: run this through the fixture broker (yubikey-fixture run ...)" >&2
  exit 2
fi

# the default PIV management key, PIN and PUK after a reset
mgmt_key="010203040506070801020304050607080102030405060708"
pin="123456"

# ykman, always aimed at the test key
yk() {
  ykman --device "${YUBIKEY_FIXTURE_SERIAL}" "$@"
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# touch the key every second in the background until stop_touching
start_touching() {
  ( while sleep 1; do yubikey-fixture touch "${YUBIKEY_FIXTURE_SLOT}" 500 >/dev/null || exit; done ) &
  touch_pid=$!
}

stop_touching() {
  kill "${touch_pid}" 2>/dev/null
  wait "${touch_pid}" 2>/dev/null
}

# reset PIV and make a 9c key that needs a touch for every signature
make_touch_key() {
  yk piv reset -f >/dev/null || fail "piv reset"
  yk piv keys generate -m "${mgmt_key}" -a ECCP256 --pin-policy once --touch-policy always \
    9c /tmp/pub.pem >/dev/null || fail "generating the 9c key"
}

# sign with the 9c key (a self-signed certificate): waits up to 15 s for a touch
sign() {
  yk piv certificates generate -m "${mgmt_key}" -P "${pin}" -s CN=fixture-touch-test 9c /tmp/pub.pem
}
