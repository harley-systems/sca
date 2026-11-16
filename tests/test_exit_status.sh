#!/bin/bash
# the exit status of the subcommand that ran is sca's exit status: a subcommand
# that reports failure with 'return 1' rather than through error must make sca
# exit non-zero, and a passing one must still exit 0.
#
# security_key verify is the case that matters: it is the documented check
# that a key is present and can sign. the tools it calls are stubbed as
# exported shell functions, as in test_security_key_init.sh.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# one yubikey in reader 0
opensc-tool() {
  [ "$1" = "--list-readers" ] || return 1
  printf 'Nr.  Card  Features  Name\n'
  printf '0    Yes             Yubico YubiKey OTP+FIDO+CCID 00 00\n'
}
ykman() {
  echo "Serial number: 5414483"
}
# signs by writing a non-empty file to the -o argument, unless SIGN_FAIL is set,
# in which case it fails the way pkcs11-tool does on an empty slot
pkcs11-tool() {
  if [ -n "${SIGN_FAIL:-}" ]; then
    echo "error: PKCS11 function C_SignInit failed: rv = CKR_KEY_HANDLE_INVALID (0x60)"
    return 1
  fi
  while [ $# -gt 0 ]; do
    [ "$1" = "-o" ] && printf 'signature' > "$2"
    shift
  done
  return 0
}
export -f opensc-tool ykman pkcs11-tool

sca config create all >/dev/null 2>&1 || fail "config create all"
# a module file where the config says it is, so verify needs no real ykcs11
echo "ykcs11_module=${HOME}/libykcs11.so" >> "$HOME/.sca/config/sca.config"
touch "$HOME/libykcs11.so"

verify_subca() {
  sca security_key verify subca <<< 123456
}

# a signing test that fails exits non-zero, and says why
export SIGN_FAIL=1
assert_fails verify_subca
output=$(verify_subca 2>&1)
[[ "$output" == *"FAILED:"* ]] || fail "verify failure output has no FAILED: line: $output"

# a signing test that passes exits 0
unset SIGN_FAIL
assert_succeeds verify_subca
output=$(verify_subca 2>&1)
[[ "$output" == *"SUCCESS:"* ]] || fail "verify success output has no SUCCESS: line: $output"

# a run that succeeds through another dispatcher still exits 0: listing with
# nothing created yet, where list_* used to return the status of a failed test
assert_succeeds sca list cas
assert_succeeds sca list all

test_done
