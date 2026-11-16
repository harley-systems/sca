#!/bin/bash
# second half of the two-step test (see steps_before.sh): a fresh container,
# with its own pcscd, sees the same key with the CHUID steps_before.sh wrote,
# and the marker it left in /state
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

[ "$(cat /state/marker 2>/dev/null)" = "${YUBIKEY_FIXTURE_SERIAL}" ] || fail "no marker from steps_before.sh in /state"
yk piv objects export CHUID /tmp/chuid || fail "reading the CHUID in the second step"
cmp -s /state/chuid /tmp/chuid || fail "the CHUID changed between the steps"
echo "PASS"
