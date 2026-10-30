security_key_unblock_pin() {
  local keep_pin=false
  local device=''
  local OPTS
  OPTS=`getopt -o hk --long help,keep-pin,device: -n "sca security_key unblock_pin" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key unblock_pin -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_unblock_pin_help
        return
      ;;
      -k | --keep-pin )
        keep_pin=true
        shift
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
  local entity="$1"
  log_detailed "security_key_unblock_pin: started (keep_pin=$keep_pin, entity=$entity, device:'$device')"
  local allowed_values=(ca subca user service host)
  [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]] && \
    error "security_key_unblock_pin: invalid value supplied for entity. use sca "\
"security_key unblock_pin -h for help." 1
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  [ "$entity_security_key_type" != yubikey ] && \
    error "security_key_unblock_pin: unblocking the pin is supported for "\
"security_key_type 'yubikey' only, '$entity' has '$entity_security_key_type'." 1
  local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
  local entity_puk_file=$(eval echo \$${entity}_yubikey_puk_file)
  # every wrong puk spends one of its retries, and a blocked puk leaves only a
  # reset of the PIV application, which destroys its keys. so all that can be
  # checked is checked before the key is touched, and it is tried once only.
  [ -s "$entity_puk_file" ] || \
    error "security_key_unblock_pin: the puk file '$entity_puk_file' is missing "\
"or empty, so the pin can not be unblocked by sca. nothing was tried on the "\
"security key. if the puk is known, use yubico-piv-tool -a unblock-pin and "\
"write the new pin to '$entity_pin_file'; see docs/yubikey.md." 1
  local puk=$(cat "$entity_puk_file")
  local pin
  if [ $keep_pin = true ]; then
    [ -s "$entity_pin_file" ] || \
      error "security_key_unblock_pin: --keep-pin was given but the pin file "\
"'$entity_pin_file' is missing or empty. nothing was tried on the security key." 1
    pin=$(cat "$entity_pin_file")
  else
    pin=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-6`
    # an empty value (dd or hexdump missing) would be set on the key as-is
    [ ${#pin} -eq 6 ] || \
      error "security_key_unblock_pin: could not generate a new pin (are dd and "\
"hexdump installed?). nothing was tried on the security key." 1
  fi
  # the key is waited for once, and then named on the yubico-piv-tool call:
  # left to itself, yubico-piv-tool uses the first reader it finds, which with
  # more than one key attached need not be the one just waited for.
  local device_option=()
  [ -n "$device" ] && device_option=(--device "$device")
  local reader_slot_number
  reader_slot_number=$(security_key_wait_for "${device_option[@]}" "$entity") || exit $?
  local reader_name
  reader_name=$(security_key_reader_name "$reader_slot_number") || exit $?
  # as in init: the new pin goes to a 0600 temporary file next to the pin file
  # before the key is touched, and replaces the pin file only once the key has
  # taken it. printf, not echo: libp11 below 0.4.17 reads a trailing newline in
  # a pin-source file as part of the pin.
  local pin_tmp=''
  if [ $keep_pin = false ]; then
    pin_tmp=$(umask 077; mktemp "${entity_pin_file}.new.XXXXXX") && \
      printf '%s' "${pin}" > "${pin_tmp}"
    if [ $? != 0 ]; then
      rm -f "$pin_tmp"
      error "security_key_unblock_pin: could not write the new pin next to "\
"'$entity_pin_file'. nothing was tried on the security key." 1
    fi
  fi
  # quoted for eval: the reader name has spaces in it
  local reader_option=''
  [ -n "$reader_name" ] && reader_option='--reader "${reader_name}"'
  local unblock_output
  unblock_output=$(eval yubico-piv-tool ${reader_option} -a unblock-pin \
    -P '"${puk}"' -N '"${pin}"' 2>&1)
  local unblock_result=$?
  log_detailed "security_key_unblock_pin: yubico-piv-tool exited $unblock_result: $unblock_output"
  if [ $unblock_result != 0 ]; then
    rm -f "$pin_tmp"
    # yubico-piv-tool says "now N tries left" for a wrong puk, and that the puk
    # "is blocked" once none are left
    local puk_state
    local tries_left=$(printf '%s' "$unblock_output" | \
      sed -n 's/.*now \([0-9][0-9]*\) tries left.*/\1/p' | head -n 1)
    if [ -n "$tries_left" ]; then
      puk_state="the puk in '$entity_puk_file' was refused; $tries_left puk "\
"retries remain."
    elif printf '%s' "$unblock_output" | grep -qi 'blocked'; then
      puk_state="the puk is blocked; no puk retries remain."
    else
      puk_state="the number of puk retries left is not known; check it with "\
"'ykman piv info'. yubico-piv-tool said: $unblock_output"
    fi
    error "security_key_unblock_pin: the security key did not unblock the "\
"pin. $puk_state the pin file was left as it was and no further attempt was "\
"made. if the puk is lost or blocked, the last resort is a reset of the PIV "\
"application, which destroys its keys; see 'Reset PIV' in docs/yubikey.md." 1
  fi
  if [ -n "$pin_tmp" ] && ! mv "$pin_tmp" "$entity_pin_file"; then
    error "security_key_unblock_pin: the pin was unblocked and changed on the "\
"security key, but the pin file could not be replaced. the new pin is in "\
"'$pin_tmp'." 1
  fi
  echo "the pin of '$entity' is unblocked. the pin in '$entity_pin_file' is now set on the security key."
  log_detailed "security_key_unblock_pin: finished (keep_pin=$keep_pin, entity=$entity)"
}
security_key_unblock_pin_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
