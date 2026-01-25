################################################################################
# manage hardware tokens
security_key() {
  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      security_key_help
      return
      ;;
  esac

  local security_key_command=$1
  shift
  log_detailed "security_key: start (security_key_command=${security_key_command})"
  case "$security_key_command" in
    get_crt|id|info|init|upload|verify|wait_for )
      eval security_key_$security_key_command "$@"
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$security_key_command' for security_key_command (first) argument.
        supported values are 'get_crt', 'id', 'info', 'init', 'upload', 'verify', and 'wait_for'.
        use sca security_key -h for help.
____EOM
      error "$message" 1
      ;;
  esac

  log_detailed "security_key: finished (security_key_command=${security_key_command})"
}
security_key_help() {
  echo '
@@@HELP@@@
'
}
###############################################################################
# for given yubikey slot id, the function will return it's corresponding
# pkcs11 slot number
#
# parameters
#   yubikey_slot_id       - single byte hex number
#                            "9a", "9c", "9d", "9e", "82",
#                            "83", "84", "85", "86", "87", "88",
#                            "89", "8a", "8b", "8c", "8d", "8e",
#                            "8f", "90", "91", "92", "93", "94",
#                            "95", "f9")
# 9a is for PIV Authentication
# 9c is for Digital Signature (PIN always checked)
# 9d is for Key Management
# 9e is for Card Authentication (PIN never checked)
# 82-95 is for Retired Key Management
# f9 is for Attestation
# mapping between pkcs slot number and yubico slot number
# 0  - ??
# 1  - 9e
# 2  - 9c
# 3  - ??
# ----------- from 4 and above, yubikey slot is derived from id as: 0x81 + id
# 4  - 82
# 5  - 83
# ...
# 23 - 95
# 24 - f9 ??
map_yubikey_slot_id_to_pkcs11_slot_number () {
  local yubikey_slot_id=$1
  local pkcs11_slot_number=0
  case "$yubikey_slot_id" in
    "9a" | "9A" )
      pkcs11_slot_number="00"
    ;;
    "9c" | "9C" )
      pkcs11_slot_number="02"
    ;;
    "9d" | "9D" )
      pkcs11_slot_number="03"
    ;;
    "9e" | "9E" )
      pkcs11_slot_number="01"
    ;;
    "82" )
      pkcs11_slot_number="04"
    ;;
    "83" )
      pkcs11_slot_number="05"
    ;;
    "84" )
      pkcs11_slot_number="06"
    ;;
    "85" )
      pkcs11_slot_number="07"
    ;;
    "86" )
      pkcs11_slot_number="08"
    ;;
    "87" )
      pkcs11_slot_number="09"
    ;;
    "88" )
      pkcs11_slot_number="10"
    ;;
    "89" )
      pkcs11_slot_number="11"
    ;;
    "8a" | "8A" )
      pkcs11_slot_number="12"
    ;;
    "8b" | "8B" )
      pkcs11_slot_number="13"
    ;;
    "8c" | "8C" )
      pkcs11_slot_number="14"
    ;;
    "8d" | "8D" )
      pkcs11_slot_number="15"
    ;;
    "8e" | "8E" )
      pkcs11_slot_number="16"
    ;;
    "8f" | "8F" )
      pkcs11_slot_number="17"
    ;;
    "90" )
      pkcs11_slot_number="18"
    ;;
    "91" )
      pkcs11_slot_number="19"
    ;;
    "92" )
      pkcs11_slot_number="20"
    ;;
    "93" )
      pkcs11_slot_number="21"
    ;;
    "94" )
      pkcs11_slot_number="22"
    ;;
    "95" )
      pkcs11_slot_number="23"
    ;;
    "f9" | "F9" )
      pkcs11_slot_number="24"
    ;;
    * )
      error "map_yubikey_slot_id_to_pkcs11_slot_number: unknown yubikey slot number $yubikey_slot_number." 1
    ;;
  esac
  echo $pkcs11_slot_number
}
map_pkcs11_id_to_yubikey_slot_id () {
  local pkcs11_slot_number=$1
  local yubikey_slot_id=0
  case "$pkcs11_slot_number" in
    "00" )
      yubikey_slot_id="9a"
    ;;
    "02" )
      yubikey_slot_id="9c"
    ;;
    "03" )
      yubikey_slot_id="9d"
    ;;
    "01" )
      yubikey_slot_id="9e"
    ;;
    "04" )
      yubikey_slot_id="82"
    ;;
    "05" )
      yubikey_slot_id="83"
    ;;
    "06" )
      yubikey_slot_id="84"
    ;;
    "07" )
      yubikey_slot_id="85"
    ;;
    "08" )
      yubikey_slot_id="86"
    ;;
    "09" )
      yubikey_slot_id="87"
    ;;
    "10" )
      yubikey_slot_id="88"
    ;;
    "11" )
      yubikey_slot_id="89"
    ;;
    "12" )
      yubikey_slot_id="8a"
    ;;
    "13" )
      yubikey_slot_id="8b"
    ;;
    "14" )
      yubikey_slot_id="8c"
    ;;
    "15" )
      yubikey_slot_id="8d"
    ;;
    "16"  )
      yubikey_slot_id="8e"
    ;;
    "17"  )
      yubikey_slot_id="8f"
    ;;
    "18" )
      yubikey_slot_id="90"
    ;;
    "19" )
      yubikey_slot_id="91"
    ;;
    "20" )
      yubikey_slot_id="92"
    ;;
    "21" )
      yubikey_slot_id="93"
    ;;
    "22" )
      yubikey_slot_id="94"
    ;;
    "23" )
      yubikey_slot_id="95"
    ;;
    "24" )
      yubikey_slot_id="F9"
    ;;
    * )
      error "map_pkcs11_slot_number_to_yubikey_slot_id: unknown pkcs11 slot number $pkcs11_slot_number." 1
    ;;
  esac
  echo $yubikey_slot_id
}
################################################################################
#
get_yubikey_pin_parameter() {
  local entity="$1"
  local apply_pin=""
  local entity_yubikey_pin_policy=$(eval echo \$${entity}_yubikey_pin_policy)
  # TODO: implement that in case of yubikey if pkcs11 key id is 2 then PIN always
  # checked - according to yubikey documentation
  if [ $entity_yubikey_pin_policy = true ]; then
    local entity_pin_file=$(eval echo \$${entity}_pin_file)
    if [ -f "$entity_pin_file" ]; then
      local pin=`cat ${entity_pin_file}`
      apply_pin="
      -passin pass:$pin"
    fi
  fi
  echo $apply_pin
}
warn_yubikey_touch_expected() {
  local entity=$1
  local entity_yubikey_touch_policy=$(eval echo \$${entity}_yubikey_touch_policy)
    log_detailed "yubikey touch policiy for entity ${entity} is set to ${entity_yubikey_touch_policy}."
  [ "$entity_yubikey_touch_policy" = "always" ] && echo "Please, touch the key to " \
    "confirm usage of the $entity key."
}
