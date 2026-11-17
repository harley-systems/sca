#!/bin/bash
################################################################################
# hardware check for sca security_key openpgp_init, on the test YubiKey only.
# not a tests/test_*.sh, so make check doesn't run it.
#
#   tests/hardware/openpgp_init.sh [SERIAL]
#
# it RESETS the OpenPGP applet of the key (deleting its OpenPGP keys) before
# and after, then runs openpgp_init unattended with PIN files and checks, with
# ykman, that the old PINs are rejected and the new ones work; that a rerun
# without --roll is refused and changes nothing; and that --roll changes them.
# no touch is needed: no key is generated and no touch policy is set.
#
# it acts only on the test key, serial 38263298, and refuses any other. every
# ykman call names it with --device; gpg is only read when its current card is
# that key. needs gpg, gpgconf and ykman, and a built sca (make).

# shellcheck disable=SC2015 # pass and fail always return 0
test_serial=38263298
serial="${1:-$test_serial}"
if [ "$serial" != "$test_serial" ]; then
  echo "error: this check only runs on the test key $test_serial, not '$serial'." >&2
  exit 2
fi
repo="$(cd "$(dirname "$0")/../.." && pwd)"
sca_sh="$repo/build/sca.sh"
[ -f "$sca_sh" ] || { echo "error: $sca_sh not found. run make first." >&2; exit 2; }
for tool in gpg gpgconf ykman; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found." >&2; exit 2; }
done
if ! ykman list --serials | grep -qx "$serial"; then
  echo "error: the test key $serial is not attached." >&2
  exit 2
fi

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}
pass() {
  echo "ok: $*"
}

# ykman and scdaemon can't both hold the card
yk() {
  gpgconf --kill scdaemon >/dev/null 2>&1
  ykman --device "$serial" "$@"
}

reset_applet() {
  yk openpgp reset --force >/dev/null 2>&1 || fail "ykman openpgp reset"
}

pins="$(mktemp -d)" || exit 2
chmod 700 "$pins"
trap 'reset_applet; rm -rf "$pins"' EXIT

# the PINs are test values on a test key, so ykman may take them as arguments
user_ok() {
  yk openpgp access change-pin --pin "$1" --new-pin "$1" >/dev/null 2>&1
}
admin_ok() {
  yk openpgp access change-admin-pin --admin-pin "$1" --new-admin-pin "$1" >/dev/null 2>&1
}
# prints "<user> <reset code> <admin>" tries remaining
counters() {
  yk openpgp info 2>/dev/null | awk -F: '
    /^PIN tries remaining/ { u = $2 }
    /^Reset code tries remaining/ { r = $2 }
    /^Admin PIN tries remaining/ { a = $2 }
    END { gsub(/[[:space:]]/, "", u); gsub(/[[:space:]]/, "", r); gsub(/[[:space:]]/, "", a); print u, r, a }'
}

printf '%s\n' hw-user-111 > "$pins/user"
printf '%s\n' hw-admin-2222 > "$pins/admin"
printf '%s\n' hw-reset-3333 > "$pins/reset"
printf '%s\n' hw-user-444 > "$pins/user2"
printf '%s\n' hw-admin-5555 > "$pins/admin2"

# 1. a factory-fresh applet
reset_applet

# 2. openpgp_init, unattended
if output=$(bash "$sca_sh" security_key openpgp_init --device "$serial" --retries 5 \
    --user-pin-file "$pins/user" --admin-pin-file "$pins/admin" \
    --reset-code-file "$pins/reset" < /dev/null 2>&1); then
  pass "openpgp_init on the default PINs"
else
  fail "openpgp_init on the default PINs: $output"
fi
echo "$output"

# 3. the counters, from ykman, and from gpg when its card is the test key
c=$(counters)
[ "$c" = "5 5 5" ] && pass "retry counters 5 5 5" || fail "retry counters: '$c'"
status=$(gpg --batch --card-status --with-colons 2>/dev/null)
if [ "$(printf '%s\n' "$status" | awk -F: '$1 == "serial" { print $2 + 0 }')" = "$serial" ]; then
  r=$(printf '%s\n' "$status" | awk -F: '$1 == "pinretries" { print $2, $3, $4 }')
  [ "$r" = "5 5 5" ] && pass "gpg --card-status counters 5 5 5" || fail "gpg --card-status counters: '$r'"
else
  echo "note: gpg's current card is not the test key, gpg --card-status not checked"
fi

# 4. the old PINs are rejected, the new ones work
user_ok 123456 && fail "user PIN 123456 still works" || pass "user PIN 123456 rejected"
admin_ok 12345678 && fail "admin PIN 12345678 still works" || pass "admin PIN 12345678 rejected"
user_ok hw-user-111 && pass "new user PIN works" || fail "new user PIN rejected"
admin_ok hw-admin-2222 && pass "new admin PIN works" || fail "new admin PIN rejected"

# 5. a rerun without --roll is refused and changes nothing; --roll changes them
if output=$(bash "$sca_sh" security_key openpgp_init --device "$serial" \
    --user-pin-file "$pins/user2" --admin-pin-file "$pins/admin2" < /dev/null 2>&1); then
  fail "a rerun without --roll exits 0: $output"
elif [[ "$output" == *"not the factory default"* ]]; then
  pass "a rerun without --roll is refused"
else
  fail "a rerun without --roll fails for another reason: $output"
fi
user_ok hw-user-111 && pass "user PIN unchanged by the refused run" || fail "user PIN changed by the refused run"
admin_ok hw-admin-2222 && pass "admin PIN unchanged by the refused run" || fail "admin PIN changed by the refused run"
if output=$(bash "$sca_sh" security_key openpgp_init --device "$serial" --roll \
    --current-admin-pin-file "$pins/admin" \
    --user-pin-file "$pins/user2" --admin-pin-file "$pins/admin2" < /dev/null 2>&1); then
  pass "openpgp_init --roll"
else
  fail "openpgp_init --roll: $output"
fi
user_ok hw-user-111 && fail "the old user PIN works after --roll" || pass "old user PIN rejected after --roll"
user_ok hw-user-444 && pass "user PIN from --roll works" || fail "user PIN from --roll rejected"
admin_ok hw-admin-5555 && pass "admin PIN from --roll works" || fail "admin PIN from --roll rejected"

# 6. the applet is reset on exit
echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
