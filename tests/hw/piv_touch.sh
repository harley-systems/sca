#!/bin/bash
# a PIV signature that needs a touch goes through when the fixture touches the key
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

make_touch_key
start_touching
sign
status=$?
stop_touching
[ "${status}" -eq 0 ] || fail "signing with a touch failed"
echo "PASS"
