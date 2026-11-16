#!/bin/bash
# second half of the power-cycle test (see cycle_before.sh): after the cycle,
# the step sees the key again, with the CHUID cycle_before.sh wrote
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

[ "$(cat /state/marker 2>/dev/null)" = "${YUBIKEY_FIXTURE_SERIAL}" ] || fail "no marker from cycle_before.sh in /state"
yk piv objects export CHUID /tmp/chuid || fail "reading the CHUID after the cycle"
cmp -s /state/chuid /tmp/chuid || fail "the CHUID changed across the power cycle"
echo "PASS"
