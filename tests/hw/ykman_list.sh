#!/bin/bash
# the test container sees exactly one YubiKey: the slot's test key
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

serials="$(ykman list --serials)"
echo "ykman list --serials: ${serials}"
[ "${serials}" = "${YUBIKEY_FIXTURE_SERIAL}" ] || fail "expected only ${YUBIKEY_FIXTURE_SERIAL}"
echo "PASS"
