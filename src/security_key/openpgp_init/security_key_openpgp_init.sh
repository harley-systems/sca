################################################################################
# move the OpenPGP applet of a yubikey off its factory default PINs: set the
# retry counters, then the user PIN, the reset code (if asked for) and, last,
# the admin PIN
#
# no PIN ever goes on a command line or into the log: they are read with read
# -s or from files, and reach gpg on its stdin, written by the printf builtin.
# the one exception is the factory default admin PIN 12345678, which ykman
# set-retries only takes as an argument. the PINs are not stored anywhere.
#
# the admin PIN is changed last, so a run cut short leaves the old admin PIN in
# place, and rerunning the same command finishes the job.
security_key_openpgp_init() {
  local command=security_key_openpgp_init
  local device=''
  local retries=''
  local retries_given=false
  local roll=false
  local want_reset_code=false
  local user_pin_file=''
  local admin_pin_file=''
  local reset_code_file=''
  local current_admin_pin_file=''
  local OPTS
  OPTS=`getopt -o h --long help,device:,retries:,roll,reset-code,user-pin-file:,admin-pin-file:,reset-code-file:,current-admin-pin-file: -n "sca security_key openpgp_init" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_init -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_init_help
        return
      ;;
      --device )
        device=$2
        shift;shift
      ;;
      --retries )
        retries=$2
        retries_given=true
        shift;shift
      ;;
      --roll )
        roll=true
        shift
      ;;
      --reset-code )
        want_reset_code=true
        shift
      ;;
      --user-pin-file )
        user_pin_file=$2
        shift;shift
      ;;
      --admin-pin-file )
        admin_pin_file=$2
        shift;shift
      ;;
      --reset-code-file )
        reset_code_file=$2
        want_reset_code=true
        shift;shift
      ;;
      --current-admin-pin-file )
        current_admin_pin_file=$2
        shift;shift
      ;;
      -- )
        shift
        break
      ;;
      * )
        break
      ;;
    esac
  done
  [ $# -gt 0 ] && error "$command: unexpected argument '$1'. use sca security_key "\
"openpgp_init -h for help." 1
  if [ $retries_given = true ]; then
    { [[ "$retries" =~ ^[0-9]{1,2}$ ]] && [ "$((10#$retries))" -ge 1 ]; } || \
      error "$command: invalid value '$retries' for --retries. use a number "\
"from 1 to 99." 1
    retries=$((10#$retries))
  fi
  if [ $roll = true ] && [ $retries_given = true ]; then
    error "$command: --retries can't be used with --roll: ykman takes the admin "\
"PIN only on its command line, where other users could read it. set the "\
"counters by hand with 'ykman openpgp access set-retries N N N', which asks "\
"for the admin PIN, then change the PINs with --roll." 1
  fi
  if [ $roll = false ] && [ -n "$current_admin_pin_file" ]; then
    error "$command: --current-admin-pin-file is only used with --roll. without "\
"--roll, the card must still have the factory default admin PIN." 1
  fi
  security_key_openpgp_need_tools $command gpg gpgconf ykman
  log_detailed "$command: started (device='$device', retries='$retries', roll=$roll, "\
"reset_code=$want_reset_code, user_pin_file='$user_pin_file', "\
"admin_pin_file='$admin_pin_file', reset_code_file='$reset_code_file', "\
"current_admin_pin_file='$current_admin_pin_file')"
  local serial
  serial=$(security_key_openpgp_select_device $command "$device") || exit $?
  log_detailed "$command: acting on the yubikey with serial '$serial'"

  # every PIN is collected and checked before the card is touched
  local default_user_pin=123456
  local default_admin_pin=12345678
  local current_admin_pin=$default_admin_pin
  local user_pin='' admin_pin='' reset_code=''
  if [ $roll = true ]; then
    security_key_openpgp_init_get_pin current_admin_pin "current admin PIN" \
      --current-admin-pin-file "$current_admin_pin_file" false
    # a shorter one can't be right, and would cost an admin PIN try
    security_key_openpgp_init_check_pin "current admin PIN" "$current_admin_pin" 8
  fi
  security_key_openpgp_init_get_pin user_pin "new user PIN" --user-pin-file "$user_pin_file" true
  security_key_openpgp_init_check_pin "new user PIN" "$user_pin" 6
  if [ $want_reset_code = true ]; then
    security_key_openpgp_init_get_pin reset_code "new reset code" --reset-code-file "$reset_code_file" true
    security_key_openpgp_init_check_pin "new reset code" "$reset_code" 8
  fi
  security_key_openpgp_init_get_pin admin_pin "new admin PIN" --admin-pin-file "$admin_pin_file" true
  security_key_openpgp_init_check_pin "new admin PIN" "$admin_pin" 8
  [ "$user_pin" = "$default_user_pin" ] && \
    error "$command: the new user PIN is the factory default. choose another one. "\
"nothing was changed." 1
  [ "$admin_pin" = "$current_admin_pin" ] && \
    error "$command: the new admin PIN is the same as the current one. choose "\
"another one. nothing was changed." 1
  [ "$user_pin" = "$admin_pin" ] && \
    error "$command: the new user PIN and admin PIN are the same. choose two "\
"different ones. nothing was changed." 1

  # the steps that succeeded, for the error messages
  security_key_openpgp_init_done=()
  security_key_openpgp_init_card "$serial"
  local counters admin_tries
  counters=$(security_key_openpgp_init_counters)
  admin_tries=${counters##* }
  log_detailed "$command: PIN retry counters before (user, reset code, admin): '$counters'"
  [[ "$admin_tries" =~ ^[0-9]+$ ]] || \
    error "$command: could not read the PIN retry counters of the card "\
"('gpg --card-status'). nothing was changed." 1
  if [ "$admin_tries" -le 1 ]; then
    error "$command: the admin PIN retry counter is $admin_tries: one more "\
"wrong try would block the OpenPGP applet for good, so no admin PIN was tried. "\
"nothing was changed. if you know the admin PIN, change the PINs by hand "\
"('gpg --card-edit', then 'admin' and 'passwd'), which resets the counter; "\
"otherwise reset the applet (docs/gpg-yubikey.md, Reset the OpenPGP applet), "\
"which deletes the keys on it." 1
  fi

  # 1. the retry counters, on the default path only. they come first: on
  # firmware before 4.0, set-retries puts all three PINs back to their defaults.
  # it is also the probe for "still the default admin PIN".
  if [ $roll = false ]; then
    local count=${retries:-5}
    log_detailed "$command: ykman --device $serial openpgp access set-retries "\
"$count $count $count --admin-pin <factory default> --force"
    # ykman can't reach the card while scdaemon holds it
    gpgconf --kill scdaemon >/dev/null 2>&1
    local ykman_output
    if ! ykman_output=$(ykman --device "$serial" openpgp access set-retries \
        "$count" "$count" "$count" --admin-pin "$default_admin_pin" --force 2>&1); then
      log_detailed "$command: set-retries failed: '$ykman_output'"
      security_key_openpgp_init_card "$serial"
      local tries_after
      tries_after=$(security_key_openpgp_init_counters)
      tries_after=${tries_after##* }
      if [[ "$tries_after" =~ ^[0-9]+$ ]] && [ "$tries_after" -lt "$admin_tries" ]; then
        error "$command: the card's admin PIN is not the factory default "\
"$default_admin_pin, so its PINs were changed before. nothing was changed. "\
"this check spent one admin PIN try ($tries_after left; the right admin PIN "\
"resets the counter). to change the PINs again, rerun with --roll." 1
      fi
      error "$command: ykman could not set the PIN retry counters: "\
"${ykman_output:-no output}. nothing was changed." 1
    fi
    echo "PIN retry counters set to $count."
    security_key_openpgp_init_done+=("PIN retry counters set to $count")
  fi

  # 2. the user PIN, set with the admin PIN (passwd menu 2, unblock PIN), so
  # --roll needs no current user PIN
  security_key_openpgp_init_change "$serial" 2 "$current_admin_pin" "$user_pin"
  case $? in
    0 ) ;;
    2 )
      if [ ${#security_key_openpgp_init_done[@]} -eq 0 ]; then
        security_key_openpgp_init_card "$serial"
        counters=$(security_key_openpgp_init_counters)
        error "$command: the card rejected the current admin PIN. nothing was "\
"changed (${counters##* } admin PIN tries left)." 1
      fi
      security_key_openpgp_init_fail "the card rejected the admin PIN while "\
"setting the user PIN."
      ;;
    * )
      security_key_openpgp_init_fail "gpg could not set the user PIN"\
"${security_key_openpgp_init_gpg_message:+ (${security_key_openpgp_init_gpg_message})}."
      ;;
  esac
  echo "user PIN changed."
  security_key_openpgp_init_done+=("user PIN changed")

  # 3. the reset code (passwd menu 4), only if asked for
  if [ $want_reset_code = true ]; then
    security_key_openpgp_init_change "$serial" 4 "$current_admin_pin" "$reset_code" || \
      security_key_openpgp_init_fail "gpg could not set the reset code"\
"${security_key_openpgp_init_gpg_message:+ (${security_key_openpgp_init_gpg_message})}."
    echo "reset code set."
    security_key_openpgp_init_done+=("reset code set")
  fi

  # 4. the admin PIN (passwd menu 3), last
  security_key_openpgp_init_change "$serial" 3 "$current_admin_pin" "$admin_pin" || \
    security_key_openpgp_init_fail "gpg could not change the admin PIN"\
"${security_key_openpgp_init_gpg_message:+ (${security_key_openpgp_init_gpg_message})}."
  echo "admin PIN changed."

  # the card is changed: reading the counters back is not worth failing for,
  # so it runs in a subshell, which a failing read can only end
  gpgconf --kill scdaemon >/dev/null 2>&1
  counters=$(security_key_openpgp_init_select "$serial" 2>/dev/null && \
    security_key_openpgp_init_counters)
  log_detailed "$command: PIN retry counters after (user, reset code, admin): '$counters'"
  echo
  echo "the OpenPGP PINs of the YubiKey $serial are changed."
  if [ -n "$counters" ]; then
    echo "PIN retry counters (user PIN, reset code, admin PIN): $counters"
  else
    echo "check the PIN retry counters with 'gpg --card-status'."
  fi
  if [ -n "$reset_code" ]; then
    echo "write the admin PIN and the reset code down and keep them with your"\
" offline backup: sca does not store them."
  else
    echo "write the admin PIN down and keep it with your offline backup: sca"\
" does not store it."
  fi
  log_detailed "$command: finished (serial=$serial)"
}
################################################################################
# reads a PIN into the variable named, from a file or the terminal
#
# parameters
#   variable - the name of the variable to set
#   label    - what the PIN is, for prompts and messages
#   option   - the option that names its file, for messages
#   file     - the file to read it from, or empty to ask for it
#   confirm  - true to have it typed twice
security_key_openpgp_init_get_pin() {
  local variable="$1" label="$2" option="$3" file="$4" confirm="$5"
  local command=security_key_openpgp_init
  local value='' again=''
  if [ -n "$file" ]; then
    { [ -r "$file" ] && [ ! -d "$file" ]; } || \
      error "$command: can't read the $label from '$file' ($option). nothing "\
"was changed." 1
    # read, not cat or $(...): no process, and only one newline is stripped
    IFS= read -r -d '' value < "$file"
    value=${value%$'\n'}
  else
    [ -t 0 ] || \
      error "$command: the $label is needed, but $option was not given and "\
"stdin is not a terminal to ask for it. nothing was changed." 1
    IFS= read -r -s -p "Enter the $label: " value
    echo >&2
    if [ "$confirm" = true ]; then
      IFS= read -r -s -p "Repeat the $label: " again
      echo >&2
      [ "$value" = "$again" ] || \
        error "$command: the two entries of the $label don't match. nothing "\
"was changed." 1
    fi
  fi
  printf -v "$variable" '%s' "$value"
}
################################################################################
# exits unless a new PIN is one line of min to 127 bytes
#
# parameters
#   label - what the PIN is, for the message
#   value - the PIN
#   min   - its minimum length
security_key_openpgp_init_check_pin() {
  local label="$1" value="$2" min="$3"
  local command=security_key_openpgp_init
  [[ "$value" == *$'\n'* ]] && \
    error "$command: the $label must be a single line. nothing was changed." 1
  # the card counts bytes
  local LC_ALL=C
  if [ ${#value} -lt "$min" ] || [ ${#value} -gt 127 ]; then
    error "$command: the $label must be $min to 127 characters long. nothing "\
"was changed." 1
  fi
}
################################################################################
# exits with the message and the steps that already succeeded, so the user
# knows the state the card is in
#
# parameters
#   message - what failed
security_key_openpgp_init_fail() {
  local message="$1"
  local state='nothing was changed.'
  if [ ${#security_key_openpgp_init_done[@]} -gt 0 ]; then
    local step steps=''
    for step in "${security_key_openpgp_init_done[@]}"; do
      steps="${steps:+$steps; }$step"
    done
    state="already done: $steps. the admin PIN is still the old one: rerun "\
"the same command to finish."
  fi
  error "security_key_openpgp_init: $message $state" 1
}
################################################################################
# makes gpg's current OpenPGP card the one with the given serial, after a fresh
# start of scdaemon, and reads it into security_key_openpgp_card_status. exits
# if that can't be done: gpg acts on its current card, and with two keys
# attached it could otherwise change the PINs of the other one.
#
# scdaemon is restarted before every step: it remembers a verified admin PIN,
# and would then not ask for it, which would shift the PINs fed to gpg.
#
# parameters
#   serial - the yubikey serial, as ykman lists it
security_key_openpgp_init_card() {
  gpgconf --kill scdaemon >/dev/null 2>&1
  security_key_openpgp_init_select "$1" || \
    security_key_openpgp_init_fail "gpg acts on the OpenPGP card with serial "\
"'$security_key_openpgp_init_card_serial', not on the YubiKey $1, and could "\
"not be switched to it. unplug the other security keys and retry."
}
################################################################################
# reads gpg's current card, and switches to the one with the given serial if it
# is another one. returns 1 if it is still another one.
#
# parameters
#   serial - the yubikey serial, as ykman lists it
security_key_openpgp_init_select() {
  local serial=$((10#$1))
  security_key_openpgp_read_card security_key_openpgp_init
  security_key_openpgp_init_card_serial=$(security_key_openpgp_init_serial)
  log_detailed "security_key_openpgp_init_select: gpg's card is "\
"'$security_key_openpgp_init_card_serial', wanted '$serial'"
  [ "$security_key_openpgp_init_card_serial" = "$serial" ] && return 0
  command -v gpg-connect-agent >/dev/null 2>&1 || return 1
  # the application ID: D27600012401, the OpenPGP version (the current card's
  # first), 0006 for Yubico, the serial in BCD and 0000. SWITCHCARD is GnuPG
  # 2.3 and later, SERIALNO --demand the fallback for 2.2.
  local current_version
  current_version=$(printf '%s\n' "$security_key_openpgp_card_status" | \
    awk -F: '$1 == "Reader" && $3 == "AID" { print substr($4, 13, 4); exit }')
  local version aid
  for version in $current_version 0304 0303 0201; do
    aid=$(printf 'D27600012401%s0006%08d0000' "$version" "$serial")
    log_detailed "security_key_openpgp_init_select: switching to '$aid'"
    gpg-connect-agent "SCD SWITCHCARD $aid" "SCD SERIALNO --demand=$aid" /bye >/dev/null 2>&1
    security_key_openpgp_read_card security_key_openpgp_init
    security_key_openpgp_init_card_serial=$(security_key_openpgp_init_serial)
    [ "$security_key_openpgp_init_card_serial" = "$serial" ] && return 0
  done
  return 1
}
################################################################################
# prints the serial of the card in security_key_openpgp_card_status, without
# leading zeros, as ykman lists it
security_key_openpgp_init_serial() {
  local serial
  serial=$(printf '%s\n' "$security_key_openpgp_card_status" | awk -F: '$1 == "serial" { print $2; exit }')
  if [[ "$serial" =~ ^[0-9]{1,8}$ ]]; then
    echo $((10#$serial))
  else
    printf '%s\n' "$serial"
  fi
}
################################################################################
# prints the PIN retry counters of the card in security_key_openpgp_card_status:
# "<user PIN> <reset code> <admin PIN>"
security_key_openpgp_init_counters() {
  printf '%s\n' "$security_key_openpgp_card_status" | \
    awk -F: '$1 == "pinretries" { print $2, $3, $4; exit }'
}
################################################################################
# runs one step of the gpg passwd menu on the card with the given serial.
# returns 0 when gpg reports success, 2 when the card rejected the admin PIN,
# and 1 otherwise, with gpg's messages in security_key_openpgp_init_gpg_message.
#
# the PINs reach gpg on its stdin, which the printf builtin writes, so they are
# on no command line. under --pinentry-mode loopback every PIN prompt reads a
# line from --command-fd: the admin PIN first, then the new value and its
# repetition. should a gpg version ask for the new value only once, the
# repetition is read at the menu, which ignores any answer longer than one
# character, and q still ends it. success is judged from the status lines, as
# gpg --change-pin exits 0 whatever the outcome.
#
# parameters
#   serial    - the yubikey serial
#   menu      - 2 (user PIN, with the admin PIN), 3 (admin PIN), 4 (reset code)
#   admin_pin - the current admin PIN
#   new_pin   - the new value
security_key_openpgp_init_change() {
  local serial="$1" menu="$2"
  security_key_openpgp_init_gpg_message=''
  security_key_openpgp_init_card "$serial"
  log_detailed "security_key_openpgp_init_change: gpg --change-pin, menu $menu"
  local output rc
  output=$(printf '%s\n' "$menu" "$3" "$4" "$4" q | \
    gpg --no-tty --pinentry-mode loopback --command-fd 0 --status-fd 1 --change-pin 2>&1)
  rc=$?
  # the status lines name no PIN; the rest is gpg's messages
  log_detailed "security_key_openpgp_init_change: rc=$rc, status:"\
"'$(printf '%s\n' "$output" | grep -E '^\[GNUPG:\] (SC_OP_|BAD_PASSPHRASE)' | tr '\n' ' ')'"
  if [ $rc = 0 ] && printf '%s\n' "$output" | grep -q '^\[GNUPG:\] SC_OP_SUCCESS' && \
      ! printf '%s\n' "$output" | grep -q '^\[GNUPG:\] SC_OP_FAILURE'; then
    return 0
  fi
  security_key_openpgp_init_gpg_message=$(printf '%s\n' "$output" | \
    awk '/^gpg: / { sub(/^gpg: /, ""); printf "%s%s", sep, $0; sep = "; " }')
  printf '%s\n' "$output" | grep -qE '^\[GNUPG:\] (SC_OP_FAILURE 2|BAD_PASSPHRASE)' && return 2
  return 1
}
security_key_openpgp_init_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
