#!/bin/bash
# security_key wait_for: with no one to insert a key it must give up and fail,
# not wait forever; with the right key attached it must return at once.
#
# the reader tools are stubbed as exported shell functions, as in
# test_security_key_init.sh. STUB_SERIAL is the serial of the key in reader 0;
# empty means no card at all, '-' a card whose serial can not be read.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

opensc-tool() {
  [ "$1" = "--list-readers" ] || return 1
  printf 'Nr.  Card  Features  Name\n'
  if [ -n "${STUB_SERIAL:-}" ]; then
    printf '0    Yes             Yubico YubiKey OTP+FIDO+CCID 00 00\n'
  else
    printf '0    No              Yubico YubiKey OTP+FIDO+CCID 00 00\n'
  fi
}
ykman() {
  [ "${STUB_SERIAL:-}" = "-" ] && return 1
  echo "Serial number: ${STUB_SERIAL}"
}
export -f opensc-tool ykman
unset security_key_wait_timeout

sca config create all >/dev/null 2>&1 || fail "config create all"
# the serial the default config expects for subca
right_serial=5414483

# run_wait ARGS... - run wait_for with stdin closed; sets status, out, err and
# elapsed (whole seconds)
run_wait() {
  local start=$SECONDS
  out=$(sca security_key wait_for "$@" </dev/null 2>"$HOME/err")
  status=$?
  elapsed=$((SECONDS - start))
  err=$(cat "$HOME/err")
}

# assert_within LOW HIGH MESSAGE - elapsed is between LOW and HIGH seconds
assert_within() {
  if [ "$elapsed" -lt "$1" ] || [ "$elapsed" -gt "$2" ]; then
    fail "$3: took ${elapsed}s, expected $1-$2s"
  fi
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "$3: '$2' not in '$1'"
}

# --- no key, --timeout 2: fails within the limit, says what to do, no stdout
export STUB_SERIAL=''
run_wait --timeout 2 subca
[ "$status" -ne 0 ] || fail "no key, --timeout 2: expected failure"
assert_within 2 4 "no key, --timeout 2"
assert_eq '' "$out" "no key: nothing on stdout"
assert_contains "$err" "'subca'" "no key: names the entity"
assert_contains "$err" "serial $right_serial" "no key: names the awaited serial"
assert_contains "$err" "attached: none" "no key: says none was attached"
assert_contains "$err" "--device SERIAL" "no key: points to --device"
assert_contains "$err" "subca_use_security_key=false" "no key: points to use_security_key"

# --- no key, nothing set, stdin not a terminal: the 10 second default
run_wait subca
[ "$status" -ne 0 ] || fail "no key, default: expected failure"
assert_within 10 12 "no key, default limit"
assert_contains "$err" "within 10 s" "no key, default: names the limit"

# --- security_key_wait_timeout is honoured, and --timeout wins over it
security_key_wait_timeout=1 run_wait subca
[ "$status" -ne 0 ] || fail "security_key_wait_timeout=1: expected failure"
assert_within 1 3 "security_key_wait_timeout=1"
security_key_wait_timeout=30 run_wait --timeout 1 subca
[ "$status" -ne 0 ] || fail "--timeout over the variable: expected failure"
assert_within 1 3 "--timeout wins over security_key_wait_timeout"

# --- a key with another serial times out, and is named as attached
export STUB_SERIAL=12345678
run_wait --timeout 1 subca
[ "$status" -ne 0 ] || fail "wrong serial: expected failure"
assert_within 1 3 "wrong serial"
assert_contains "$err" "attached: 12345678." "wrong serial: names the attached serial"

# --- --device names the awaited serial in the message
run_wait --timeout 1 --device 87654321 subca
assert_contains "$err" "serial 87654321" "--device: names the asked-for serial"

# --- a card whose serial can not be read is mentioned
export STUB_SERIAL=-
run_wait --timeout 1 subca
[ "$status" -ne 0 ] || fail "unreadable card: expected failure"
assert_contains "$err" "could not be read)" "unreadable card: mentioned in the error"

# --- the right key returns at once, with and without a limit
export STUB_SERIAL=$right_serial
run_wait subca
assert_eq 0 "$status" "right serial: exit status"
assert_eq 0 "$out" "right serial: reader number"
assert_within 0 1 "right serial, no limit set"
run_wait --timeout 2 subca
assert_eq 0 "$status" "right serial, --timeout 2: exit status"
assert_eq 0 "$out" "right serial, --timeout 2: reader number"
assert_within 0 1 "right serial, --timeout 2"
security_key_wait_timeout=0 run_wait subca
assert_eq 0 "$status" "right serial, security_key_wait_timeout=0: exit status"

# --- invalid values fail at once
for value in abc -1 1.5 ''; do
  run_wait --timeout "$value" subca
  assert_eq 1 "$status" "--timeout '$value': exit status"
  assert_within 0 1 "--timeout '$value': fails at once"
  assert_contains "$err" "--timeout" "--timeout '$value': names the option"
done
security_key_wait_timeout=abc run_wait subca
assert_eq 1 "$status" "security_key_wait_timeout=abc: exit status"
assert_contains "$err" "security_key_wait_timeout" "security_key_wait_timeout=abc: names the variable"

# --- a caller stops when wait_for gives up, rather than signing on with an
# empty reader number: create crt with a key-backed subca and no key attached
export STUB_SERIAL=''
echo "export opensc_pkcs11_module=$HOME/stub-module.so" >> "$HOME/.sca/config/sca.config"
touch "$HOME/stub-module.so"
p11tool() { echo "p11tool was called" >&2; }
export -f p11tool
start=$SECONDS
err=$(security_key_wait_timeout=1 sca create crt service </dev/null 2>&1 >/dev/null)
status=$?
elapsed=$((SECONDS - start))
[ "$status" -ne 0 ] || fail "create crt, no key: expected failure"
assert_within 1 3 "create crt, no key"
assert_contains "$err" "no security key for 'subca'" "create crt, no key: wait_for's error"
[[ "$err" == *"p11tool was called"* ]] && fail "create crt, no key: ran on past wait_for"

test_done
