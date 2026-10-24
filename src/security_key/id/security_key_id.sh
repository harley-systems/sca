security_key_id() {
  local security_key_type=''
  local device=''
  local OPTS=`getopt -o ht: --long help,security-key-type:,device: -n "sca security_key id" -- "$@"`
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
  log_detailed "security_key_id: started (security_key_type:'$security_key_type', device:'$device')"
  local current_security_key_id=''
  local reader_filter='.'
  [ "$security_key_type" = "yubikey" ] && reader_filter='[Yy]ubi[Kk]ey'
  local readers=$(security_key_list_readers "$reader_filter")
  log_detailed "security_key_id: readers with a card:'${readers}'"
  local device_found=false
  if ! [ -z "$readers" ]; then
    # there may be several readers with a card in them. each one is asked for its
    # own serial; asking ykman without naming a reader fails outright as soon as
    # more than one key is present.
    while IFS=$'\t' read -r reader_slot_number reader_name; do
      [ -z "$reader_slot_number" ] && continue
      log_detailed "security_key_id: reader_slot_number:'${reader_slot_number}' reader_name:'${reader_name}'"
      local current_security_key_id=''
      if [ "$security_key_type" = "yubikey" ] && command -v ykman &> /dev/null; then
        # For YubiKeys, use ykman to get the hardware serial (stable, doesn't change)
        # opensc-tool --serial returns CHUID which changes when certificates are uploaded
        local ykman_output=$(ykman --reader "$reader_name" info 2>&1)
        current_security_key_id=$(printf '%s\n' "$ykman_output" | grep -i "serial number" | awk '{print $3}')
        # the error is logged rather than dropped. discarding it turned a plain
        # "Multiple YubiKeys detected" into an empty serial, and an empty serial
        # makes every wait_for-gated command spin forever on a line it can never
        # match.
        [ -z "$current_security_key_id" ] && \
          log_detailed "security_key_id: ykman gave no serial for reader '${reader_name}':'${ykman_output}'"
        log_detailed "security_key_id: using ykman hardware serial"
      else
        # Fallback to opensc-tool for non-YubiKey devices
        current_security_key_id=$(opensc-tool --serial \
          --reader $reader_slot_number | cut -d ' ' -f 1,2,3,4,5,6 | tr ' ' '-')
      fi
      # a reader whose serial could not be read is reported as '-' rather than as
      # an empty field, so it cannot be mistaken for a key with a blank serial.
      [ -z "$current_security_key_id" ] && current_security_key_id='-'
      log_detailed "security_key_id: current_security_key_id:'${current_security_key_id}'"
      # with --device, only the key asked for is listed
      if [ -n "$device" ]; then
        [ "$current_security_key_id" != "$device" ] && continue
        device_found=true
      fi
      echo "$current_security_key_id $reader_slot_number"
    done <<< "$readers"
    # For YubiKeys: security_key_id is the hardware serial number (stable).
    # For other devices: security_key_id is the first 6 hex digits of the card serial.
  elif [ -z "$device" ]; then
    echo "- -"
  fi
  if [ -n "$device" ] && [ $device_found = false ]; then
    error "security_key_id: no security key with serial '$device' is attached." 1
  fi
  log_detailed "security_key_id: finished (security_key_type:'$security_key_type')"
}
security_key_id_help() {
  echo "
@@@HELP@@@
"
}
