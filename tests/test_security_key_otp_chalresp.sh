#!/bin/bash
# security_key otp_chalresp: setup writes a new secret file (mode 600, never
# over an existing one) and programs it into slot 2, backup programs the same
# secret into another key, test prints the response to a fixed challenge. an
# occupied slot is kept without -f, the secret reaches ykman on stdin only --
# never an argv, the log or the output -- and no mode needs the sca config.
#
# a ykman shim first on PATH (a real file, so calls from subshells and
# pipelines are caught) records every argv in $HOME/calls and the stdin of
# every otp chalresp call in $HOME/stdin. it reports what is in $HOME/device.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# next to the built sca rather than in TMPDIR, which may be mounted noexec
shim_dir="$(mktemp -d "$(dirname "${SCA}")/test-ykman.XXXXXX")" || exit 2
test_cleanup+=("${shim_dir}")
cat > "${shim_dir}/ykman" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/calls"
dev="$HOME/device"
[ "$1" = --device ] && shift 2
case "$1 $2" in
  "list --serials" )
    cat "$dev/serials" 2>/dev/null
    ;;
  "otp info" )
    echo "Slot 1: programmed"
    echo "Slot 2: $(cat "$dev/slot2")"
    ;;
  "otp chalresp" )
    cat >> "$HOME/stdin"
    if [ -f "$dev/chalresp_fails" ]; then
      echo "Error: Failed to write to the YubiKey." >&2
      exit 1
    fi
    echo programmed > "$dev/slot2"
    echo "challenge-response credential stored in slot 2."
    ;;
  "otp calculate" )
    [ -f "$dev/calculate_fails" ] && { echo "Error: timed out" >&2; exit 1; }
    echo 0123456789abcdef0123456789abcdef01234567
    ;;
  * ) exit 2 ;;
esac
EOF
chmod +x "${shim_dir}/ykman"
PATH="${shim_dir}:${PATH}"
# if bash skipped the shim (noexec mount), every check below would pass unseen
if [ "$(command -v ykman)" != "${shim_dir}/ykman" ]; then
  echo "error: can't run the ykman shim in ${shim_dir} (noexec?)" >&2
  exit 2
fi

serial=12345678
default_file="$HOME/.sca/private/yubikey-${serial}-chalresp.txt"

# one key, slot 2 empty, no secret files
reset_state() {
  rm -rf "$HOME/device" "$HOME/calls" "$HOME/stdin" "$HOME/.sca/private" "$HOME/out" "$HOME/.sca/log"
  mkdir -p "$HOME/device" "$HOME/out"
  : > "$HOME/calls"
  : > "$HOME/stdin"
  echo "$serial" > "$HOME/device/serials"
  echo empty > "$HOME/device/slot2"
}

chalresp_calls() {
  grep -c ' otp chalresp ' "$HOME/calls"
}

# assert_not_leaked SECRET WHAT OUTPUT - the secret is in no argv, no output and
# not in the log
assert_not_leaked() {
  local secret=$1 what=$2 output=$3
  ! grep -qiF -- "$secret" "$HOME/calls" || fail "$what: the secret is on a ykman command line"
  [[ "${output,,}" != *"$secret"* ]] || fail "$what: the secret is in the output"
  ! grep -qiF -- "$secret" "$HOME/.sca/log" 2>/dev/null || fail "$what: the secret is in ~/.sca/log"
}

mode_of() {
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

config_file="$HOME/.sca/config/sca.config"
[ ! -e "$config_file" ] || fail "the test starts with a sca config"

# --- -h works without config
output="$(sca security_key otp_chalresp -h 2>&1)" || fail "otp_chalresp -h fails without config: $output"
[[ "$output" == *"otp_chalresp setup"* ]] || fail "otp_chalresp -h prints no syntax: $output"
output="$(sca security_key otp_chalresp bogus 2>&1)" && fail "an unknown mode exits 0"
[[ "$output" == *"'setup', 'backup' and 'test'"* ]] || fail "an unknown mode does not list the modes: $output"
output="$(sca security_key otp_chalresp test extra 2>&1)" && fail "test with an extra argument exits 0"

# --- setup with -d: file written 600 in a 700 folder, secret delivered on
# stdin only, slot programmed once, no -g, no -t, every call with --device
reset_state
output="$(sca -d security_key otp_chalresp setup 2>&1)"
assert_eq 0 "$?" "setup exit code"
assert_file_exists "$default_file" "setup writes the default secret file"
secret="$(cat "$default_file")"
[[ "$secret" =~ ^[0-9a-f]{40}$ ]] || fail "the secret file does not hold 40 lowercase hex characters: '$secret'"
assert_eq "$(printf '%s\nx' "$secret")" "$(cat "$default_file"; printf x)" "secret file is the hex and one newline"
assert_eq 600 "$(mode_of "$default_file")" "mode of the secret file"
assert_eq 700 "$(mode_of "$HOME/.sca/private")" "mode of ~/.sca/private"
[ -s "$HOME/.sca/log" ] || fail "sca -d wrote no log, so the log check proves nothing"
assert_not_leaked "$secret" "setup -d" "$output"
grep -qxF -- "$secret" "$HOME/stdin" || fail "the secret did not reach ykman on stdin"
assert_eq "$(printf '%s\ny' "$secret")" "$(cat "$HOME/stdin")" "ykman's stdin: the key, then y for its confirmation"
assert_eq 1 "$(chalresp_calls)" "otp chalresp calls"
grep -qx -- "--device $serial otp chalresp 2" "$HOME/calls" || fail "chalresp argv: $(grep chalresp "$HOME/calls")"
! grep -q -- ' -g\| --generate' "$HOME/calls" || fail "ykman -g is used, which prints the key"
assert_eq 0 "$(grep -vc -- "^--device $serial \|^list --serials$" "$HOME/calls")" "ykman calls without --device $serial"
[[ "$output" == *"$serial"* ]] || fail "setup does not print the serial: $output"
[[ "$output" == *"$default_file"* ]] || fail "setup does not print the secret file: $output"
[[ "$output" == *"no touch is required"* ]] || fail "setup does not say no touch is required: $output"
[[ "$output" == *"otp_chalresp backup --device"* ]] || fail "setup does not print the backup step: $output"
[ ! -e "$config_file" ] || fail "setup creates a sca config"
leftovers=("$HOME"/.sca/private/.sca-otp-chalresp.*)
[ -e "${leftovers[0]}" ] && fail "setup leaves a temporary file behind: ${leftovers[*]}"

# --- a second setup never overwrites the file, with or without -f
before="$(cat "$default_file")"
echo empty > "$HOME/device/slot2"
output="$(sca security_key otp_chalresp setup 2>&1)" && fail "a second setup exits 0"
[[ "$output" == *"never overwritten"* ]] || fail "a second setup does not say why: $output"
output="$(sca security_key otp_chalresp setup -f 2>&1)" && fail "a second setup -f exits 0"
assert_eq "$before" "$(cat "$default_file")" "secret file after the second setups"
assert_eq 1 "$(chalresp_calls)" "otp chalresp calls after the refused setups"

# --- an occupied slot 2 is kept without -f, and replaced with it
reset_state
echo programmed > "$HOME/device/slot2"
output="$(sca security_key otp_chalresp setup 2>&1)" && fail "setup on a programmed slot exits 0"
[[ "$output" == *"already programmed"* && "$output" == *"-f"* ]] || fail "setup on a programmed slot does not say so: $output"
assert_eq 0 "$(chalresp_calls)" "otp chalresp calls on a programmed slot"
[ ! -e "$default_file" ] || fail "setup on a programmed slot writes the secret file"
output="$(sca security_key otp_chalresp setup -f 2>&1)" || fail "setup -f on a programmed slot fails: $output"
assert_eq 1 "$(chalresp_calls)" "otp chalresp calls with -f"
assert_file_exists "$default_file" "setup -f writes the secret file"

# --- --touch adds -t, a custom --secret-file is used and its folder kept
reset_state
mkdir -m 755 "$HOME/out/keys"
custom="$HOME/out/keys/chalresp.hex"
output="$(sca security_key otp_chalresp setup --touch --secret-file "$custom" 2>&1)" || fail "setup --touch fails: $output"
grep -qx -- "--device $serial otp chalresp -t 2" "$HOME/calls" || fail "--touch argv: $(grep chalresp "$HOME/calls")"
[[ "$output" == *"a touch is required"* ]] || fail "setup --touch does not say a touch is required: $output"
[[ "$output" == *"--touch"* ]] || fail "setup --touch does not pass --touch on to the backup step: $output"
assert_file_exists "$custom" "setup --secret-file"
assert_eq 600 "$(mode_of "$custom")" "mode of a custom secret file"
assert_eq 755 "$(mode_of "$HOME/out/keys")" "mode of a custom secret file's folder"
[ ! -e "$HOME/.sca/private" ] || fail "setup --secret-file creates ~/.sca/private"
output="$(sca security_key otp_chalresp setup --secret-file "$HOME/no/such/dir/f" 2>&1)" && fail "setup into a missing folder exits 0"

# --- a failing otp chalresp removes the file it just wrote
reset_state
touch "$HOME/device/chalresp_fails"
output="$(sca security_key otp_chalresp setup 2>&1)" && fail "setup exits 0 when programming fails"
[ ! -e "$default_file" ] || fail "setup keeps the secret file of a failed programming"
[[ "$output" == *"Failed to write"* ]] || fail "setup does not show ykman's error: $output"
[[ "$output" == *"was removed"* ]] || fail "setup does not say the file was removed: $output"

# --- backup: required, missing, malformed and valid secret files
reset_state
output="$(sca security_key otp_chalresp backup 2>&1)" && fail "backup without --secret-file exits 0"
[[ "$output" == *"--secret-file FILE is required"* ]] || fail "backup without --secret-file: $output"
output="$(sca security_key otp_chalresp backup --secret-file "$HOME/out/missing" 2>&1)" && fail "backup with a missing file exits 0"
[[ "$output" == *"not a readable file"* ]] || fail "backup with a missing file: $output"
bad=0123456789abcdef0123456789abcdef0123456z
(umask 077; echo "$bad" > "$HOME/out/bad")
output="$(sca security_key otp_chalresp backup --secret-file "$HOME/out/bad" 2>&1)" && fail "backup with a malformed file exits 0"
[[ "$output" == *"40 hex characters"* ]] || fail "backup with a malformed file: $output"
[[ "$output" != *"$bad"* ]] || fail "backup quotes a malformed file's content: $output"
assert_eq 0 "$(chalresp_calls)" "otp chalresp calls with bad secret files"
good=89ABCDEF0123456789abcdef0123456789abcdef
(umask 077; printf '  %s\n\n' "$good" > "$HOME/out/good")
cp -p "$HOME/out/good" "$HOME/out/good.orig"
output="$(sca -d security_key otp_chalresp backup --secret-file "$HOME/out/good" 2>&1)"
assert_eq 0 "$?" "backup exit code"
assert_eq "$(printf '%s\ny' "${good,,}")" "$(cat "$HOME/stdin")" "backup's ykman stdin"
assert_not_leaked "${good,,}" "backup -d" "$output"
grep -qx -- "--device $serial otp chalresp 2" "$HOME/calls" || fail "backup argv: $(grep chalresp "$HOME/calls")"
cmp -s "$HOME/out/good" "$HOME/out/good.orig" || fail "backup changes the secret file"
[[ "$output" != *"warning"* ]] || fail "backup warns about a mode 600 file: $output"
# the same slot rule, --touch, and a warning for a readable file
output="$(sca security_key otp_chalresp backup --secret-file "$HOME/out/good" 2>&1)" && fail "backup on a programmed slot exits 0"
assert_eq 1 "$(chalresp_calls)" "otp chalresp calls after backup on a programmed slot"
chmod 644 "$HOME/out/good"
output="$(sca security_key otp_chalresp backup -f --touch --secret-file "$HOME/out/good" 2>&1)" || fail "backup -f --touch fails: $output"
grep -qx -- "--device $serial otp chalresp -t 2" "$HOME/calls" || fail "backup --touch argv: $(grep chalresp "$HOME/calls")"
[[ "$output" == *"warning"*"other users"* ]] || fail "backup does not warn about a readable file: $output"
assert_file_exists "$HOME/out/good" "backup keeps the secret file"

# --- test: prints the response, refuses an empty slot, reports a failure
reset_state
output="$(sca security_key otp_chalresp test 2>&1)" && fail "test on an empty slot exits 0"
[[ "$output" == *"is empty"* ]] || fail "test on an empty slot: $output"
echo programmed > "$HOME/device/slot2"
output="$(sca security_key otp_chalresp test 2>&1)" || fail "test fails: $output"
[[ "$output" == *"0123456789abcdef0123456789abcdef01234567"* ]] || fail "test does not print the response: $output"
[[ "$output" == *"$serial"* ]] || fail "test does not print the serial: $output"
grep -qE -- "^--device $serial otp calculate 2 [0-9a-f]+$" "$HOME/calls" || fail "calculate argv: $(grep calculate "$HOME/calls")"
touch "$HOME/device/calculate_fails"
output="$(sca security_key otp_chalresp test 2>&1)" && fail "test exits 0 when calculate fails"
[[ "$output" == *"touch"* ]] || fail "a failing test gives no hint: $output"

# --- device selection
reset_state
printf '%s\n' "$serial" 87654321 > "$HOME/device/serials"
output="$(sca security_key otp_chalresp setup 2>&1)" && fail "setup with two keys and no --device exits 0"
[[ "$output" == *"more than one security key is attached (serials: $serial, 87654321)"* ]] \
  || fail "two keys and no --device: $output"
output="$(sca security_key otp_chalresp test --device 11112222 2>&1)" && fail "an unknown --device exits 0"
[[ "$output" == *"no security key with serial '11112222' is attached"* ]] || fail "unknown --device: $output"
output="$(sca security_key otp_chalresp setup --device 87654321 2>&1)" || fail "setup --device fails: $output"
assert_file_exists "$HOME/.sca/private/yubikey-87654321-chalresp.txt" "setup --device names the file after that key"
assert_eq 0 "$(grep -vc -- '^--device 87654321 \|^list --serials$' "$HOME/calls")" "ykman calls without --device 87654321"
: > "$HOME/device/serials"
output="$(sca security_key otp_chalresp test 2>&1)" && fail "test with no key exits 0"
[[ "$output" == *"no YubiKey attached"* ]] || fail "no key: $output"

# --- ykman missing: point to sca install
reset_state
no_ykman="$(mktemp -d "$(dirname "${SCA}")/test-noykman.XXXXXX")" || exit 2
test_cleanup+=("${no_ykman}")
for tool in bash getopt openssl awk sed grep mktemp mv rm cat dirname find wc date tr id; do
  p="$(PATH="${PATH#"${shim_dir}:"}" command -v "$tool")" && ln -s "$p" "${no_ykman}/$tool"
done
for mode in setup "backup --secret-file $HOME/out/x" test; do
  # shellcheck disable=SC2086 # the mode's words are split on purpose
  output="$(PATH="${no_ykman}" bash "${SCA}" security_key otp_chalresp $mode 2>&1)" && fail "$mode without ykman exits 0"
  [[ "$output" == *"ykman not found"*"sca install --yubikey-support"* ]] || fail "$mode without ykman: $output"
done

[ ! -e "$config_file" ] || fail "otp_chalresp created a sca config"
test_done
