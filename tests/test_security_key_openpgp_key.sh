#!/bin/bash
# security_key openpgp_key: create makes a [C] master key with [S], [E] and
# [A] subkeys and four mode-600 backup files it never overwrites; to_card moves
# the right subkey to the right slot of the right card, refuses filled slots,
# a missing backup, another card and old firmware, answers each secret prompt
# at most as often as gpg can legitimately ask, never saves after a failure,
# and keeps the passphrase and admin PIN out of argv, the environment and the
# log. neither mode needs the sca configuration.
#
# create runs the real gpg, in a temporary GNUPGHOME, and is skipped when gpg
# is not installed. to_card runs against gpg, ykman and gpg-connect-agent
# stubs (exported shell functions, as in test_security_key_openpgp_ssh.sh);
# the gpg stub plays the --edit-key --command-fd/--status-fd dialogue of
# GnuPG 2.2 and reads what it reports from files in $HOME/device.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

config_file="$HOME/.sca/config/sca.config"
passphrase='correct horse battery'
admin_pin='87654321'
mkdir -p "$HOME/.sca" "$HOME/secrets"
printf '%s\n' "$passphrase" > "$HOME/secrets/passphrase"
printf '%s\n' "$admin_pin" > "$HOME/secrets/admin-pin"

# the secrets must never be in an argv, an environment or the log
assert_no_secrets() {
  local file
  for file in "$HOME/calls" "$HOME/env" "$HOME/.sca/log"; do
    [ -f "$file" ] || continue
    grep -qF -- "$passphrase" "$file" && fail "$1: the passphrase is in $file"
    grep -qF -- "$admin_pin" "$file" && fail "$1: the admin PIN is in $file"
  done
}

# everything below runs with no sca configuration
[ ! -e "$config_file" ] || fail "the test starts with a sca config"

# --- -h works without config
output="$(sca security_key openpgp_key -h 2>&1)" || fail "openpgp_key -h fails without config: $output"
[[ "$output" == *"openpgp_key create"*"openpgp_key to_card"* ]] || fail "openpgp_key -h prints no syntax: $output"
sca security_key openpgp_key create -h >/dev/null 2>&1 || fail "create -h fails"
sca security_key openpgp_key to_card -h >/dev/null 2>&1 || fail "to_card -h fails"

# --- bad options and arguments are refused, before gpg runs
assert_fails sca security_key openpgp_key
assert_fails sca security_key openpgp_key frobnicate
assert_fails sca security_key openpgp_key create --no-such-option
assert_fails sca security_key openpgp_key create --name A --email a@b.c extra
assert_fails sca security_key openpgp_key to_card extra
assert_fails sca security_key openpgp_key to_card --device
for args in "--email a@example.org" "--name A" "--name A<b --email a@example.org" \
    "--name A --email not-an-email" "--name A --email a@example.org --algo dsa" \
    "--name A --email a@example.org --expire soon"; do
  # shellcheck disable=SC2086 # split into options on purpose
  output="$(sca security_key openpgp_key create $args 2>&1)" && fail "create $args exits 0"
  [[ "$output" == *"openpgp_key create"* ]] || fail "create $args: $output"
done

################################################################################
# create, with the real gpg
if ! command -v gpg >/dev/null 2>&1 || ! command -v gpgconf >/dev/null 2>&1; then
  echo "  skip: gpg is not installed, so openpgp_key create is not tested"
else
  GNUPGHOME="$(mktemp -d "${TMPDIR:-/tmp}/sca-gnupg.XXXXXX")" || exit 2
  export GNUPGHOME
  test_cleanup+=("$GNUPGHOME")
  # count_keys - the number of master keys in the keyring
  count_keys() {
    gpg --batch --list-secret-keys --with-colons 2>/dev/null | grep -c '^sec:'
  }
  output="$(sca -d security_key openpgp_key create --name "Test User" --email test@example.org \
    --algo ed25519 --expire 1y --passphrase-file "$HOME/secrets/passphrase" 2>&1)"
  assert_eq 0 "$?" "create exit code: $output"
  listing="$(gpg --batch --list-secret-keys --with-colons 2>/dev/null)"
  fpr="$(printf '%s\n' "$listing" | awk -F: '$1 == "fpr" { print $10; exit }')"
  assert_eq 1 "$(count_keys)" "number of keys after create"
  # the lower case letters are the key's own capabilities
  assert_eq "sec:c" "$(printf '%s\n' "$listing" | awk -F: '$1 == "sec" { gsub(/[A-Z]/, "", $12); print $1 ":" $12 }')" "the master key only certifies"
  assert_eq "ssb:s:ed25519 ssb:e:cv25519 ssb:a:ed25519" \
    "$(printf '%s\n' "$listing" | awk -F: '$1 == "ssb" { printf "%s%s:%s:%s", sep, $1, $12, $17; sep = " " }')" "the subkeys"
  [ -z "$(printf '%s\n' "$listing" | awk -F: '$1 == "sec" { print $7 }')" ] || fail "the master key expires"
  [ -n "$(printf '%s\n' "$listing" | awk -F: '$1 == "ssb" { print $7; exit }')" ] || fail "the subkeys do not expire"
  printf '%s\n' "$listing" | grep -q '^uid:.*Test User <test@example.org>' || fail "the user ID: $listing"
  [[ "$output" == *"created the OpenPGP key $fpr"* ]] || fail "create does not print the fingerprint: $output"
  [[ "$output" == *"passphrase"*"keep the passphrase with them"* ]] || fail "create does not say to keep the passphrase: $output"
  backup_dir="$HOME/.sca/keys/openpgp/$fpr"
  [[ "$output" == *"$backup_dir"* ]] || fail "create does not print the backup folder: $output"
  for file in master-and-subkeys.asc subkeys.asc public.asc revoke.asc; do
    assert_file_exists "$backup_dir/$file" "backup file"
    assert_eq 600 "$(stat -c %a "$backup_dir/$file" 2>/dev/null)" "mode of $file"
  done
  assert_eq 700 "$(stat -c %a "$backup_dir")" "mode of the backup folder"
  grep -q 'BEGIN PGP PRIVATE KEY BLOCK' "$backup_dir/master-and-subkeys.asc" || fail "master-and-subkeys.asc holds no secret key"
  grep -q 'BEGIN PGP PRIVATE KEY BLOCK' "$backup_dir/subkeys.asc" || fail "subkeys.asc holds no secret key"
  grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$backup_dir/public.asc" || fail "public.asc holds no public key"
  grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$backup_dir/revoke.asc" || fail "revoke.asc holds no revocation certificate"
  gpg --batch --show-keys --with-colons "$backup_dir/master-and-subkeys.asc" 2>/dev/null | grep -q "^fpr:::::::::$fpr:" \
    || fail "master-and-subkeys.asc is not a backup of $fpr"
  [ "$(find "$backup_dir" -name '.sca-openpgp-key.*' | wc -l)" = 0 ] || fail "create leaves temporary files"
  [ ! -e "$config_file" ] || fail "create creates a sca config"
  assert_no_secrets "create"

  # --backup-dir puts the files there, and a second run into it is refused
  # before any key is made
  output="$(sca security_key openpgp_key create --name "Other User" --email other@example.org \
    --backup-dir "$HOME/backup" --passphrase-file "$HOME/secrets/passphrase" 2>&1)"
  assert_eq 0 "$?" "create --backup-dir exit code: $output"
  for file in master-and-subkeys.asc subkeys.asc public.asc revoke.asc; do
    assert_eq 600 "$(stat -c %a "$HOME/backup/$file" 2>/dev/null)" "mode of --backup-dir $file"
  done
  before="$(md5sum "$HOME/backup/"*)"
  output="$(sca security_key openpgp_key create --name "Third User" --email third@example.org \
    --backup-dir "$HOME/backup" --passphrase-file "$HOME/secrets/passphrase" 2>&1)" \
    && fail "create into a folder with backups exits 0"
  [[ "$output" == *"already exists"* ]] || fail "create into a folder with backups: $output"
  assert_eq 2 "$(count_keys)" "keys after a refused create"
  assert_eq "$before" "$(md5sum "$HOME/backup/"*)" "existing backups after a refused create"
  # one existing file is enough
  mkdir -p "$HOME/backup2"
  echo keep > "$HOME/backup2/revoke.asc"
  assert_fails sca security_key openpgp_key create --name "Third User" --email third@example.org \
    --backup-dir "$HOME/backup2" --passphrase-file "$HOME/secrets/passphrase"
  assert_eq 2 "$(count_keys)" "keys after a refused create (one file)"
  assert_eq keep "$(cat "$HOME/backup2/revoke.asc")" "an existing revoke.asc"

  # bad passphrase files are refused before any key is made
  : > "$HOME/secrets/empty"
  printf 'one\ntwo\n' > "$HOME/secrets/two-lines"
  for file in "$HOME/secrets/empty" "$HOME/secrets/two-lines" "$HOME/secrets/missing"; do
    assert_fails sca security_key openpgp_key create --name "Fourth User" --email fourth@example.org \
      --backup-dir "$HOME/backup3" --passphrase-file "$file"
  done
  assert_eq 2 "$(count_keys)" "keys after bad passphrase files"
  gpgconf --kill gpg-agent 2>/dev/null
  unset GNUPGHOME
fi

################################################################################
# to_card, with stubs
master=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
other=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
sig=1111111111111111111111111111111111111111
enc=2222222222222222222222222222222222222222
aut=3333333333333333333333333333333333333333
export master other

# the subkeys are listed [A], [S], [E], so the slots are not the gpg key order
reset_state() {
  rm -rf "$HOME/device" "$HOME/calls" "$HOME/env" "$HOME/commands" "$HOME/hidden" "$HOME/.sca/keys"
  mkdir -p "$HOME/device" "$HOME/.sca/keys/openpgp/$master"
  : > "$HOME/calls"
  : > "$HOME/.sca/log"
  cat > "$HOME/device/listing" <<EOF
sec:u:255:22:AAAAAAAAAAAAAAAA:1700000000:::u:::cSEA:::+::ed25519:::0:
fpr:::::::::$master:
grp:::::::::A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0A0:
uid:u::::1700000000::HASH::Test User <test@example.org>::::::::::0:
ssb:u:255:22:3333333333333333:1700000000:1800000000:::::a:::+::ed25519::
fpr:::::::::$aut:
grp:::::::::A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3:
ssb:u:255:22:1111111111111111:1700000000:1800000000:::::s:::+::ed25519::
fpr:::::::::$sig:
grp:::::::::A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1:
ssb:u:255:18:2222222222222222:1700000000:1800000000:::::e:::+::cv25519::
fpr:::::::::$enc:
grp:::::::::A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2A2:
EOF
  cat > "$HOME/device/card_status" <<EOF
Reader:Yubico YubiKey OTP FIDO CCID 00 00:AID:D2760001240103040006123456780000:openpgp-card
version:0304
vendor:0006:Yubico:
serial:12345678:
keyattr:1:1:2048:
keyattr:2:1:2048:
keyattr:3:1:2048:
fpr::::
EOF
  echo 12345678 > "$HOME/device/serials"
  echo 5.4.3 > "$HOME/device/firmware"
  printf '%s\n' "$passphrase" > "$HOME/device/passphrase"
  printf '%s\n' "$admin_pin" > "$HOME/device/admin_pin"
  # card key attributes differ from the keys: GnuPG 2.2 asks the PIN twice
  echo 2 > "$HOME/device/pin_asks"
  echo "backup of $master" > "$HOME/.sca/keys/openpgp/$master/master-and-subkeys.asc"
}

# the edit-key dialogue. "key N" toggles subkey N, keytocard asks for the slot,
# replace_key if the slot is filled, then in loopback mode the passphrase and
# $HOME/device/pin_asks admin PINs, checking each. save marks the subkeys as
# card stubs. every command goes to $HOME/commands, every secret answer to
# $HOME/hidden.
# shellcheck disable=SC2317 # the stubs are called by sca
gpg_edit() {
  local loopback=false line selected='' moved=0 slot i
  [[ "$*" == *"--pinentry-mode loopback"* ]] && loopback=true
  st() { echo "[GNUPG:] $*"; }
  ask() { st "$1 $2"; IFS= read -r line || exit 2; st GOT_IT; }
  st "KEY_CONSIDERED $master 0"
  while true; do
    ask GET_LINE keyedit.prompt
    echo "$line" >> "$HOME/commands"
    case "$line" in
      "key "* )
        if [ "$selected" = "${line#key }" ]; then selected=''; else selected=${line#key }; fi
        ;;
      keytocard )
        [ -f "$HOME/device/no_card" ] && { st "CARDCTRL 6"; continue; }
        ask GET_LINE cardedit.genkeys.storekeytype
        slot=$line
        echo "slot $slot <- key $selected" >> "$HOME/commands"
        if [ -f "$HOME/device/filled_$slot" ]; then
          ask GET_BOOL cardedit.genkeys.replace_key
          echo "replace $line" >> "$HOME/commands"
          [ "$line" = y ] || continue
        fi
        if [ "$loopback" = true ] && [ ! -f "$HOME/device/unprotected" ]; then
          st "INQUIRE_MAXLEN 100"
          ask GET_HIDDEN passphrase.enter
          echo "passphrase:$line" >> "$HOME/hidden"
          [ "$line" = "$(cat "$HOME/device/passphrase")" ] || { st SC_OP_FAILURE; continue; }
        fi
        if [ "$loopback" = true ]; then
          for ((i = 0; i < $(cat "$HOME/device/pin_asks"); i++)); do
            st "INQUIRE_MAXLEN 100"
            ask GET_HIDDEN passphrase.enter
            echo "pin:$line" >> "$HOME/hidden"
            [ "$line" = $'\x04' ] && { st "SC_OP_FAILURE 1"; continue 2; }
            [ "$line" = "$(cat "$HOME/device/admin_pin")" ] || { st "SC_OP_FAILURE 2"; continue 2; }
          done
        fi
        moved=1
        ;;
      save )
        sed -i '/^ssb/s/:+:/:D2760001240103040006123456780000:/' "$HOME/device/listing"
        touch "$HOME/device/saved"
        return 0
        ;;
      quit )
        if [ "$moved" = 1 ]; then
          ask GET_BOOL keyedit.save.okay
          echo "save.okay $line" >> "$HOME/commands"
        fi
        return 0
        ;;
    esac
  done
}
# shellcheck disable=SC2317
gpg() {
  echo "gpg $*" >> "$HOME/calls"
  env >> "$HOME/env"
  case "$*" in
    *--card-status* )
      [ -f "$HOME/device/card_status" ] || { echo "gpg: selecting card failed: No such device" >&2; return 2; }
      cat "$HOME/device/card_status"
      ;;
    *--show-keys* )
      local file="${*: -1}"
      if grep -q "backup of $master" "$file"; then
        printf '%s\n' "sec:u:255:22:AAAAAAAAAAAAAAAA:1700000000:::u:::cSEA:::::ed25519:::0:" "fpr:::::::::$master:"
      else
        printf '%s\n' "sec:u:255:22:BBBBBBBBBBBBBBBB:1700000000:::u:::cSEA:::::ed25519:::0:" "fpr:::::::::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB:"
      fi
      ;;
    *--edit-key* )
      gpg_edit "$@"
      ;;
    *--list-secret-keys*--with-colons* )
      [[ "$*" == *"$other"* ]] && { [ -f "$HOME/device/other_key" ] && cat "$HOME/device/other_key"; return; }
      cat "$HOME/device/listing"
      [[ "$*" == *"$master"* ]] || { [ -f "$HOME/device/other_key" ] && cat "$HOME/device/other_key"; }
      return 0
      ;;
    *--list-secret-keys* )
      echo "ssb>  ed25519 2023-11-14 [S]"
      ;;
    * ) return 1 ;;
  esac
}
# shellcheck disable=SC2317
ykman() {
  echo "ykman $*" >> "$HOME/calls"
  case "$*" in
    "list --serials" ) cat "$HOME/device/serials" ;;
    *info ) echo "Firmware version: $(cat "$HOME/device/firmware")" ;;
    * ) return 1 ;;
  esac
}
# shellcheck disable=SC2317
gpg-connect-agent() {
  echo "gpg-connect-agent $*" >> "$HOME/calls"
  local grip=${1#KEYINFO }
  if [ -f "$HOME/device/unprotected" ]; then
    echo "S KEYINFO $grip D - - - C - - -"
  else
    echo "S KEYINFO $grip D - - - P - - -"
  fi
  echo OK
}
export -f gpg gpg_edit ykman gpg-connect-agent

secret_opts=(--passphrase-file "$HOME/secrets/passphrase" --admin-pin-file "$HOME/secrets/admin-pin")
moves="key 2
keytocard
slot 1 <- key 2
key 2
key 3
keytocard
slot 2 <- key 3
key 3
key 1
keytocard
slot 3 <- key 1
key 1
save"

# --- unattended: the right subkey to the right slot, then save
reset_state
output="$(sca -d security_key openpgp_key to_card --device 12345678 "${secret_opts[@]}" 2>&1)"
assert_eq 0 "$?" "to_card exit code: $output"
assert_eq "$moves" "$(cat "$HOME/commands")" "the edit-key commands"
assert_eq "passphrase:$passphrase pin:$admin_pin pin:$admin_pin passphrase:$passphrase pin:$admin_pin pin:$admin_pin passphrase:$passphrase pin:$admin_pin pin:$admin_pin" \
  "$(paste -sd' ' "$HOME/hidden")" "the secret answers"
assert_file_exists "$HOME/device/saved" "to_card does not save"
[[ "$output" == *"ssb>"* ]] || fail "to_card does not show the moved keys: $output"
[[ "$output" == *"set-touch"* ]] || fail "to_card does not point to the touch policy: $output"
grep -q -- "--pinentry-mode loopback --edit-key $master" "$HOME/calls" || fail "to_card does not use loopback mode: $(cat "$HOME/calls")"
grep -q -- "--passphrase" "$HOME/calls" && fail "to_card passes --passphrase to gpg"
grep -q "ykman --device 12345678 info" "$HOME/calls" || fail "to_card does not check the firmware"
[ ! -e "$config_file" ] || fail "to_card creates a sca config"
grep -q "answering with the admin PIN (not logged)" "$HOME/.sca/log" || fail "to_card -d logs no dialogue"
assert_no_secrets "to_card"

# --- the card already knows the PIN, and the attributes match: no second ask
reset_state
echo 1 > "$HOME/device/pin_asks"
sed -i 's/^keyattr:1:.*/keyattr:1:22:ed25519:/; s/^keyattr:2:.*/keyattr:2:18:cv25519:/; s/^keyattr:3:.*/keyattr:3:22:ed25519:/' "$HOME/device/card_status"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)"
assert_eq 0 "$?" "to_card with matching attributes: $output"
assert_eq 3 "$(grep -c '^pin:' "$HOME/hidden")" "PIN answers with matching attributes"

# --- a second admin PIN prompt the card can't need is not answered
reset_state
echo 2 > "$HOME/device/pin_asks"
sed -i 's/^keyattr:1:.*/keyattr:1:22:ed25519:/' "$HOME/device/card_status"
output="$(sca -d security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 after a second PIN prompt"
assert_eq "passphrase:$passphrase pin:$admin_pin pin:"$'\x04' "$(paste -sd' ' "$HOME/hidden")" "answers to a second PIN prompt"
[ ! -e "$HOME/device/saved" ] || fail "to_card saves after a second PIN prompt"
grep -qx quit "$HOME/commands" || fail "to_card does not quit after a second PIN prompt"
[[ "$output" == *"probably wrong"*"not saved"* ]] || fail "second PIN prompt message: $output"
assert_no_secrets "second PIN prompt"

# --- a wrong admin PIN is sent once, and nothing is saved
reset_state
echo 99999999 > "$HOME/device/admin_pin"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with a wrong PIN"
assert_eq 1 "$(grep -c '^pin:' "$HOME/hidden")" "PIN answers with a wrong PIN"
[ ! -e "$HOME/device/saved" ] || fail "to_card saves after a wrong PIN"
[[ "$output" == *"refused the admin PIN"* ]] || fail "wrong PIN message: $output"

# --- a wrong passphrase: the PIN is never sent
reset_state
echo nope > "$HOME/device/passphrase"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with a wrong passphrase"
assert_eq 0 "$(grep -c '^pin:' "$HOME/hidden")" "PIN answers with a wrong passphrase"
[ ! -e "$HOME/device/saved" ] || fail "to_card saves after a wrong passphrase"

# --- a failure in a later slot names the slots already written
reset_state
touch "$HOME/device/filled_3"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 when gpg finds slot 3 filled"
grep -qx "replace n" "$HOME/commands" || fail "to_card replaces a key without --force"
grep -qx "save.okay n" "$HOME/commands" || fail "to_card does not refuse to save on quit"
[ ! -e "$HOME/device/saved" ] || fail "to_card saves after a failed slot"
[[ "$output" == *"already written: signature key encryption key."* ]] || fail "failed slot message: $output"

# --- no secret files: pinentry asks, so no loopback and no secret answers
reset_state
output="$(sca security_key openpgp_key to_card 2>&1)"
assert_eq 0 "$?" "to_card without secret files: $output"
[ ! -e "$HOME/hidden" ] || fail "to_card without secret files answers a secret prompt"
grep -q -- "--pinentry-mode" "$HOME/calls" && fail "to_card without secret files uses loopback mode"
grep -q "gpg-connect-agent" "$HOME/calls" && fail "to_card without secret files asks gpg-agent"
assert_file_exists "$HOME/device/saved" "to_card without secret files does not save"

# --- a protected key and only an admin PIN file
reset_state
output="$(sca security_key openpgp_key to_card --admin-pin-file "$HOME/secrets/admin-pin" 2>&1)" \
  && fail "to_card exits 0 with a PIN file and no passphrase file"
[[ "$output" == *"--passphrase-file"* ]] || fail "missing passphrase file message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card starts with no passphrase file"
# and a passphrase file alone, since loopback mode has no pinentry for the PIN
output="$(sca security_key openpgp_key to_card --passphrase-file "$HOME/secrets/passphrase" 2>&1)" \
  && fail "to_card exits 0 with a passphrase file and no PIN file"
[[ "$output" == *"needs --admin-pin-file too"* ]] || fail "missing PIN file message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card starts with no PIN file"
# an unprotected key needs no passphrase file
reset_state
touch "$HOME/device/unprotected"
output="$(sca security_key openpgp_key to_card --admin-pin-file "$HOME/secrets/admin-pin" 2>&1)"
assert_eq 0 "$?" "to_card, unprotected key: $output"
grep -q '^passphrase:' "$HOME/hidden" && fail "to_card sends a passphrase for an unprotected key"
assert_eq 6 "$(grep -c "^pin:$admin_pin$" "$HOME/hidden")" "PIN answers for an unprotected key"

# --- filled slots are refused without --force, replaced with it
reset_state
sed -i "s/^fpr:.*/fpr:$other::$other:/" "$HOME/device/card_status"
touch "$HOME/device/filled_1" "$HOME/device/filled_3"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with filled slots"
[[ "$output" == *"Signature key: $other"*"Authentication key: $other"*"--force"* ]] || fail "filled slots message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits with filled slots"
output="$(sca security_key openpgp_key to_card --force "${secret_opts[@]}" 2>&1)"
assert_eq 0 "$?" "to_card --force: $output"
assert_eq 2 "$(grep -cx "replace y" "$HOME/commands")" "replace answers with --force"
assert_file_exists "$HOME/device/saved" "to_card --force does not save"

# --- the backup check
reset_state
rm "$HOME/.sca/keys/openpgp/$master/master-and-subkeys.asc"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 without a backup"
[[ "$output" == *"no backup"*"--no-backup-check"* ]] || fail "missing backup message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits without a backup"
sca security_key openpgp_key to_card --no-backup-check "${secret_opts[@]}" >/dev/null 2>&1 || fail "to_card --no-backup-check"
reset_state
mkdir -p "$HOME/elsewhere"
echo "backup of someone else" > "$HOME/elsewhere/master-and-subkeys.asc"
output="$(sca security_key openpgp_key to_card --backup-dir "$HOME/elsewhere" "${secret_opts[@]}" 2>&1)" \
  && fail "to_card exits 0 with another key's backup"
[[ "$output" == *"is not a backup of the key $master"* ]] || fail "wrong backup message: $output"
echo "backup of $master" > "$HOME/elsewhere/master-and-subkeys.asc"
rm "$HOME/.sca/keys/openpgp/$master/master-and-subkeys.asc"
sca security_key openpgp_key to_card --backup-dir "$HOME/elsewhere" "${secret_opts[@]}" >/dev/null 2>&1 \
  || fail "to_card --backup-dir"

# --- the card: another serial, more than one key, no ykman, no card
reset_state
output="$(sca security_key openpgp_key to_card --device 87654321 "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 for another card"
[[ "$output" == *"serial '12345678', not 87654321"* ]] || fail "serial mismatch message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits another card"
printf '%s\n' 12345678 87654321 > "$HOME/device/serials"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with two keys"
[[ "$output" == *"12345678"*"87654321"*"--device"* ]] || fail "two keys message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits with two keys"
sca security_key openpgp_key to_card --device 12345678 "${secret_opts[@]}" >/dev/null 2>&1 \
  || fail "to_card --device with two keys"
reset_state
export -n -f ykman
nopath="$HOME/bin-noykman"
mkdir -p "$nopath"
for tool in bash cat dirname getopt grep mkdir mktemp mv rm sed awk tail chmod paste env touch; do
  ln -sf "$(command -v "$tool")" "$nopath/$tool"
done
output="$(PATH="$nopath" sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 without ykman"
[[ "$output" == *"ykman not found"*"--device"* ]] || fail "no ykman message: $output"
output="$(PATH="$nopath" sca security_key openpgp_key to_card --device 12345678 "${secret_opts[@]}" 2>&1)"
assert_eq 0 "$?" "to_card --device without ykman: $output"
[[ "$output" == *"warning: ykman not found, so the firmware is not checked"* ]] || fail "no firmware warning: $output"
export -f ykman
reset_state
rm "$HOME/device/card_status"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with no card"
[[ "$output" == *"no OpenPGP card found"*"sca install --openpgp"* ]] || fail "no card message: $output"

# --- ed25519 on firmware before 5.2.3
reset_state
echo 5.1.2 > "$HOME/device/firmware"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 on firmware 5.1.2"
[[ "$output" == *"firmware 5.1.2"*"--algo rsa4096"* ]] || fail "old firmware message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits on old firmware"
# rsa4096 is fine there
sed -i '/^ssb/{s/:255:22:/:4096:1:/; s/:255:18:/:4096:1:/; s/:ed25519:/::/; s/:cv25519:/::/}' "$HOME/device/listing"
sca security_key openpgp_key to_card "${secret_opts[@]}" >/dev/null 2>&1 || fail "to_card rsa4096 on firmware 5.1.2"

# --- which key: two candidates, --fingerprint, a key that doesn't fit
# another key, with two [S] subkeys
write_other_key() {
  cat > "$HOME/device/other_key" <<EOF
sec:u:255:22:BBBBBBBBBBBBBBBB:1700000000:::u:::cSEA:::+::ed25519:::0:
fpr:::::::::$other:
grp:::::::::B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0:
ssb:u:255:22:4444444444444444:1700000000:1800000000:::::s:::+::ed25519::
fpr:::::::::4444444444444444444444444444444444444444:
grp:::::::::B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1B1:
ssb:u:255:22:5555555555555555:1700000000:1800000000:::::s:::+::ed25519::
fpr:::::::::5555555555555555555555555555555555555555:
grp:::::::::B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2B2:
ssb:u:255:18:6666666666666666:1700000000:1800000000:::::e:::+::cv25519::
fpr:::::::::6666666666666666666666666666666666666666:
grp:::::::::B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3B3:
ssb:u:255:22:7777777777777777:1700000000:1800000000:::::a:::+::ed25519::
fpr:::::::::7777777777777777777777777777777777777777:
grp:::::::::B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4B4:
EOF
}
reset_state
write_other_key
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)"
assert_eq 0 "$?" "to_card with one fitting key: $output"
grep -q -- "--edit-key $master" "$HOME/calls" || fail "to_card does not pick the fitting key"
output="$(sca security_key openpgp_key to_card --fingerprint "$other" "${secret_opts[@]}" 2>&1)" \
  && fail "to_card exits 0 for a key with two [S] subkeys"
[[ "$output" == *"the key $other needs exactly one subkey"*"2 sign"*"by hand"* ]] || fail "two [S] subkeys message: $output"
# an expired [S] subkey doesn't count, so the other key fits too
reset_state
write_other_key
sed -i 's/^ssb:u:255:22:5555/ssb:e:255:22:5555/' "$HOME/device/other_key"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with two fitting keys"
[[ "$output" == *"more than one key"*"--fingerprint"* ]] || fail "two keys message: $output"
[[ "$output" == *"$master"* && "$output" == *"$other"* ]] || fail "two keys are not listed: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits with two fitting keys"
reset_state
sed -i '0,/:a:::+:/s//:a:::#:/' "$HOME/device/listing"
output="$(sca security_key openpgp_key to_card --fingerprint "$master" "${secret_opts[@]}" 2>&1)" \
  && fail "to_card exits 0 for a key whose [A] subkey is a stub"
[[ "$output" == *"0 authenticate"*"by hand"* ]] || fail "stub subkey message: $output"
grep -q -- "--edit-key" "$HOME/calls" && fail "to_card edits a key with a stub subkey"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 with no fitting key"
[[ "$output" == *"no key in this keyring"* ]] || fail "no fitting key message: $output"

# --- gpg failing before it asks for the slot (no card daemon) quits unsaved
reset_state
touch "$HOME/device/no_card"
output="$(sca security_key openpgp_key to_card "${secret_opts[@]}" 2>&1)" && fail "to_card exits 0 when keytocard fails"
[[ "$output" == *"signature key slot failed"*"already written: none"* ]] || fail "keytocard failure message: $output"
[ ! -e "$HOME/device/saved" ] || fail "to_card saves after keytocard failed"

# --- bad secret files are refused before gpg runs
reset_state
for file in "$HOME/secrets/empty" "$HOME/secrets/two-lines" "$HOME/secrets/missing"; do
  [ -e "$HOME/secrets/empty" ] || : > "$HOME/secrets/empty"
  [ -e "$HOME/secrets/two-lines" ] || printf 'one\ntwo\n' > "$HOME/secrets/two-lines"
  assert_fails sca security_key openpgp_key to_card --admin-pin-file "$file" --passphrase-file "$HOME/secrets/passphrase"
done
assert_eq "" "$(cat "$HOME/calls")" "gpg calls with bad secret files"

# --- missing gpg names sca install --openpgp
reset_state
export -n -f gpg
output="$(PATH="$nopath" sca security_key openpgp_key to_card 2>&1)" && fail "to_card exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "to_card, missing gpg message: $output"
output="$(PATH="$nopath" sca security_key openpgp_key create --name A --email a@example.org 2>&1)" && fail "create exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "create, missing gpg message: $output"
export -f gpg

[ ! -e "$config_file" ] || fail "openpgp_key creates a sca config"
test_done
