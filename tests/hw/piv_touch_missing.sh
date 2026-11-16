#!/bin/bash
# the same signature as piv_touch.sh fails when nobody touches the key, which
# shows piv_touch.sh passes because of the fixture's touch
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

make_touch_key
if sign; then
  fail "signing went through without a touch"
fi
echo "PASS"
