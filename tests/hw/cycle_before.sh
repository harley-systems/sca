#!/bin/bash
# first half of a power-cycle test: run as
#   yubikey-fixture run tests/hw/cycle_before.sh SHA SLOT cycle tests/hw/cycle_after.sh
# leaves a marker in /state and a fresh PIV CHUID on the key
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

yk piv objects generate -m "${mgmt_key}" CHUID || fail "generating a CHUID"
yk piv objects export CHUID /state/chuid || fail "reading the CHUID"
echo "${YUBIKEY_FIXTURE_SERIAL}" > /state/marker
echo "PASS"
