#!/bin/bash
# security_key fido2_ssh: the key type follows the firmware, the resident and
# verify-required flags follow the options, an existing key file is never
# touched, and every preflight failure exits non-zero.
#
# ykman, ssh and ssh-keygen are stubbed as exported shell functions, as in
# test_security_key_unblock_pin.sh. the stubs read what they report from
# files in $HOME/device, so each case can change one thing.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

ykman() {
  case "$*" in
    list ) cat "$HOME/device/list" ;;
    info ) echo "Device type: YubiKey 5 NFC"
           echo "Firmware version: $(cat "$HOME/device/firmware")" ;;
    "fido info" ) cat "$HOME/device/fido_info" ;;
    * ) return 1 ;;
  esac
}
ssh() {
  [ "$1" = -V ] || return 1
  echo "OpenSSH_$(cat "$HOME/device/openssh")p1 Ubuntu-3ubuntu13, OpenSSL 3.0.13 30 Jan 2024" >&2
}
# every call is logged in $HOME/calls, one argument per line and a "--" line
# after each call. -f FILE writes FILE and FILE.pub, -K writes the files in
# $HOME/device/resident to the current folder.
ssh-keygen() {
  printf '%s\n' "$@" -- >> "$HOME/calls"
  [ -f "$HOME/device/keygen_fails" ] && return 1
  local file='' restore=false
  while [ $# -gt 0 ]; do
    case "$1" in
      -f ) file=$2; shift ;;
      -K ) restore=true ;;
    esac
    shift
  done
  if [ $restore = true ]; then
    local name
    for name in $(cat "$HOME/device/resident"); do
      echo "restored key" > "$name"
      [[ "$name" == *.pub ]] || chmod 600 "$name"
    done
    return 0
  fi
  echo "private key" > "$file"
  echo "sk-ssh-ed25519@openssh.com AAAA test" > "$file.pub"
}
export -f ykman ssh ssh-keygen

# one YubiKey 5 with a FIDO2 PIN set, and OpenSSH 9.6
reset_state() {
  rm -rf "$HOME/.ssh" "$HOME/device" "$HOME/calls" "$HOME/out"
  mkdir -p "$HOME/device"
  echo "YubiKey 5 NFC (5.4.3) [OTP+FIDO+CCID] Serial: 12345678" > "$HOME/device/list"
  echo 5.4.3 > "$HOME/device/firmware"
  printf 'AAGUID: ee882879\nPIN: 8 attempt(s) remaining\n' > "$HOME/device/fido_info"
  echo 9.6 > "$HOME/device/openssh"
  : > "$HOME/device/resident"
}

# the arguments of the first ssh-keygen call, one per line
keygen_args() {
  sed '/^--$/q' "$HOME/calls" | sed '$d'
}

keygen_called() {
  [ -s "$HOME/calls" ]
}

sca config create all >/dev/null 2>&1 || fail "config create all"

# --- the default create: resident, verify-required, application ssh:sca
reset_state
output="$(sca security_key fido2_ssh create 2>&1)"
assert_eq 0 "$?" "default create exit code"
args="$(keygen_args)"
[[ "$args" == *$'-t\ned25519-sk'* ]] || fail "firmware 5.4.3 uses ed25519-sk: '$args'"
[[ "$args" == *$'-O\nresident'* ]] || fail "default create is resident: '$args'"
[[ "$args" == *$'-O\nverify-required'* ]] || fail "default create is verify-required: '$args'"
[[ "$args" == *$'-O\napplication=ssh:sca'* ]] || fail "default application is ssh:sca: '$args'"
[[ "$args" == *"-C"* ]] && fail "no -C without --comment: '$args'"
assert_file_exists "$HOME/.ssh/id_ed25519_sk_rk_sca" "default resident key file"
assert_eq 700 "$(stat -c '%a' "$HOME/.ssh")" "a new ~/.ssh is mode 700"
[[ "$output" == *"using ed25519-sk (firmware 5.4.3)"* ]] || fail "says which key type: '$output'"
[[ "$output" == *"sk-ssh-ed25519@openssh.com AAAA test"* ]] || fail "prints the public key: '$output'"
[[ "$output" == *"authorized_keys"* ]] || fail "prints the next step: '$output'"
[[ "$output" == *"ssh -i $HOME/.ssh/id_ed25519_sk_rk_sca"* ]] || \
  fail "says how to use a name ssh doesn't try: '$output'"

# --- firmware before 5.2.3 uses ecdsa-sk
reset_state
echo 5.2.2 > "$HOME/device/firmware"
assert_succeeds sca security_key fido2_ssh create
[[ "$(keygen_args)" == *$'-t\necdsa-sk'* ]] || fail "firmware 5.2.2 uses ecdsa-sk: '$(keygen_args)'"
assert_file_exists "$HOME/.ssh/id_ecdsa_sk_rk_sca" "ecdsa resident key file"

# --- firmware that can't be read uses ecdsa-sk
reset_state
echo unknown > "$HOME/device/firmware"
assert_succeeds sca security_key fido2_ssh create
[[ "$(keygen_args)" == *$'-t\necdsa-sk'* ]] || fail "unknown firmware uses ecdsa-sk: '$(keygen_args)'"

# --- --non-resident and --no-verify drop each flag
reset_state
assert_succeeds sca security_key fido2_ssh create --non-resident
args="$(keygen_args)"
[[ "$args" == *resident* ]] && fail "--non-resident drops -O resident: '$args'"
[[ "$args" == *verify-required* ]] || fail "--non-resident keeps verify-required: '$args'"
assert_file_exists "$HOME/.ssh/id_ed25519_sk" "default non-resident key file"
reset_state
assert_succeeds sca security_key fido2_ssh create --no-verify
args="$(keygen_args)"
[[ "$args" == *verify-required* ]] && fail "--no-verify drops verify-required: '$args'"
[[ "$args" == *$'-O\nresident'* ]] || fail "--no-verify keeps resident: '$args'"

# --- --non-resident --no-verify needs no FIDO2 PIN
reset_state
echo "PIN: Not set" > "$HOME/device/fido_info"
assert_succeeds sca security_key fido2_ssh create --non-resident --no-verify

# --- --application and --output
reset_state
assert_succeeds sca security_key fido2_ssh create --application ssh:work
[[ "$(keygen_args)" == *$'-O\napplication=ssh:work'* ]] || fail "--application ssh:work: '$(keygen_args)'"
assert_file_exists "$HOME/.ssh/id_ed25519_sk_rk_work" "resident key file named by the application"
reset_state
assert_succeeds sca security_key fido2_ssh create --application work --output "$HOME/out/my key"
[[ "$(keygen_args)" == *$'-O\napplication=ssh:work'* ]] || fail "--application work: '$(keygen_args)'"
assert_file_exists "$HOME/out/my key" "--output with a space"
reset_state
assert_fails sca security_key fido2_ssh create --application 'bad name'
keygen_called && fail "ssh-keygen ran with an invalid application"

# --- --comment with a space arrives as one argument
reset_state
assert_succeeds sca security_key fido2_ssh create --comment "me@my laptop"
[[ "$(keygen_args)" == *$'-C\nme@my laptop'* ]] || fail "--comment arrives whole: '$(keygen_args)'"

# --- an existing key or .pub: refused, ssh-keygen never runs, file unchanged
for existing in id_ed25519_sk_rk_sca id_ed25519_sk_rk_sca.pub; do
  reset_state
  mkdir -p "$HOME/.ssh"
  echo "keep me" > "$HOME/.ssh/$existing"
  stderr="$(sca security_key fido2_ssh create 2>&1 >/dev/null)"
  assert_eq 1 "$?" "existing $existing exit code"
  keygen_called && fail "ssh-keygen ran although $existing exists"
  assert_eq "keep me" "$(cat "$HOME/.ssh/$existing")" "$existing is unchanged"
  [[ "$stderr" == *"$HOME/.ssh/$existing"* ]] || fail "the error names $existing: '$stderr'"
  [[ "$stderr" == *"--output"* ]] || fail "the error suggests --output: '$stderr'"
  [[ "$stderr" == *"--application"* ]] || fail "the error suggests --application: '$stderr'"
done

# --- no FIDO2 PIN, in the ykman 4 and ykman 5 wordings
for wording in "PIN is not set." "PIN: Not set"; do
  reset_state
  echo "$wording" > "$HOME/device/fido_info"
  stderr="$(sca security_key fido2_ssh create 2>&1 >/dev/null)"
  assert_eq 1 "$?" "no PIN ('$wording') exit code"
  [[ "$stderr" == *"ykman fido access change-pin"* ]] || fail "no PIN: says how to set one: '$stderr'"
  keygen_called && fail "ssh-keygen ran without a PIN ('$wording')"
  assert_fails sca security_key fido2_ssh restore
done

# --- OpenSSH too old
reset_state
echo 8.1 > "$HOME/device/openssh"
stderr="$(sca security_key fido2_ssh create --non-resident --no-verify 2>&1 >/dev/null)"
assert_eq 1 "$?" "OpenSSH 8.1 exit code"
[[ "$stderr" == *"sca install --fido2"* ]] || fail "OpenSSH 8.1: suggests sca install --fido2: '$stderr'"
assert_fails sca security_key fido2_ssh restore
reset_state
echo 8.2 > "$HOME/device/openssh"
stderr="$(sca security_key fido2_ssh create 2>&1 >/dev/null)"
assert_eq 1 "$?" "OpenSSH 8.2 with verify-required exit code"
[[ "$stderr" == *"--no-verify"* ]] || fail "OpenSSH 8.2: suggests --no-verify: '$stderr'"
keygen_called && fail "ssh-keygen ran with OpenSSH 8.2 and verify-required"
assert_succeeds sca security_key fido2_ssh create --no-verify
reset_state
echo 8.3 > "$HOME/device/openssh"
assert_succeeds sca security_key fido2_ssh create
reset_state
echo 10.0 > "$HOME/device/openssh"
assert_succeeds sca security_key fido2_ssh create
reset_state
echo "x" > "$HOME/device/openssh"
assert_fails sca security_key fido2_ssh create

# --- zero or two YubiKeys
reset_state
: > "$HOME/device/list"
stderr="$(sca security_key fido2_ssh create 2>&1 >/dev/null)"
assert_eq 1 "$?" "no YubiKey exit code"
[[ "$stderr" == *"exactly one"* ]] || fail "no YubiKey: asks for exactly one: '$stderr'"
reset_state
echo "Security Key NFC (5.4.3) [FIDO]" >> "$HOME/device/list"
stderr="$(sca security_key fido2_ssh create 2>&1 >/dev/null)"
assert_eq 1 "$?" "two YubiKeys exit code"
[[ "$stderr" == *"exactly one"* ]] || fail "two YubiKeys: asks for exactly one: '$stderr'"
keygen_called && fail "ssh-keygen ran with two YubiKeys"
assert_fails sca security_key fido2_ssh restore
# a Security Key series device has no serial, and still counts as one
reset_state
echo "Security Key NFC (5.4.3) [FIDO]" > "$HOME/device/list"
assert_succeeds sca security_key fido2_ssh create

# --- ssh-keygen failing makes sca fail
reset_state
touch "$HOME/device/keygen_fails"
assert_fails sca security_key fido2_ssh create
assert_fails sca security_key fido2_ssh restore

# --- restore writes the resident keys to ~/.ssh
reset_state
printf '%s\n' id_ed25519_sk_rk_sca id_ed25519_sk_rk_sca.pub > "$HOME/device/resident"
output="$(sca security_key fido2_ssh restore 2>&1)"
assert_eq 0 "$?" "restore exit code"
[[ "$(cat "$HOME/calls")" == *"-K"* ]] || fail "restore runs ssh-keygen -K"
assert_eq "restored key" "$(cat "$HOME/.ssh/id_ed25519_sk_rk_sca")" "restored private key"
assert_eq 600 "$(stat -c '%a' "$HOME/.ssh/id_ed25519_sk_rk_sca")" "restored private key mode"
assert_file_exists "$HOME/.ssh/id_ed25519_sk_rk_sca.pub" "restored public key"
[[ "$output" == *"restored: $HOME/.ssh/id_ed25519_sk_rk_sca.pub"* ]] || fail "restore lists the files: '$output'"
assert_eq "" "$(find "$HOME/.ssh" -name '.sca-fido2-restore.*')" "no temporary folder left"

# --- restore keeps a file that exists, restores the other, and fails
reset_state
printf '%s\n' id_ed25519_sk_rk_sca id_ed25519_sk_rk_sca.pub > "$HOME/device/resident"
mkdir -p "$HOME/.ssh"
echo "keep me" > "$HOME/.ssh/id_ed25519_sk_rk_sca"
output="$(sca security_key fido2_ssh restore 2>&1)"
assert_eq 1 "$?" "restore with an existing file exit code"
assert_eq "keep me" "$(cat "$HOME/.ssh/id_ed25519_sk_rk_sca")" "the existing file is unchanged"
assert_eq "restored key" "$(cat "$HOME/.ssh/id_ed25519_sk_rk_sca.pub")" "the other file is restored"
[[ "$output" == *"kept the existing file"* ]] || fail "restore says what it kept: '$output'"
[[ "$output" == *"--output-dir"* ]] || fail "restore suggests --output-dir: '$output'"
assert_eq "" "$(find "$HOME/.ssh" -name '.sca-fido2-restore.*')" "no temporary folder left"

# --- restore into a new --output-dir, and with no resident keys
reset_state
printf '%s\n' id_ecdsa_sk_rk id_ecdsa_sk_rk.pub > "$HOME/device/resident"
assert_succeeds sca security_key fido2_ssh restore --output-dir "$HOME/out/new dir"
assert_file_exists "$HOME/out/new dir/id_ecdsa_sk_rk" "restore to --output-dir"
reset_state
output="$(sca security_key fido2_ssh restore 2>&1)"
assert_eq 0 "$?" "restore with no resident keys exit code"
[[ "$output" == *"no resident keys"* ]] || fail "restore says there are none: '$output'"

# --- the mode: missing, unknown, and help at both levels
reset_state
for mode in '' bogus; do
  stderr="$(sca security_key fido2_ssh $mode 2>&1 >/dev/null)"
  assert_eq 1 "$?" "mode '$mode' exit code"
  [[ "$stderr" == *"'create' and 'restore'"* ]] || fail "mode '$mode': lists the modes: '$stderr'"
done
for help in "--help" "create --help" "restore -h"; do
  # shellcheck disable=SC2086
  output="$(sca security_key fido2_ssh $help 2>&1)"
  [[ "$output" == *"fido2_ssh create"* ]] || fail "'fido2_ssh $help' prints the help"
done
keygen_called && fail "ssh-keygen ran for a help or mode error"

test_done
