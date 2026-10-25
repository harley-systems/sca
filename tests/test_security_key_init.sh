#!/bin/bash
# security_key init: the pin, puk and management key files must always match
# what is on the key, and must be readable by their owner only.
#
# the tools init calls are stubbed as exported shell functions rather than
# scripts on PATH: they reach the sca child process just the same, and work
# where the temporary folder is mounted noexec.
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
# a minimal PIV device kept in $HOME/device. an action fails if it is named in
# PIV_FAIL, or if the management key, pin or puk given does not match.
yubico-piv-tool() {
  local key='' action='' old='' new=''
  while [ $# -gt 0 ]; do
    case "$1" in
      -k ) key=$2; shift ;;
      -a ) action=$2; shift ;;
      -P ) old=$2; shift ;;
      -n | -N ) new=$2; shift ;;
      --reader ) shift ;;
    esac
    shift
  done
  [ "$action" = "${PIV_FAIL:-}" ] && return 1
  [ "$key" = "$(cat "$HOME/device/key")" ] || return 1
  case "$action" in
    set-mgm-key ) printf '%s' "$new" > "$HOME/device/key" ;;
    change-pin )
      [ "$old" = "$(cat "$HOME/device/pin")" ] || return 1
      printf '%s' "$new" > "$HOME/device/pin" ;;
    change-puk )
      [ "$old" = "$(cat "$HOME/device/puk")" ] || return 1
      printf '%s' "$new" > "$HOME/device/puk" ;;
    * ) return 1 ;;
  esac
}
export -f opensc-tool ykman yubico-piv-tool
# init generates its values with hexdump, which minimal systems may lack. this
# stand-in covers only the two formats init uses.
if ! command -v hexdump >/dev/null; then
  hexdump() {
    case "$*" in
      *%02X* ) od -An -v -tx1 | tr -d ' \n' | tr 'a-f' 'A-F' ;;
      *%u* ) od -An -v -tu1 | tr -d ' \n' ;;
    esac
  }
  export -f hexdump
fi

# reset to a factory-fresh key and an empty ~/.sca with the default config
reset_state() {
  rm -rf "$HOME/.sca" "$HOME/device"
  mkdir -p "$HOME/device"
  printf '%s' 010203040506070801020304050607080102030405060708 > "$HOME/device/key"
  printf '%s' 123456 > "$HOME/device/pin"
  printf '%s' 12345678 > "$HOME/device/puk"
  sca config create all >/dev/null 2>&1 || fail "config create all"
  unset PIV_FAIL
}

credential_files() {
  find "$HOME/.sca" -name '*yubikey-*.txt*' | sort
}

file_of() {
  find "$HOME/.sca" -name "*-subca-yubikey-$1.txt"
}

# assert_files_match_device MESSAGE
assert_files_match_device() {
  local name
  for name in key pin puk; do
    assert_eq "$(cat "$HOME/device/$name")" "$(cat "$(file_of "$name")" 2>/dev/null)" \
      "$1: $name file matches the key"
  done
}

perm() {
  stat -c '%a' "$1"
}

# --- init before create key: folder is created, files are 0600, folder 0700
reset_state
assert_succeeds sca security_key init subca
private_folder="$(dirname "$(file_of pin)")"
assert_eq 700 "$(perm "$private_folder")" "private folder mode"
for name in key pin puk; do
  assert_file_exists "$(file_of "$name")" "$name file after init"
  assert_eq 600 "$(perm "$(file_of "$name")")" "$name file mode"
done
assert_files_match_device "after init"
assert_eq 3 "$(credential_files | wc -l)" "no temporary files left after init"

# --- a successful --roll-keys keeps the old files as backups
assert_succeeds sca security_key init --roll-keys subca
assert_files_match_device "after roll"
assert_eq 6 "$(credential_files | wc -l)" "three files and three backups after roll"

# --- the first step fails on a fresh key: no files are left behind
reset_state
export PIV_FAIL=set-mgm-key
assert_fails sca security_key init subca
assert_eq "" "$(credential_files)" "no files after a failed init"

# --- the first step fails on --roll-keys: the files are unchanged
reset_state
sca security_key init subca >/dev/null 2>&1
before="$(for f in $(credential_files); do echo "$f"; cat "$f"; echo; done)"
export PIV_FAIL=set-mgm-key
assert_fails sca security_key init --roll-keys subca
after="$(for f in $(credential_files); do echo "$f"; cat "$f"; echo; done)"
assert_eq "$before" "$after" "files unchanged after a failed roll"
assert_files_match_device "after a failed roll"

# --- a later step fails: the files record what is on the key, stderr says so
for step in change-pin change-puk; do
  reset_state
  export PIV_FAIL=$step
  stderr="$(sca security_key init subca 2>&1 >/dev/null)"
  assert_eq 1 "$?" "$step failure exit code"
  assert_files_match_device "after $step failed"
  assert_eq 3 "$(credential_files | wc -l)" "no temporary files left after $step failed"
  case "$step" in
    change-pin ) expected='Changed on the key: management key.' ;;
    change-puk ) expected='Changed on the key: management key, pin.' ;;
  esac
  [[ "$stderr" == *"$expected"* ]] || fail "$step: stderr names what changed: '$stderr'"
done

# --- a later step fails on --roll-keys: same, and the old files are backed up
reset_state
sca security_key init subca >/dev/null 2>&1
export PIV_FAIL=change-pin
assert_fails sca security_key init --roll-keys subca
assert_files_match_device "after change-pin failed on roll"
assert_eq 6 "$(credential_files | wc -l)" "three files and three backups after partial roll"

# --- a missing or invalid entity names the right command
reset_state
for entity in '' bogus; do
  stderr="$(sca security_key init $entity 2>&1 >/dev/null)"
  [[ "$stderr" == *"security_key init"* ]] || \
    fail "entity '$entity': error names security_key init: '$stderr'"
  [[ "$stderr" == *"wait_for"* ]] && fail "entity '$entity': error names wait_for: '$stderr'"
done

test_done
