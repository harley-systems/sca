#!/bin/bash
# security_key otp_chalresp on the test YubiKey (serial 38263298): setup with no
# touch, then test, and the response must be the HMAC-SHA1 of the challenge
# under the secret setup wrote. slot 2 is deleted again whatever happens.
#
# the test key is reached through the yubikey-fixture broker (#179). until the
# broker defines how a test finds it, this runs only when
# SCA_TEST_YUBIKEY_BROKER names its socket, and is skipped otherwise. it never
# touches any key but the test key.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

test_serial=38263298

if [ -z "${SCA_TEST_YUBIKEY_BROKER}" ] || [ ! -S "${SCA_TEST_YUBIKEY_BROKER}" ]; then
  echo "  skipped: no yubikey-fixture broker socket (SCA_TEST_YUBIKEY_BROKER, see #179)"
  test_done
fi
command -v ykman >/dev/null 2>&1 || { fail "ykman not found"; test_done; }

# shellcheck disable=SC2317 # called by the trap
cleanup_slot() {
  local status=$?
  ykman --device "${test_serial}" otp delete -f 2 >/dev/null 2>&1
  (exit "${status}")
  test_exit
}
trap cleanup_slot EXIT

secret_file="$HOME/chalresp.txt"
output="$(sca security_key otp_chalresp setup -f --device "${test_serial}" --secret-file "${secret_file}" 2>&1)" \
  || { fail "setup on the test key: $output"; test_done; }
output="$(sca security_key otp_chalresp test --device "${test_serial}" 2>&1)" \
  || { fail "test on the test key: $output"; test_done; }
challenge="$(printf '%s\n' "$output" | awk '$1 == "challenge:" { print $2 }')"
response="$(printf '%s\n' "$output" | awk '$1 == "response:" { print $2 }')"

# the throwaway test secret on openssl's argv is fine here, and only here
secret="$(cat "${secret_file}")"
# hex_bytes HEX - print HEX as raw bytes
hex_bytes() {
  # shellcheck disable=SC2059 # the format is the escaped bytes
  printf "$(printf '%s' "$1" | sed 's/../\\x&/g')"
}
expected="$(hex_bytes "${challenge}" | openssl mac -digest SHA1 -macopt "hexkey:${secret}" HMAC 2>/dev/null)" || expected=''
if [ -z "${expected}" ]; then
  expected="$(hex_bytes "${challenge}" | openssl dgst -sha1 -mac HMAC -macopt "hexkey:${secret}" | awk '{ print $NF }')"
fi
assert_eq "${expected,,}" "${response,,}" "response of the test key to challenge ${challenge}"
test_done
