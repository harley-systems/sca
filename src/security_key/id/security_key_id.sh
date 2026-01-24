security_key_id() {
  local security_key_type=''
  local OPTS=`getopt -o ht: --long help,security-key-type: -n "sca security_key id" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key id -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_id_help
        return
      ;;
      -t | --security-key-type )
        security_key_type=$2
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
  log_detailed "security_key_id: started (security_key_type:'$security_key_type')"
  local current_security_key_id=''
  local filter_readers_with_cards='| grep -P "^\d\s*Yes"'

  local filter_yubikey_readers=''
  [ "$security_key_type" = "yubikey" ] && filter_yubikey_readers=' | grep -i yubikey '
  local select_first_column=' | cut -c1 '
  local get_readers_command="opensc-tool --list-readers $filter_readers_with_cards $filter_yubikey_readers $select_first_column"
  local security_key_opensc_reader_slot_numbers=$(eval $get_readers_command)
  log_detailed "security_key_id: security_key_opensc_reader_slot_numbers:'${security_key_opensc_reader_slot_numbers}' "
  if ! [ -z "$security_key_opensc_reader_slot_numbers" ]; then
    # above command may return multiple slot numbers. we shall loop over
    # all security_key_opensc_reader_slot_numbers and extract all security_key_ids
    while read -r reader_slot_number; do
      log_detailed "security_key_id: reader_slot_number:'${reader_slot_number}'"
      local current_security_key_id=''
      if [ "$security_key_type" = "yubikey" ] && command -v ykman &> /dev/null; then
        # For YubiKeys, use ykman to get the hardware serial (stable, doesn't change)
        # opensc-tool --serial returns CHUID which changes when certificates are uploaded
        current_security_key_id=$(ykman info 2>/dev/null | grep -i "serial number" | awk '{print $3}')
        log_detailed "security_key_id: using ykman hardware serial"
      else
        # Fallback to opensc-tool for non-YubiKey devices
        current_security_key_id=$(opensc-tool --serial \
          --reader $reader_slot_number | cut -d ' ' -f 1,2,3,4,5,6 | tr ' ' '-')
      fi
      log_detailed "security_key_id: current_security_key_id:'${current_security_key_id}'"
      echo "$current_security_key_id $reader_slot_number"
    done <<< "$security_key_opensc_reader_slot_numbers"
    # For YubiKeys: security_key_id is the hardware serial number (stable).
    # For other devices: security_key_id is the first 6 hex digits of the card serial.
  else
    echo "- -"
  fi
  log_detailed "security_key_id: finished (security_key_type:'$security_key_type')"
}
security_key_id_help() {
  echo "
@@@HELP@@@
"
}
