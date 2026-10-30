#!/bin/bash
# security_key unblock_pin: a blocked pin is unblocked with the stored puk, the
# pin file then matches the key, and a refused puk is tried once only and
# leaves the pin file as it was.
#
# the tools are stubbed as exported shell functions, as in
# test_security_key_init.sh.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# one yubikey in reader 0, with the serial the default config expects for subca
opensc-tool() {
  [ "$1" = "--list-readers" ] || return 1
  printf 'Nr.  Card  Features  Name\n'
  printf '0    Yes             Yubico YubiKey OTP+FIDO+CCID 00 00\n'
}
ykman() {
  echo "Serial number: 5414483"
}
# a minimal PIV device kept in $HOME/device: pin, puk, the puk retries left in
# puk_tries, and a "blocked" file while the pin is blocked. the init actions
# only record the new values. every unblock-pin call is logged in
# $HOME/device/calls.
yubico-piv-tool() {
  local action='' old='' new=''
  while [ $# -gt 0 ]; do
    case "$1" in
      -a ) action=$2; shift ;;
      -P ) old=$2; shift ;;
      -N ) new=$2; shift ;;
      --reader ) shift ;;
    esac
    shift
  done
  case "$action" in
    set-mgm-key ) return 0 ;;
    change-pin ) printf '%s' "$new" > "$HOME/device/pin"; return 0 ;;
    change-puk ) printf '%s' "$new" > "$HOME/device/puk"; return 0 ;;
    unblock-pin ) echo "$action" >> "$HOME/device/calls" ;;
    * ) return 1 ;;
  esac
  local tries
  tries=$(cat "$HOME/device/puk_tries")
  if [ "$tries" -eq 0 ]; then
    echo "The puk code is blocked, you will have to reinitialize the application." >&2
    return 1
  fi
  if [ "$old" != "$(cat "$HOME/device/puk")" ]; then
    tries=$((tries - 1))
    echo "$tries" > "$HOME/device/puk_tries"
    echo "Failed changing/unblocking code, now $tries tries left before blocked." >&2
    return 1
  fi
  printf '%s' "$new" > "$HOME/device/pin"
  rm -f "$HOME/device/blocked"
}
# signs only with the pin on the device, and not while the pin is blocked
pkcs11-tool() {
  local pin='' out=''
  while [ $# -gt 0 ]; do
    case "$1" in
      --pin ) pin=$2; shift ;;
      -o ) out=$2; shift ;;
    esac
    shift
  done
  if [ -f "$HOME/device/blocked" ] || [ "$pin" != "$(cat "$HOME/device/pin")" ]; then
    echo "error: PKCS11 function C_Login failed: rv = CKR_PIN_LOCKED (0xa4)" >&2
    return 1
  fi
  echo signature > "$out"
}
export -f opensc-tool ykman yubico-piv-tool pkcs11-tool
# init and unblock_pin generate their values with hexdump, which minimal
# systems may lack. this stand-in covers only the two formats they use.
if ! command -v hexdump >/dev/null; then
  hexdump() {
    case "$*" in
      *%02X* ) od -An -v -tx1 | tr -d ' \n' | tr 'a-f' 'A-F' ;;
      *%u* ) od -An -v -tu1 | tr -d ' \n' ;;
    esac
  }
  export -f hexdump
fi

# init has run, so the pin and puk files hold what is on the key, and then
# the pin was blocked
reset_state() {
  rm -rf "$HOME/.sca" "$HOME/device"
  mkdir -p "$HOME/device"
  echo 3 > "$HOME/device/puk_tries"
  sca config create all >/dev/null 2>&1 || fail "config create all"
  # verify needs a ykcs11 module file to exist; pkcs11-tool is stubbed
  touch "$HOME/libykcs11.so"
  echo "export ykcs11_module=\"$HOME/libykcs11.so\"" >> "$HOME/.sca/config/sca.config"
  sca security_key init subca >/dev/null 2>&1 || fail "security_key init"
  pin_file="$(find "$HOME/.sca" -name '*-subca-yubikey-pin.txt')"
  puk_file="$(find "$HOME/.sca" -name '*-subca-yubikey-puk.txt')"
  old_pin="$(cat "$pin_file")"
  [ -n "$old_pin" ] || fail "pin file after init"
  touch "$HOME/device/blocked"
}

perm() {
  stat -c '%a' "$1"
}

leftover_files() {
  find "$HOME/.sca" -name '*.new.*'
}

# --- a blocked pin: verify fails and points to unblock_pin
reset_state
# (verify's exit code is not checked: sca exits 0 even when verify fails)
output="$(sca security_key verify subca 2>&1)"
[[ "$output" == *"FAILED"* ]] || fail "verify fails while the pin is blocked: '$output'"
[[ "$output" == *"sca security_key unblock_pin subca"* ]] || \
  fail "verify suggests unblock_pin: '$output'"

# --- unblock_pin sets a new pin, writes it 0600, and verify passes again
assert_succeeds sca security_key unblock_pin subca
[ -f "$HOME/device/blocked" ] && fail "pin still blocked after unblock_pin"
assert_eq "$(cat "$HOME/device/pin")" "$(cat "$pin_file")" "pin file matches the key"
[ "$(cat "$pin_file")" = "$old_pin" ] && fail "a new pin was not generated"
assert_eq 6 "$(wc -c < "$pin_file" | tr -d ' ')" "pin is 6 digits, no newline"
assert_eq 600 "$(perm "$pin_file")" "pin file mode"
assert_eq "" "$(leftover_files)" "no temporary files left after unblock_pin"
output="$(sca security_key verify subca 2>&1)"
[[ "$output" == *"SUCCESS"* ]] || fail "verify passes after unblock_pin: '$output'"

# --- --keep-pin sets the stored pin again and leaves the file alone
reset_state
assert_succeeds sca security_key unblock_pin --keep-pin subca
assert_eq "$old_pin" "$(cat "$HOME/device/pin")" "--keep-pin sets the stored pin"
assert_eq "$old_pin" "$(cat "$pin_file")" "--keep-pin leaves the pin file"
output="$(sca security_key verify subca 2>&1)"
[[ "$output" == *"SUCCESS"* ]] || fail "verify passes after --keep-pin: '$output'"

# --- a wrong puk: one attempt, pin file unchanged, retries reported
reset_state
printf '%s' 11111111 > "$puk_file"
stderr="$(sca security_key unblock_pin subca 2>&1 >/dev/null)"
assert_eq 1 "$?" "wrong puk exit code"
assert_eq "$old_pin" "$(cat "$pin_file")" "pin file unchanged after a wrong puk"
assert_eq 1 "$(grep -c unblock-pin "$HOME/device/calls")" "the puk is tried once only"
assert_eq "" "$(leftover_files)" "no temporary files left after a wrong puk"
[[ "$stderr" == *"2 puk retries remain"* ]] || fail "stderr gives the puk retries: '$stderr'"
[[ "$stderr" == *"docs/yubikey.md"* ]] || fail "stderr points to docs/yubikey.md: '$stderr'"

# --- a blocked puk says so
reset_state
echo 0 > "$HOME/device/puk_tries"
stderr="$(sca security_key unblock_pin subca 2>&1 >/dev/null)"
assert_eq 1 "$?" "blocked puk exit code"
assert_eq "$old_pin" "$(cat "$pin_file")" "pin file unchanged after a blocked puk"
[[ "$stderr" == *"puk is blocked"* ]] || fail "stderr says the puk is blocked: '$stderr'"

# --- no puk file: nothing is tried on the key
reset_state
rm -f "$puk_file"
assert_fails sca security_key unblock_pin subca
[ -f "$HOME/device/calls" ] && fail "the key was used without a puk file"
assert_eq "$old_pin" "$(cat "$pin_file")" "pin file unchanged without a puk file"

# --- a missing or invalid entity names the right command
reset_state
for entity in '' bogus; do
  stderr="$(sca security_key unblock_pin $entity 2>&1 >/dev/null)"
  [[ "$stderr" == *"security_key unblock_pin"* ]] || \
    fail "entity '$entity': error names security_key unblock_pin: '$stderr'"
done

test_done
