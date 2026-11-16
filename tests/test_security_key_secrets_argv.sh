#!/bin/bash
# security_key verify, init, unblock_pin and upload: the yubikey pin, puk and
# management key never appear on the command line of a tool sca runs, where
# any local user could read them with ps. they reach the tool on stdin
# (yubico-piv-tool --stdin-input) or in its environment (pkcs11-tool --pin
# env:NAME), and they stay out of the detailed log.
#
# the tools are stubbed as exported shell functions, as in
# test_security_key_init.sh: a function gets the same argv a program on PATH
# would. each stub appends its argv to $HOME/argv, and every secret it receives
# to $HOME/received as "<action> <what> <value>".
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# one yubikey in reader 0, with the serial the default config expects for subca.
# OPENSC_VERSION sets the version --info reports.
opensc-tool() {
  echo "opensc-tool $*" >> "$HOME/argv"
  case "$1" in
    --info ) echo "OpenSC ${OPENSC_VERSION-0.23.0} [gcc  12.2.0]" ;;
    --list-readers )
      printf 'Nr.  Card  Features  Name\n'
      printf '0    Yes             Yubico YubiKey OTP+FIDO+CCID 00 00\n' ;;
    * ) return 1 ;;
  esac
}
ykman() {
  echo "ykman $*" >> "$HOME/argv"
  echo "Serial number: 5414483"
}
# a minimal PIV device kept in $HOME/device. it reads the values that are not
# on the command line from stdin, as the real tool does with --stdin-input and
# in the same order: the management key (bare -k) first for the actions that
# authenticate, then the current and the new value. NO_STDIN_INPUT makes it a
# yubico-piv-tool without --stdin-input.
yubico-piv-tool() {
  echo "yubico-piv-tool $*" >> "$HOME/argv"
  local key='' action='' old='' new='' slot='' input='' stdin_input=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --full-help )
        [ -n "${NO_STDIN_INPUT:-}" ] || echo '      --stdin-input        Read sensitive values from stdin'
        return 0 ;;
      --stdin-input ) [ -n "${NO_STDIN_INPUT:-}" ] && return 1; stdin_input=true ;;
      -k ) key='-' ;;
      --key=* ) key=${1#--key=} ;;
      -a ) action=$2; shift ;;
      -s ) slot=$2; shift ;;
      -i ) input=$2; shift ;;
      -P ) old=$2; shift ;;
      -n | -N ) new=$2; shift ;;
      --reader ) shift ;;
      --pin-policy=* | --touch-policy=* ) ;;
    esac
    shift
  done
  # take VAR from stdin unless it was given, and record what came in
  take() {
    if [ -z "${!1}" ] || [ "${!1}" = - ]; then
      [ $stdin_input = true ] || return 1
      read -r "$1" || return 1
      echo "$action $1 ${!1}" >> "$HOME/received"
    fi
  }
  case "$action" in
    set-mgm-key | import-key | import-certificate | delete-certificate )
      [ -z "$key" ] && key=010203040506070801020304050607080102030405060708
      take key || return 1
      [ "$key" = "$(cat "$HOME/device/key")" ] || { echo "Failed authentication" >&2; return 1; }
  esac
  case "$action" in
    set-mgm-key )
      take new || return 1
      printf '%s' "$new" > "$HOME/device/key" ;;
    change-pin | change-puk | unblock-pin )
      take old && take new || return 1
      local held=puk changed=pin
      [ "$action" = change-pin ] && held=pin
      [ "$action" = change-puk ] && changed=puk
      [ "$old" = "$(cat "$HOME/device/$held")" ] || return 1
      printf '%s' "$new" > "$HOME/device/$changed" ;;
    read-certificate ) cat "$HOME/device/crt-$slot" 2>/dev/null || { echo "Failed fetching certificate." >&2; return 1; } ;;
    delete-certificate ) rm -f "$HOME/device/crt-$slot" ;;
    import-certificate ) cat "${input:--}" > "$HOME/device/crt-$slot" ;;
    import-key ) cat "${input:--}" > "$HOME/device/key-$slot" ;;
    * ) return 1 ;;
  esac
}
# signs only with the pin on the device. --pin env:NAME takes the pin from the
# environment, as OpenSC's pkcs11-tool does.
pkcs11-tool() {
  echo "pkcs11-tool $*" >> "$HOME/argv"
  local pin='' out='' pin_var=''
  while [ $# -gt 0 ]; do
    case "$1" in
      --pin )
        pin=$2
        if [[ "$pin" == env:* ]]; then
          pin_var=${pin#env:}
          pin=${!pin_var}
          echo "sign env:pin $pin" >> "$HOME/received"
        fi
        shift ;;
      -o ) out=$2; shift ;;
    esac
    shift
  done
  if [ "$pin" != "$(cat "$HOME/device/pin")" ]; then
    echo "error: PKCS11 function C_Login failed: rv = CKR_PIN_INCORRECT (0xa0)" >&2
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

default_key=010203040506070801020304050607080102030405060708
default_pin=123456
default_puk=12345678

# a factory-fresh key and an empty ~/.sca with the default config
reset_state() {
  rm -rf "$HOME/.sca" "$HOME/device" "$HOME/argv" "$HOME/received" "$HOME/output"
  mkdir -p "$HOME/device"
  printf '%s' "$default_key" > "$HOME/device/key"
  printf '%s' "$default_pin" > "$HOME/device/pin"
  printf '%s' "$default_puk" > "$HOME/device/puk"
  sca config create all >/dev/null 2>&1 || fail "config create all"
  # verify needs a ykcs11 module file to exist; pkcs11-tool is stubbed
  touch "$HOME/libykcs11.so"
  echo "export ykcs11_module=\"$HOME/libykcs11.so\"" >> "$HOME/.sca/config/sca.config"
  : > "$HOME/argv"
  : > "$HOME/received"
  unset NO_STDIN_INPUT OPENSC_VERSION
}

file_of() {
  find "$HOME/.sca" -name "*-subca-yubikey-$1.txt"
}

# run sca with -d, keeping its terminal output in $HOME/output
run() {
  sca -d "$@" >> "$HOME/output" 2>&1
}

# every secret seen in this run: the defaults, and what is or was in the files
secrets() {
  printf '%s\n' "$default_key" "$default_pin" "$default_puk"
  find "$HOME/.sca" -name '*yubikey-*.txt*' -exec sh -c 'cat "$1"; echo' _ {} \;
}

# assert_no_secrets_leaked MESSAGE - not in any argv, the output or the log
assert_no_secrets_leaked() {
  local secret
  [ -s "$HOME/argv" ] || fail "$1: no tool was run"
  while read -r secret; do
    [ -n "$secret" ] || continue
    grep -qF -- "$secret" "$HOME/argv" && fail "$1: '$secret' on a command line: $(grep -F -- "$secret" "$HOME/argv")"
    grep -qF -- "$secret" "$HOME/output" && fail "$1: '$secret' in the output"
    grep -qF -- "$secret" "$HOME/.sca/log" 2>/dev/null && fail "$1: '$secret' in the log"
  done < <(secrets | sort -u)
}

# --- init: each value arrives on stdin, in the order yubico-piv-tool reads it
reset_state
run security_key init subca || fail "init"
expected="set-mgm-key key $default_key
set-mgm-key new $(cat "$(file_of key)")
change-pin old $default_pin
change-pin new $(cat "$(file_of pin)")
change-puk old $default_puk
change-puk new $(cat "$(file_of puk)")"
assert_eq "$expected" "$(cat "$HOME/received")" "init: values received on stdin"
assert_no_secrets_leaked "init"

# --- init --roll-keys: the old values from the files, then the new ones
old_key="$(cat "$(file_of key)")"
old_pin="$(cat "$(file_of pin)")"
old_puk="$(cat "$(file_of puk)")"
: > "$HOME/received"
run security_key init --roll-keys subca || fail "init --roll-keys"
expected="set-mgm-key key $old_key
set-mgm-key new $(cat "$(file_of key)")
change-pin old $old_pin
change-pin new $(cat "$(file_of pin)")
change-puk old $old_puk
change-puk new $(cat "$(file_of puk)")"
assert_eq "$expected" "$(cat "$HOME/received")" "init --roll-keys: values received on stdin"
assert_no_secrets_leaked "init --roll-keys"

# --- verify: the pin arrives in pkcs11-tool's environment
: > "$HOME/received"
run security_key verify subca || fail "verify"
grep -q SUCCESS "$HOME/output" || fail "verify signs with the pin: $(cat "$HOME/output")"
assert_eq "sign env:pin $(cat "$(file_of pin)")" "$(cat "$HOME/received")" "verify: pin received through env:"
assert_no_secrets_leaked "verify"

# --- unblock_pin: the puk, then the new pin, on stdin
for keep in '' --keep-pin; do
  pin_before="$(cat "$(file_of pin)")"
  : > "$HOME/received"
  run security_key unblock_pin $keep subca || fail "unblock_pin $keep"
  [ -n "$keep" ] && assert_eq "$pin_before" "$(cat "$(file_of pin)")" "unblock_pin --keep-pin keeps the pin"
  expected="unblock-pin old $(cat "$(file_of puk)")
unblock-pin new $(cat "$(file_of pin)")"
  assert_eq "$expected" "$(cat "$HOME/received")" "unblock_pin $keep: values received on stdin"
  assert_no_secrets_leaked "unblock_pin $keep"
done

# --- upload key (through create key), crt, and crt --force over an occupied
# slot: the management key arrives on stdin, the file through -i
: > "$HOME/received"
run create key subca || fail "create key (uploads the key)"
key_file="$(find "$HOME/.sca" -name '*-subca-key.pem')"
assert_eq "$(cat "$key_file")" "$(cat "$HOME/device/key-9c" 2>/dev/null)" "upload key: key imported"
crt_file="$(dirname "$(dirname "$key_file")")/$(basename "${key_file%key.pem}")crt.pem"
openssl req -x509 -new -key "$key_file" -subj /CN=subca -days 1 -out "$crt_file" 2>/dev/null || \
  fail "a certificate to upload"
run security_key upload subca crt || fail "upload crt"
assert_eq "$(cat "$crt_file")" "$(cat "$HOME/device/crt-9c" 2>/dev/null)" "upload crt: certificate imported"
run security_key upload --force subca crt || fail "upload --force crt"
mgm_key="$(cat "$(file_of key)")"
expected="import-key key $mgm_key
import-certificate key $mgm_key
delete-certificate key $mgm_key
import-certificate key $mgm_key"
assert_eq "$expected" "$(cat "$HOME/received")" "upload: management key received on stdin"
assert_no_secrets_leaked "upload"

# --- a yubico-piv-tool without --stdin-input: refused before anything changes
reset_state
export NO_STDIN_INPUT=1
assert_fails sca security_key init subca
assert_eq "" "$(find "$HOME/.sca" -name '*yubikey-*.txt*')" "no credential files without --stdin-input"
assert_eq "$default_key" "$(cat "$HOME/device/key")" "key unchanged without --stdin-input"
unset NO_STDIN_INPUT
sca security_key init subca >/dev/null 2>&1 || fail "init"
export NO_STDIN_INPUT=1
: > "$HOME/argv"
pin_before="$(cat "$(file_of pin)")"
stderr="$(sca security_key unblock_pin subca 2>&1 >/dev/null)"
assert_eq 1 "$?" "unblock_pin without --stdin-input exit code"
[[ "$stderr" == *"--stdin-input"* ]] || fail "unblock_pin: stderr names --stdin-input: '$stderr'"
assert_eq "$pin_before" "$(cat "$(file_of pin)")" "pin file unchanged without --stdin-input"
assert_eq "" "$(find "$HOME/.sca" -name '*.new.*')" "no temporary files without --stdin-input"
assert_fails sca security_key upload subca crt
grep -q -- '-a ' "$HOME/argv" && fail "an action was run without --stdin-input: $(grep -- '-a ' "$HOME/argv")"
unset NO_STDIN_INPUT

# --- an OpenSC too old for --pin env: (or of unknown version): verify stops
# before the pin is tried
for OPENSC_VERSION in 0.14.0 '' unknown; do
  export OPENSC_VERSION
  : > "$HOME/argv"
  stderr="$(sca security_key verify subca 2>&1 >/dev/null)"
  assert_eq 1 "$?" "verify with OpenSC '$OPENSC_VERSION' exit code"
  [[ "$stderr" == *"OpenSC 0.15.0 or newer"* ]] || \
    fail "verify with OpenSC '$OPENSC_VERSION': stderr names the version needed: '$stderr'"
  grep -q '^pkcs11-tool' "$HOME/argv" && fail "pkcs11-tool run with OpenSC '$OPENSC_VERSION'"
done
for OPENSC_VERSION in 0.15.0 0.20.0 1.0; do
  export OPENSC_VERSION
  output="$(sca security_key verify subca 2>&1)"
  [[ "$output" == *SUCCESS* ]] || fail "verify with OpenSC '$OPENSC_VERSION': '$output'"
done
unset OPENSC_VERSION

test_done
