################################################################################
# program, back up and test HMAC-SHA1 challenge-response in OTP slot 2 of a
# yubikey (KeePassXC, pam_yubico, disk unlock scripts)
#
# no mode reads the sca configuration. the secret only ever lives in a shell
# variable, the secret file and ykman's stdin: never on an argv (sca's,
# ykman's or openssl's), in the log, or on stdout or stderr.
security_key_otp_chalresp() {
  local mode="$1"
  case "$mode" in
    -h | --help )
      security_key_otp_chalresp_help
      return
      ;;
    setup|backup|test )
      shift
      log_detailed "security_key_otp_chalresp: start (mode=${mode})"
      security_key_otp_chalresp_$mode "$@"
      ;;
    * )
      error "security_key_otp_chalresp: invalid value '$mode' for the mode. supported "\
"values are 'setup', 'backup' and 'test'. use sca security_key otp_chalresp -h for help." 1
      ;;
  esac
}
# the challenge test sends: "sca otp_chalresp test" in hex
security_key_otp_chalresp_challenge=736361206f74705f6368616c726573702074657374
################################################################################
# sca security_key otp_chalresp setup
security_key_otp_chalresp_setup() {
  local device=''
  local touch=false
  local secret_file=''
  local force=false
  local OPTS
  OPTS=`getopt -o hf --long help,device:,touch,secret-file:,force -n "sca security_key otp_chalresp setup" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key otp_chalresp -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_otp_chalresp_help
        return
      ;;
      --device )
        device=$2
        shift;shift
      ;;
      --touch )
        touch=true
        shift
      ;;
      --secret-file )
        secret_file=$2
        shift;shift
      ;;
      -f | --force )
        force=true
        shift
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
  [ $# -gt 0 ] && error "security_key_otp_chalresp setup: unexpected argument '$1'. "\
"use sca security_key otp_chalresp -h for help." 1
  security_key_otp_chalresp_need_tools ykman openssl
  log_detailed "security_key_otp_chalresp_setup: started (device='$device', touch=$touch, "\
"secret_file='$secret_file', force=$force)"
  local serial
  serial=$(security_key_otp_chalresp_select_device "$device") || exit $?

  local folder
  if [ -z "$secret_file" ]; then
    folder="$HOME/.sca/private"
    secret_file="$folder/yubikey-${serial}-chalresp.txt"
    if [ ! -d "$folder" ]; then
      (umask 077; mkdir -p "$folder") || \
        error "security_key_otp_chalresp setup: could not create '$folder'. "\
"choose another file with --secret-file FILE." 1
    fi
  else
    folder=$(dirname "$secret_file")
    [ -d "$folder" ] || \
      error "security_key_otp_chalresp setup: the folder '$folder' does not exist. "\
"create it, or choose another file with --secret-file FILE." 1
  fi
  log_detailed "security_key_otp_chalresp_setup: secret_file='$secret_file'"
  if [ -e "$secret_file" ] || [ -L "$secret_file" ]; then
    error "security_key_otp_chalresp setup: '$secret_file' already exists and is "\
"never overwritten, not even with -f. it may hold the secret of a key in use: "\
"move it away, or choose another file with --secret-file FILE." 1
  fi
  security_key_otp_chalresp_check_slot "$serial" "$force" setup

  local secret
  secret=$(openssl rand -hex 20)
  [[ "$secret" =~ ^[0-9a-f]{40}$ ]] || \
    error "security_key_otp_chalresp setup: 'openssl rand -hex 20' failed, nothing "\
"was written or programmed. check the openssl installation." 1

  # created 600 from the start, and never over a file that appeared meanwhile
  local tmp
  tmp=$(umask 077; mktemp "$folder/.sca-otp-chalresp.XXXXXX") || \
    error "security_key_otp_chalresp setup: could not create a temporary file in "\
"'$folder'. nothing was programmed." 1
  trap "rm -f $(printf '%q' "$tmp")" EXIT
  if ! (umask 077; printf '%s\n' "$secret" > "$tmp") || \
      ! mv -n "$tmp" "$secret_file" || [ -e "$tmp" ]; then
    error "security_key_otp_chalresp setup: could not write '$secret_file'. "\
"nothing was programmed." 1
  fi
  trap - EXIT

  if ! security_key_otp_chalresp_program "$serial" "$secret" "$touch"; then
    rm -f "$secret_file"
    error "security_key_otp_chalresp setup: programming slot 2 of YubiKey $serial "\
"failed, and '$secret_file' was removed. if the slot is protected by an OTP "\
"access code, remove it with ykman first (sca does not support access codes)." 1
  fi
  local touch_text='no touch is required'
  [ $touch = true ] && touch_text='a touch is required for every response'
  cat <<EOF
YubiKey $serial: slot 2 is programmed with HMAC-SHA1 challenge-response
($touch_text).
the secret was written to '$secret_file'.

next steps:
  1. store a copy of '$secret_file' offline.
  2. program a backup key with the same secret:
       sca security_key otp_chalresp backup --device <other serial> --secret-file '$secret_file'$( [ $touch = true ] && printf ' --touch')
  3. run 'sca security_key otp_chalresp test --device <serial>' on both keys:
     the responses must match.
  4. delete '$secret_file', or move it to the air-gapped stick.
EOF
  log_detailed "security_key_otp_chalresp_setup: finished (serial=$serial)"
}
################################################################################
# sca security_key otp_chalresp backup
security_key_otp_chalresp_backup() {
  local device=''
  local touch=false
  local secret_file=''
  local force=false
  local OPTS
  OPTS=`getopt -o hf --long help,device:,touch,secret-file:,force -n "sca security_key otp_chalresp backup" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key otp_chalresp -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_otp_chalresp_help
        return
      ;;
      --device )
        device=$2
        shift;shift
      ;;
      --touch )
        touch=true
        shift
      ;;
      --secret-file )
        secret_file=$2
        shift;shift
      ;;
      -f | --force )
        force=true
        shift
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
  [ $# -gt 0 ] && error "security_key_otp_chalresp backup: unexpected argument '$1'. "\
"use sca security_key otp_chalresp -h for help." 1
  [ -n "$secret_file" ] || \
    error "security_key_otp_chalresp backup: --secret-file FILE is required: the file "\
"setup wrote, with the secret of the key to back up." 1
  security_key_otp_chalresp_need_tools ykman
  log_detailed "security_key_otp_chalresp_backup: started (device='$device', touch=$touch, "\
"secret_file='$secret_file', force=$force)"
  { [ -f "$secret_file" ] && [ -r "$secret_file" ]; } || \
    error "security_key_otp_chalresp backup: '$secret_file' is not a readable file. "\
"pass the file sca security_key otp_chalresp setup wrote." 1
  local secret
  secret=$(< "$secret_file")
  secret=${secret//[[:space:]]/}
  # the content is never quoted: it is, or is close to, the secret
  [[ "$secret" =~ ^[0-9A-Fa-f]{40}$ ]] || \
    error "security_key_otp_chalresp backup: '$secret_file' does not hold a secret "\
"in the format setup writes (40 hex characters). check that it is the right file." 1
  secret=${secret,,}
  if [ -n "$(find "$secret_file" -prune \( -perm -g+r -o -perm -o+r \) 2>/dev/null)" ]; then
    >&2 echo "warning: '$secret_file' can be read by other users. restrict it "\
"with chmod 600, and move it offline when the backup is done."
  fi
  local serial
  serial=$(security_key_otp_chalresp_select_device "$device") || exit $?
  security_key_otp_chalresp_check_slot "$serial" "$force" backup
  security_key_otp_chalresp_program "$serial" "$secret" "$touch" || \
    error "security_key_otp_chalresp backup: programming slot 2 of YubiKey $serial "\
"failed. if the slot is protected by an OTP access code, remove it with ykman "\
"first (sca does not support access codes)." 1
  local touch_text='no touch is required'
  [ $touch = true ] && touch_text='a touch is required for every response'
  cat <<EOF
YubiKey $serial: slot 2 is programmed with the secret from '$secret_file'
($touch_text).
run 'sca security_key otp_chalresp test --device <serial>' on this key and the
original: the responses must match.
EOF
  log_detailed "security_key_otp_chalresp_backup: finished (serial=$serial)"
}
################################################################################
# sca security_key otp_chalresp test
security_key_otp_chalresp_test() {
  local device=''
  local OPTS
  OPTS=`getopt -o h --long help,device: -n "sca security_key otp_chalresp test" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key otp_chalresp -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_otp_chalresp_help
        return
      ;;
      --device )
        device=$2
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
  [ $# -gt 0 ] && error "security_key_otp_chalresp test: unexpected argument '$1'. "\
"use sca security_key otp_chalresp -h for help." 1
  security_key_otp_chalresp_need_tools ykman
  log_detailed "security_key_otp_chalresp_test: started (device='$device')"
  local serial
  serial=$(security_key_otp_chalresp_select_device "$device") || exit $?
  local state
  state=$(security_key_otp_chalresp_slot_state "$serial") || exit $?
  [ "$state" = empty ] && \
    error "security_key_otp_chalresp test: slot 2 of YubiKey $serial is empty. "\
"program it with sca security_key otp_chalresp setup, or backup." 1
  local challenge=$security_key_otp_chalresp_challenge
  local response
  # stderr is left alone: it is where ykman asks for a touch
  response=$(ykman --device "$serial" otp calculate 2 "$challenge") && [ -n "$response" ] || \
    error "security_key_otp_chalresp test: 'ykman --device $serial otp calculate 2' "\
"failed. if slot 2 requires a touch, touch the key when it blinks; check that "\
"slot 2 holds a challenge-response credential (ykman --device $serial otp info)." 1
  echo "challenge: $challenge"
  echo "response:  $response (YubiKey $serial, slot 2)"
  log_detailed "security_key_otp_chalresp_test: finished (serial=$serial)"
}
################################################################################
# prints the serial of the yubikey to use. OTP is reached over HID, so this
# goes through ykman list --serials rather than the PC/SC readers
# security_key_select_device uses.
#
# parameters
#   device - the serial given with --device, or empty
security_key_otp_chalresp_select_device() {
  local device="$1"
  local serials
  serials=$(ykman list --serials 2>/dev/null | awk 'NF { print $1 }')
  local listed
  listed=$(printf '%s\n' "$serials" | awk 'NF { printf "%s%s", sep, $1; sep=", " }')
  log_detailed "security_key_otp_chalresp_select_device: device:'$device' attached:'$listed'"
  [ -n "$serials" ] || \
    error "no YubiKey attached (ykman list --serials shows none). plug one in, and "\
"check that its OTP application is enabled (ykman info)." 1
  if [ -z "$device" ]; then
    if [ "$(printf '%s\n' "$serials" | wc -l)" -gt 1 ]; then
      error "more than one security key is attached (serials: $listed). "\
"choose one with --device SERIAL." 1
    fi
    printf '%s\n' "$serials"
  else
    printf '%s\n' "$serials" | grep -qxF -- "$device" || \
      error "no security key with serial '$device' is attached "\
"(attached: ${listed:-none})." 1
    printf '%s\n' "$device"
  fi
}
################################################################################
# prints 'programmed' or 'empty', the state of OTP slot 2
#
# parameters
#   serial - the yubikey's serial
security_key_otp_chalresp_slot_state() {
  local serial="$1"
  local info
  info=$(ykman --device "$serial" otp info 2>&1) || \
    error "security_key_otp_chalresp: 'ykman --device $serial otp info' failed: "\
"$info. check that the OTP application is enabled (ykman --device $serial info)." 1
  local state
  state=$(printf '%s\n' "$info" | awk '$1 == "Slot" && $2 == "2:" { print $3; exit }')
  log_detailed "security_key_otp_chalresp_slot_state: serial=$serial slot 2: '$state'"
  case "$state" in
    programmed|empty ) printf '%s\n' "$state" ;;
    * )
      error "security_key_otp_chalresp: could not read the state of slot 2 from "\
"'ykman --device $serial otp info'. check the ykman version (sca install --yubikey-support)." 1
      ;;
  esac
}
################################################################################
# exits unless slot 2 is empty, or force is true
#
# parameters
#   serial - the yubikey's serial
#   force  - true to replace a programmed slot
#   mode   - setup or backup, for the message
security_key_otp_chalresp_check_slot() {
  local serial="$1" force="$2" mode="$3"
  local state
  state=$(security_key_otp_chalresp_slot_state "$serial") || exit $?
  if [ "$state" = programmed ] && [ "$force" != true ]; then
    error "security_key_otp_chalresp $mode: slot 2 of YubiKey $serial is already "\
"programmed, and nothing was changed. replacing it with -f loses its secret for "\
"good: whatever relies on it (a KeePassXC database, a pam_yubico login) stops "\
"working. rerun with -f only if nothing does." 1
  fi
  [ "$state" = programmed ] && log_detailed "security_key_otp_chalresp_check_slot: "\
"replacing slot 2 of $serial (-f)"
  return 0
}
################################################################################
# programs the secret into slot 2. the secret goes to ykman's stdin, answering
# its key prompt, and the y after it answers its confirmation: ykman's own -f
# can't be used, since it refuses to prompt for the key. sca has already
# checked the slot.
#
# parameters
#   serial - the yubikey's serial
#   secret - 40 hex characters
#   touch  - true to require a touch for every response
security_key_otp_chalresp_program() {
  local serial="$1" secret="$2" touch="$3"
  local touch_option=()
  [ "$touch" = true ] && touch_option=(-t)
  log_detailed "security_key_otp_chalresp_program: serial=$serial touch=$touch"
  local output
  if ! output=$(printf '%s\ny\n' "$secret" | \
      ykman --device "$serial" otp chalresp "${touch_option[@]}" 2 2>&1); then
    printf '%s\n' "${output//"$secret"/<secret>}" >&2
    return 1
  fi
}
################################################################################
# exits, naming the first missing one, unless all the given tools are found
#
# parameters
#   tool... - ykman, openssl
security_key_otp_chalresp_need_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || \
      error "security_key_otp_chalresp: $tool not found. install it with "\
"sca install --yubikey-support." 1
  done
}
security_key_otp_chalresp_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
