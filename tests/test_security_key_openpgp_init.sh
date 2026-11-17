#!/bin/bash
# security_key openpgp_init: on a card with the default PINs it sets the retry
# counters first, then the user PIN, the reset code and the admin PIN last; a
# card already set up is refused unless --roll; it acts only on the selected
# key; every bad input is refused before the card is touched; and no PIN but
# the factory default admin PIN (for ykman) reaches a command line, the log or
# the output.
#
# gpg, gpgconf, gpg-connect-agent and ykman are executable shims first on PATH,
# not exported functions, so that their argv is what ps would show. each one
# logs its argv to $HOME/device/argv.log, and the gpg shim logs the lines it
# reads on stdin to $HOME/device/stdin.log. the cards are folders
# $HOME/device/<serial> holding their PINs and retry counters, and
# $HOME/device/current names gpg's current card.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# next to the built sca rather than in TMPDIR, which may be mounted noexec
shim_dir="$(mktemp -d "$(dirname "${SCA}")/test-openpgp-init.XXXXXX")" || exit 2
test_cleanup+=("${shim_dir}")

cat > "${shim_dir}/gpg" <<'EOF'
#!/bin/bash
# --card-status prints gpg's current card. --change-pin runs the passwd menu
# as gpg does under --pinentry-mode loopback --command-fd 0: a menu choice, then
# the admin PIN, the new value and its repetition (only once with
# SHIM_ASK_ONCE), until q. any other input is recorded in
# $HOME/device/unexpected.
D="$HOME/device"
printf '%s\n' "$(printf '%q ' gpg "$@")" >> "$D/argv.log"
cur=$(cat "$D/current")
C="$D/$cur"
case " $* " in
  *" --card-status "* )
    : > "$D/scdaemon_running"
    read -r u r a < "$C/retries"
    printf 'Reader:Yubico YubiKey OTP FIDO CCID 00 00:AID:D2760001240103040006%08d0000:openpgp-card\n' "$cur"
    printf 'version:0304\nvendor:0006:Yubico:\nserial:%08d:\npinretries:%s:%s:%s:\n' "$cur" "$u" "$r" "$a"
    ;;
  *" --change-pin "* )
    : > "$D/scdaemon_running"
    if [[ " $* " != *" --pinentry-mode loopback "* || " $* " != *" --command-fd 0 "* ]]; then
      echo "change-pin without loopback and --command-fd 0: $*" >> "$D/unexpected"
      exit 2
    fi
    fd=2
    args=("$@")
    for i in "${!args[@]}"; do
      [ "${args[$i]}" = --status-fd ] && fd=${args[$((i+1))]}
    done
    say() { echo "[GNUPG:] $*" >&"$fd"; }
    next() {
      IFS= read -r line || { echo "end of input at a prompt" >> "$D/unexpected"; exit 2; }
      printf '%s\n' "$line" >> "$D/stdin.log"
    }
    while true; do
      next
      case "$line" in
        q ) exit 0 ;;
        2 | 3 | 4 )
          menu=$line
          next; admin=$line
          next; new1=$line
          if [ -n "${SHIM_ASK_ONCE:-}" ]; then new2=$new1; else next; new2=$line; fi
          read -r u r a < "$C/retries"
          if [ "$admin" != "$(cat "$C/admin_pin")" ]; then
            echo "$u $r $((a - 1))" > "$C/retries"
            echo "gpg: error setting the PIN: Bad PIN" >&2
            say SC_OP_FAILURE 2
            continue
          fi
          echo "$u $r $(cat "$C/max")" > "$C/retries"
          if [ "$new1" != "$new2" ]; then say SC_OP_FAILURE; continue; fi
          case $menu in
            2 ) printf '%s' "$new1" > "$C/user_pin"; echo "$cur user" >> "$D/order" ;;
            3 ) printf '%s' "$new1" > "$C/admin_pin"; echo "$cur admin" >> "$D/order" ;;
            4 ) printf '%s' "$new1" > "$C/reset_code"; echo "$cur reset" >> "$D/order" ;;
          esac
          say SC_OP_SUCCESS
          ;;
        * )
          # gpg asks again for an answer longer than one character
          [ ${#line} -gt 1 ] && continue
          echo "menu answer '$line'" >> "$D/unexpected"
          ;;
      esac
    done
    ;;
  * ) exit 2 ;;
esac
EOF

cat > "${shim_dir}/ykman" <<'EOF'
#!/bin/bash
# list --serials prints $HOME/device/serials. set-retries fails while scdaemon
# holds the card, and with a wrong admin PIN costs an admin PIN try.
D="$HOME/device"
printf '%s\n' "$(printf '%q ' ykman "$@")" >> "$D/argv.log"
if [ "$*" = "list --serials" ]; then
  cat "$D/serials"
  exit 0
fi
if [ "$1" = --device ] && [ "$3 $4 $5" = "openpgp access set-retries" ] && \
    [ "$9" = --admin-pin ] && [ "${11}" = --force ]; then
  C="$D/$2"
  [ -d "$C" ] || { echo "Error: device $2 not found" >&2; exit 1; }
  [ -f "$D/scdaemon_running" ] && { echo "Error: Failed to connect to YubiKey." >&2; exit 1; }
  read -r u r a < "$C/retries"
  if [ "${10}" != "$(cat "$C/admin_pin")" ]; then
    echo "$u $r $((a - 1))" > "$C/retries"
    echo "Error: Wrong PIN." >&2
    exit 1
  fi
  echo "$6 $7 $8" > "$C/retries"
  echo "$8" > "$C/max"
  echo "$2 retries $6 $7 $8" >> "$D/order"
  exit 0
fi
echo "Error: unexpected ykman call" >&2
exit 2
EOF

cat > "${shim_dir}/gpgconf" <<'EOF'
#!/bin/bash
D="$HOME/device"
printf '%s\n' "$(printf '%q ' gpgconf "$@")" >> "$D/argv.log"
[ "$*" = "--kill scdaemon" ] && rm -f "$D/scdaemon_running"
exit 0
EOF

cat > "${shim_dir}/gpg-connect-agent" <<'EOF'
#!/bin/bash
# SCD SWITCHCARD and SCD SERIALNO --demand make the card with the serial in the
# AID current, unless SHIM_NO_SWITCH is set
D="$HOME/device"
printf '%s\n' "$(printf '%q ' gpg-connect-agent "$@")" >> "$D/argv.log"
[ -n "${SHIM_NO_SWITCH:-}" ] && exit 0
for arg in "$@"; do
  case "$arg" in
    "SCD SWITCHCARD "* ) aid=${arg#SCD SWITCHCARD } ;;
    "SCD SERIALNO --demand="* ) aid=${arg#SCD SERIALNO --demand=} ;;
    * ) continue ;;
  esac
  serial=$((10#${aid:20:8}))
  [ -d "$D/$serial" ] && echo "$serial" > "$D/current"
done
exit 0
EOF
chmod +x "${shim_dir}"/*

PATH="${shim_dir}:${PATH}"
# if bash skipped the shims (noexec mount), every check below would pass unseen
if [ "$(command -v gpg)" != "${shim_dir}/gpg" ]; then
  echo "error: can't run the gpg shim in ${shim_dir} (noexec?)" >&2
  exit 2
fi

D="$HOME/device"
serial=38263298
other=11111111

# a card with the factory defaults: user PIN 123456, admin PIN 12345678, no
# reset code, 3 tries each
new_card() {
  mkdir -p "$D/$1"
  printf '%s' 123456 > "$D/$1/user_pin"
  printf '%s' 12345678 > "$D/$1/admin_pin"
  : > "$D/$1/reset_code"
  echo "3 0 3" > "$D/$1/retries"
  echo 3 > "$D/$1/max"
}

# one key attached, with the factory defaults, and the PIN files
reset_state() {
  rm -rf "$D" "$HOME/pins" "$HOME/.sca"
  mkdir -p "$D" "$HOME/pins" "$HOME/.sca"
  new_card $serial
  echo $serial > "$D/serials"
  echo $serial > "$D/current"
  : > "$D/argv.log"
  : > "$D/order"
  printf '%s\n' "$user_pin" > "$HOME/pins/user"
  printf '%s\n' "$admin_pin" > "$HOME/pins/admin"
  printf '%s\n' "$reset_code" > "$HOME/pins/reset"
  unset SHIM_NO_SWITCH SHIM_ASK_ONCE
}

user_pin="user-pin-4711"
admin_pin="admin-pin-0815"
reset_code="reset-code-42"
pin_args=(--user-pin-file "$HOME/pins/user" --admin-pin-file "$HOME/pins/admin")

card() {
  cat "$D/${2:-$serial}/$1"
}

# assert_untouched WHAT - no card was changed, and no PIN was sent
assert_untouched() {
  assert_eq "" "$(cat "$D/order")" "$1: card changes"
  [ -s "$D/stdin.log" ] && fail "$1: PINs were sent to gpg: $(cat "$D/stdin.log")"
  assert_eq 12345678 "$(card admin_pin)" "$1: admin PIN"
  assert_eq 123456 "$(card user_pin)" "$1: user PIN"
}

assert_no_unexpected() {
  [ -s "$D/unexpected" ] && fail "$1: unexpected input to gpg: $(cat "$D/unexpected")"
}

config_file="$HOME/.sca/config/sca.config"

# --- -h works without config
output="$(sca security_key openpgp_init -h 2>&1)" || fail "openpgp_init -h fails: $output"
[[ "$output" == *"--user-pin-file FILE"* ]] || fail "openpgp_init -h prints no options: $output"

# --- a card with the default PINs: retries first, then user PIN, reset code,
# admin PIN
reset_state
output="$(sca security_key openpgp_init --retries 5 "${pin_args[@]}" \
  --reset-code-file "$HOME/pins/reset" 2>&1)"
assert_eq 0 "$?" "default card exit code: $output"
assert_eq "$serial retries 5 5 5
$serial user
$serial reset
$serial admin" "$(cat "$D/order")" "order of the changes"
assert_eq "$user_pin" "$(card user_pin)" "new user PIN"
assert_eq "$admin_pin" "$(card admin_pin)" "new admin PIN"
assert_eq "$reset_code" "$(card reset_code)" "new reset code"
[[ "$output" == *"PIN retry counters (user PIN, reset code, admin PIN): 5 5 5"* ]] || \
  fail "the counters are not printed: $output"
[[ "$output" == *"write the admin PIN and the reset code down"* ]] || \
  fail "no reminder to write the PINs down: $output"
assert_no_unexpected "default card"
[ ! -e "$config_file" ] || fail "openpgp_init creates a sca config"
# scdaemon was stopped before ykman, and before every PIN change
grep -B1 '^ykman --device' "$D/argv.log" | head -1 | grep -q '^gpgconf --kill scdaemon' || \
  fail "scdaemon is not stopped right before ykman: $(cat "$D/argv.log")"
assert_eq 3 "$(grep -c -- '--change-pin' "$D/argv.log")" "one gpg call per change"

# --- without --retries the counters are set to 5; no reset code without asking
reset_state
sca security_key openpgp_init "${pin_args[@]}" >/dev/null 2>&1 || fail "default card without --retries"
assert_eq "$serial retries 5 5 5
$serial user
$serial admin" "$(cat "$D/order")" "order without --retries and reset code"
assert_eq "" "$(card reset_code)" "a reset code is set without asking"

# --- a second run without --roll is refused and changes nothing
: > "$D/argv.log"
output="$(sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "second run without --roll exits 0"
[[ "$output" == *"not the factory default"*"nothing was changed"*"--roll"* ]] || \
  fail "second run message: $output"
assert_eq "$user_pin" "$(card user_pin)" "user PIN after the refused run"
assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN after the refused run"
assert_eq "5 5 4" "$(card retries)" "the refused run spends one admin PIN try"
[[ "$output" == *"4 left"* ]] || fail "the refused run does not say how many tries are left: $output"
grep -q -- '--change-pin' "$D/argv.log" && \
  fail "the refused run still calls gpg --change-pin"

# --- --roll with the right current admin PIN changes the PINs, and no retries
printf '%s\n' "$admin_pin" > "$HOME/pins/current"
printf '%s\n' "rolled-user-1" > "$HOME/pins/user2"
printf '%s\n' "rolled-admin-1" > "$HOME/pins/admin2"
: > "$D/order"
output="$(sca security_key openpgp_init --roll --current-admin-pin-file "$HOME/pins/current" \
  --user-pin-file "$HOME/pins/user2" --admin-pin-file "$HOME/pins/admin2" 2>&1)"
assert_eq 0 "$?" "--roll exit code: $output"
assert_eq "$serial user
$serial admin" "$(cat "$D/order")" "--roll changes"
assert_eq rolled-user-1 "$(card user_pin)" "user PIN after --roll"
assert_eq rolled-admin-1 "$(card admin_pin)" "admin PIN after --roll"

# --- --roll with a wrong current admin PIN: nothing changed, the tries left said
: > "$D/order"
printf '%s\n' "wrong-admin-pin" > "$HOME/pins/current"
output="$(sca security_key openpgp_init --roll --current-admin-pin-file "$HOME/pins/current" \
  "${pin_args[@]}" 2>&1)" && fail "--roll with a wrong admin PIN exits 0"
[[ "$output" == *"rejected the current admin PIN"*"nothing was changed"*"4 admin PIN tries left"* ]] || \
  fail "--roll with a wrong admin PIN message: $output"
assert_eq "" "$(cat "$D/order")" "--roll with a wrong admin PIN changes"

# --- --roll --retries is refused before any call
reset_state
output="$(sca security_key openpgp_init --roll --retries 5 "${pin_args[@]}" 2>&1)" && \
  fail "--roll --retries exits 0"
[[ "$output" == *"ykman openpgp access set-retries"* ]] || fail "--roll --retries message: $output"
assert_eq "" "$(cat "$D/argv.log")" "--roll --retries calls"

# --- bad option values are refused before any call
for bad in 0 100 abc -1 ''; do
  reset_state
  assert_fails sca security_key openpgp_init --retries "$bad" "${pin_args[@]}"
  assert_eq "" "$(cat "$D/argv.log")" "--retries '$bad' calls"
done
reset_state
assert_fails sca security_key openpgp_init --current-admin-pin-file "$HOME/pins/admin" "${pin_args[@]}"
assert_fails sca security_key openpgp_init extra "${pin_args[@]}"
assert_fails sca security_key openpgp_init --no-such-option
assert_eq "" "$(cat "$D/argv.log")" "bad options calls"
# getopt takes --user-pin for --user-pin-file: the value is a file name, never
# a PIN
assert_fails sca security_key openpgp_init --user-pin "$user_pin" --admin-pin-file "$HOME/pins/admin"
assert_untouched "--user-pin VALUE"

# --- the admin PIN counter at 1: nothing tried
reset_state
echo "3 0 1" > "$D/$serial/retries"
output="$(sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "admin counter 1 exits 0"
[[ "$output" == *"retry counter is 1"*"nothing was changed"* ]] || fail "admin counter 1 message: $output"
grep -q '^ykman --device' "$D/argv.log" && fail "admin counter 1 still runs set-retries"
assert_untouched "admin counter 1"
assert_eq "3 0 1" "$(card retries)" "admin counter 1: counters"

# --- bad PINs are refused before the card is touched
check_refused() {
  local what="$1" expected="$2"
  shift 2
  local output
  output="$(sca security_key openpgp_init "$@" 2>&1)" && fail "$what exits 0"
  [[ "$output" == *"$expected"*"nothing was changed"* ]] || fail "$what message: $output"
  grep -qv '^ykman list --serials' "$D/argv.log" && fail "$what touches the card: $(cat "$D/argv.log")"
  assert_untouched "$what"
}
reset_state
printf '%s\n' 12345 > "$HOME/pins/short"
check_refused "user PIN too short" "6 to 127" --user-pin-file "$HOME/pins/short" --admin-pin-file "$HOME/pins/admin"
printf '%s\n' 1234567 > "$HOME/pins/short"
check_refused "admin PIN too short" "8 to 127" --user-pin-file "$HOME/pins/user" --admin-pin-file "$HOME/pins/short"
check_refused "reset code too short" "8 to 127" "${pin_args[@]}" --reset-code-file "$HOME/pins/short"
printf '%0128d\n' 0 > "$HOME/pins/long"
check_refused "admin PIN too long" "8 to 127" --user-pin-file "$HOME/pins/user" --admin-pin-file "$HOME/pins/long"
printf 'line-one-1\nline-two-2\n' > "$HOME/pins/twolines"
check_refused "a two-line PIN" "single line" --user-pin-file "$HOME/pins/twolines" --admin-pin-file "$HOME/pins/admin"
check_refused "a missing PIN file" "can't read" --user-pin-file "$HOME/pins/none" --admin-pin-file "$HOME/pins/admin"
check_refused "a folder as PIN file" "can't read" --user-pin-file "$HOME/pins" --admin-pin-file "$HOME/pins/admin"
check_refused "the user PIN is the admin PIN" "are the same" --user-pin-file "$HOME/pins/admin" --admin-pin-file "$HOME/pins/admin"
printf '%s\n' 12345678 > "$HOME/pins/default_admin"
check_refused "the new admin PIN is the old one" "same as the current one" --user-pin-file "$HOME/pins/user" --admin-pin-file "$HOME/pins/default_admin"
printf '%s\n' 123456 > "$HOME/pins/default_user"
check_refused "the new user PIN is the default" "factory default" --user-pin-file "$HOME/pins/default_user" --admin-pin-file "$HOME/pins/admin"
printf '%s\n' short > "$HOME/pins/current"
check_refused "a short current admin PIN" "8 to 127" --roll --current-admin-pin-file "$HOME/pins/current" "${pin_args[@]}"
# no file and no terminal: an error, not a hang
check_refused "no PIN file and no terminal" "stdin is not a terminal" --admin-pin-file "$HOME/pins/admin" < /dev/null
check_refused "--reset-code with no file and no terminal" "stdin is not a terminal" --reset-code "${pin_args[@]}" < /dev/null

# --- process substitution and a file without a trailing newline work; only
# one newline is stripped
reset_state
printf '%s' "$admin_pin" > "$HOME/pins/admin"
sca security_key openpgp_init --user-pin-file <(printf '%s\n' "$user_pin") \
  --admin-pin-file "$HOME/pins/admin" >/dev/null 2>&1 || fail "process substitution PIN file"
assert_eq "$user_pin" "$(card user_pin)" "user PIN from process substitution"
assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN without a trailing newline"

# --- at a terminal, every new PIN is asked for twice; a mismatch changes
# nothing. script(1) provides the terminal, where it is installed.
if command -v script >/dev/null 2>&1; then
  reset_state
  printf '%s\n' "$user_pin" "$user_pin" "$admin_pin" "$admin_pin" | \
    script -qec "bash '${SCA}' security_key openpgp_init" /dev/null > "$HOME/tty.out" 2>&1
  assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN typed at the terminal: $(cat "$HOME/tty.out")"
  assert_eq "$user_pin" "$(card user_pin)" "user PIN typed at the terminal"
  reset_state
  printf '%s\n' "$user_pin" "not-the-same" | \
    script -qec "bash '${SCA}' security_key openpgp_init" /dev/null > "$HOME/tty.out" 2>&1
  grep -q "don't match"  "$HOME/tty.out" || fail "a mismatch at the terminal: $(cat "$HOME/tty.out")"
  assert_untouched "a mismatch at the terminal"
fi

# --- a gpg that asks for the new PIN once: the repetition is ignored at the menu
reset_state
SHIM_ASK_ONCE=1 sca security_key openpgp_init "${pin_args[@]}" >/dev/null 2>&1 || fail "gpg asking once"
assert_eq "$user_pin" "$(card user_pin)" "user PIN, gpg asking once"
assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN, gpg asking once"
assert_no_unexpected "gpg asking once"

# --- no PIN in any argv (but 12345678 for ykman), in the -d log or the output
reset_state
output="$(sca -d security_key openpgp_init "${pin_args[@]}" --reset-code-file "$HOME/pins/reset" 2>&1)"
assert_eq 0 "$?" "-d run exit code: $output"
[ -s "$HOME/.sca/log" ] || fail "-d run wrote no log"
printf '%s\n' "rolled-user-2" > "$HOME/pins/user2"
printf '%s\n' "rolled-admin-2" > "$HOME/pins/admin2"
printf '%s\n' "$admin_pin" > "$HOME/pins/current"
roll_output="$(sca -d security_key openpgp_init --roll --current-admin-pin-file "$HOME/pins/current" \
  --user-pin-file "$HOME/pins/user2" --admin-pin-file "$HOME/pins/admin2" 2>&1)"
assert_eq 0 "$?" "-d --roll run exit code: $roll_output"
for pin in "$user_pin" "$admin_pin" "$reset_code" rolled-user-2 rolled-admin-2; do
  grep -qF -- "$pin" "$D/stdin.log" || fail "the shim never got '$pin', so the check below proves nothing"
  grep -F -- "$pin" "$D/argv.log" && fail "PIN '$pin' on a command line"
  grep -F -- "$pin" "$HOME/.sca/log" && fail "PIN '$pin' in the log"
  [[ "$output$roll_output" == *"$pin"* ]] && fail "PIN '$pin' in the output"
done
grep -F -- 12345678 "$D/argv.log" | grep -v '^ykman --device' && fail "the default admin PIN on a command line other than ykman's"
grep -qF -- 12345678 "$HOME/.sca/log" && fail "the default admin PIN in the log"

# --- two keys without --device: refused; --device must be attached
reset_state
new_card $other
printf '%s\n' $serial $other > "$D/serials"
output="$(sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "two keys without --device exits 0"
[[ "$output" == *"more than one"*"$serial, $other"*"--device"* ]] || fail "two keys message: $output"
assert_untouched "two keys without --device"
output="$(sca security_key openpgp_init --device 99999999 "${pin_args[@]}" 2>&1)" && fail "--device not attached exits 0"
[[ "$output" == *"no security key with serial '99999999'"* ]] || fail "--device not attached message: $output"
assert_untouched "--device not attached"
echo -n > "$D/serials"
output="$(sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "no key exits 0"
[[ "$output" == *"no YubiKey found"* ]] || fail "no key message: $output"

# --- gpg's current card is another key: switched to the selected one, the
# other one never touched
reset_state
new_card $other
printf '%s\n' $other $serial > "$D/serials"
echo $other > "$D/current"
output="$(sca security_key openpgp_init --device $serial "${pin_args[@]}" 2>&1)"
assert_eq 0 "$?" "switch to the selected card exit code: $output"
assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN of the selected card"
assert_eq 12345678 "$(card admin_pin $other)" "admin PIN of the other card"
assert_eq 123456 "$(card user_pin $other)" "user PIN of the other card"
grep -q "^$other" "$D/order" && fail "the other card was changed: $(cat "$D/order")"

# --- and if it can't be switched: refused, nothing changed on either
reset_state
new_card $other
printf '%s\n' $other $serial > "$D/serials"
echo $other > "$D/current"
output="$(SHIM_NO_SWITCH=1 sca security_key openpgp_init --device $serial "${pin_args[@]}" 2>&1)" && \
  fail "an unswitchable card exits 0"
[[ "$output" == *"serial '$other', not on the YubiKey $serial"*"nothing was changed"* ]] || \
  fail "unswitchable card message: $output"
assert_untouched "unswitchable card"
assert_eq "3 0 3" "$(card retries $other)" "counters of the other card"
grep -q '^ykman --device' "$D/argv.log" && fail "an unswitchable card still runs set-retries"

# --- a step that fails says what was already done
reset_state
# the gpg shim refuses an input it doesn't expect, here the reset code menu
mv "${shim_dir}/gpg" "${shim_dir}/gpg.real"
cat > "${shim_dir}/gpg" <<EOF
#!/bin/bash
if [[ " \$* " == *" --change-pin "* ]] && [ "\$(grep -c -- --change-pin "\$HOME/device/argv.log")" -ge 1 ]; then
  printf '%s\n' "\$(printf '%q ' gpg "\$@")" >> "\$HOME/device/argv.log"
  cat > /dev/null
  echo "gpg: error setting the Reset Code: Card error" >&2
  echo "[GNUPG:] SC_OP_FAILURE"
  exit 0
fi
exec "${shim_dir}/gpg.real" "\$@"
EOF
chmod +x "${shim_dir}/gpg"
output="$(sca security_key openpgp_init "${pin_args[@]}" --reset-code-file "$HOME/pins/reset" 2>&1)" && \
  fail "a failing reset code exits 0"
[[ "$output" == *"could not set the reset code (error setting the Reset Code: Card error)"* ]] || \
  fail "failing step message: $output"
[[ "$output" == *"already done: PIN retry counters set to 5; user PIN changed. the admin PIN is still the old one: rerun the same command to finish."* ]] || \
  fail "failing step does not say what was done: $output"
assert_eq 12345678 "$(card admin_pin)" "admin PIN after a failing reset code"
mv "${shim_dir}/gpg.real" "${shim_dir}/gpg"
# the rerun finishes the job
sca security_key openpgp_init "${pin_args[@]}" --reset-code-file "$HOME/pins/reset" >/dev/null 2>&1 || \
  fail "rerun after a failing step"
assert_eq "$admin_pin" "$(card admin_pin)" "admin PIN after the rerun"
assert_eq "$reset_code" "$(card reset_code)" "reset code after the rerun"

# --- a missing tool names sca install --openpgp
reset_state
noykman_path="$HOME/bin-noykman"
mkdir -p "$noykman_path"
for tool in bash cat getopt grep awk sed wc mkdir rm; do
  ln -s "$(command -v "$tool")" "$noykman_path/$tool"
done
ln -s "${shim_dir}/gpg" "$noykman_path/gpg"
ln -s "${shim_dir}/gpgconf" "$noykman_path/gpgconf"
output="$(PATH="$noykman_path" sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "openpgp_init exits 0 without ykman"
[[ "$output" == *"ykman not found"*"sca install --openpgp"* ]] || fail "missing ykman message: $output"
rm "$noykman_path/gpg"
output="$(PATH="$noykman_path" sca security_key openpgp_init "${pin_args[@]}" 2>&1)" && fail "openpgp_init exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "missing gpg message: $output"
assert_eq "" "$(cat "$D/argv.log")" "calls without the tools"

test_done
