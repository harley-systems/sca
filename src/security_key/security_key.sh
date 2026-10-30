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
    get_crt|id|info|init|unblock_pin|upload|verify|wait_for )
      eval security_key_$security_key_command "$@"
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$security_key_command' for security_key_command (first) argument.
        supported values are 'get_crt', 'id', 'info', 'init', 'unblock_pin', 'upload', 'verify',
        and 'wait_for'.
        use sca security_key -h for help.
____EOM
      error "$message" 1
      ;;
  esac

  log_detailed "security_key: finished (security_key_command=${security_key_command})"
}
security_key_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
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
  # Maps ykcs11 PKCS#11 IDs to YubiKey PIV slot IDs
  local pkcs11_slot_number=$1
  local yubikey_slot_id=0
  case "$pkcs11_slot_number" in
    "01" )
      yubikey_slot_id="9a"  # PIV Authentication
    ;;
    "02" )
      yubikey_slot_id="9c"  # Digital Signature
    ;;
    "03" )
      yubikey_slot_id="9d"  # Key Management
    ;;
    "04" )
      yubikey_slot_id="9e"  # Card Authentication
    ;;
    "05" )
      yubikey_slot_id="82"  # Retired Key 1
    ;;
    "06" )
      yubikey_slot_id="83"  # Retired Key 2
    ;;
    "07" )
      yubikey_slot_id="84"  # Retired Key 3
    ;;
    "08" )
      yubikey_slot_id="85"  # Retired Key 4
    ;;
    "09" )
      yubikey_slot_id="86"  # Retired Key 5
    ;;
    "0a" )
      yubikey_slot_id="87"  # Retired Key 6
    ;;
    "0b" )
      yubikey_slot_id="88"  # Retired Key 7
    ;;
    "0c" )
      yubikey_slot_id="89"  # Retired Key 8
    ;;
    "0d" )
      yubikey_slot_id="8a"  # Retired Key 9
    ;;
    "0e" )
      yubikey_slot_id="8b"  # Retired Key 10
    ;;
    "0f" )
      yubikey_slot_id="8c"  # Retired Key 11
    ;;
    "10" )
      yubikey_slot_id="8d"  # Retired Key 12
    ;;
    "11" )
      yubikey_slot_id="8e"  # Retired Key 13
    ;;
    "12" )
      yubikey_slot_id="8f"  # Retired Key 14
    ;;
    "13" )
      yubikey_slot_id="90"  # Retired Key 15
    ;;
    "14" )
      yubikey_slot_id="91"  # Retired Key 16
    ;;
    "15" )
      yubikey_slot_id="92"  # Retired Key 17
    ;;
    "16" )
      yubikey_slot_id="93"  # Retired Key 18
    ;;
    "17" )
      yubikey_slot_id="94"  # Retired Key 19
    ;;
    "18" )
      yubikey_slot_id="95"  # Retired Key 20
    ;;
    "19" )
      yubikey_slot_id="f9"  # PIV Attestation
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
  local pin=""
  local entity_yubikey_pin_policy=$(eval echo \$${entity}_yubikey_pin_policy)
  # if pin policy requires PIN, read it from file and return the raw PIN
  if [ "$entity_yubikey_pin_policy" = "always" ] || [ "$entity_yubikey_pin_policy" = "once" ]; then
    local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
    if [ -f "$entity_pin_file" ]; then
      pin=$(cat "${entity_pin_file}")
    fi
  fi
  echo "$pin"
}
# the path of the PIN file, for a pin-source= attribute in a PKCS#11 URI.
# the PIN itself must never go in the URI: a URI is a command-line argument,
# so the PIN would be readable in ps for as long as the call runs.
# gated on the same pin policy as get_yubikey_pin_parameter, so a key that
# needs no PIN still gets no attribute.
get_yubikey_pin_file_parameter() {
  local entity="$1"
  local pin_file=""
  local entity_yubikey_pin_policy=$(eval echo \$${entity}_yubikey_pin_policy)
  if [ "$entity_yubikey_pin_policy" = "always" ] || [ "$entity_yubikey_pin_policy" = "once" ]; then
    local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
    # -s, not -f: an empty PIN file means "no PIN" by the convention security
    # key verify already follows. Pointing pin-source at it would make openssl
    # log in with an empty PIN and fail, where returning nothing leaves openssl
    # to prompt as it did before pin-source was used here.
    [ -s "$entity_pin_file" ] && pin_file="$entity_pin_file"
  fi
  echo "$pin_file"
}
warn_yubikey_touch_expected() {
  local entity=$1
  local entity_yubikey_touch_policy=$(eval echo \$${entity}_yubikey_touch_policy)
    log_detailed "yubikey touch policiy for entity ${entity} is set to ${entity_yubikey_touch_policy}."
  # echo joins its arguments with a space, so the fragment must not end in one
  # too -- that is where the stray double space in this prompt came from.
  [ "$entity_yubikey_touch_policy" = "always" ] && echo "Please, touch the key to" \
    "confirm usage of the $entity key."
}
################################################################################
# the readers that hold a card, one per line: "<opensc reader number><TAB><name>"
#
# the reader NAME is carried alongside the number, not discarded: it is the only
# handle that ties an opensc reader to a particular key. the Name column offset
# is taken from the header row rather than assumed, because the Features column
# between them is usually empty but not always.
#
# parameters
#   reader_filter - optional regex the reader name has to match
security_key_list_readers() {
  local reader_filter="${1:-.}"
  local readers_output=$(opensc-tool --list-readers 2>&1)
  log_detailed "security_key_list_readers: opensc readers:'${readers_output}'"
  printf '%s\n' "$readers_output" | awk -v want="$reader_filter" '
    /^Nr\./ { namecol = index($0, "Name"); next }
    namecol && /^[0-9]+[[:space:]]+Yes/ {
      name = substr($0, namecol)
      sub(/[[:space:]]+$/, "", name)
      if (name ~ want) printf "%s\t%s\n", $1, name
    }'
}
################################################################################
# the name of the reader with the given opensc reader number, in the form
# yubico-piv-tool --reader takes. prints nothing for an empty reader number.
#
# yubico-piv-tool connects to the first reader whose name CONTAINS the one it is
# given. where one attached reader's name is part of another's (macOS names a
# second key "... CCID 01" next to a first key's "... CCID"), it cannot be told
# apart, and that is refused rather than left to act on whichever comes first.
#
# parameters
#   reader_slot_number - opensc reader number, as printed by security_key id
security_key_reader_name() {
  local reader_slot_number="$1"
  [ -z "$reader_slot_number" ] && return 0
  local readers=$(security_key_list_readers)
  local reader_name=$(printf '%s\n' "$readers" | \
    awk -F'\t' -v nr="$reader_slot_number" '$1 == nr { print $2; exit }')
  [ -z "$reader_name" ] && \
    error "security_key_reader_name: no card found in reader '$reader_slot_number'." 1
  local wanted=$(printf '%s' "$reader_name" | tr '[:upper:]' '[:lower:]')
  local reader_number other_name
  while IFS=$'\t' read -r reader_number other_name; do
    [ -z "$reader_number" ] || [ "$reader_number" = "$reader_slot_number" ] && continue
    other_name=$(printf '%s' "$other_name" | tr '[:upper:]' '[:lower:]')
    if [[ "$other_name" == *"$wanted"* ]]; then
      error "security_key_reader_name: the reader '$reader_name' can not be "\
"told apart from another attached reader whose name contains it, so "\
"yubico-piv-tool could act on either key. attach only the key you want to "\
"use." 1
    fi
  done <<< "$readers"
  log_detailed "security_key_reader_name: reader '$reader_slot_number' is '$reader_name'"
  echo "$reader_name"
}
################################################################################
# selects the yubikey a command that does not wait for a key acts on, and prints
# "<serial><TAB><reader name>" for it.
#
# with no device asked for, behaviour with a single key is what it always was:
# no key found prints nothing, leaving the tool to report it; one key is that
# key; more than one is refused with the attached serials listed, rather than
# letting the tool act on whichever it finds first.
#
# parameters
#   device - the serial asked for with --device, or empty
security_key_select_device() {
  local device="$1"
  local ids=$(security_key_id --security-key-type yubikey)
  local attached=$(printf '%s\n' "$ids" | awk '$2 != "-" && $2 != ""')
  local serials=$(printf '%s\n' "$attached" | awk 'NF { printf "%s%s", sep, $1; sep=", " }')
  log_detailed "security_key_select_device: device:'$device' attached:'$serials'"
  local selected=''
  if [ -z "$device" ]; then
    local count=$(printf '%s\n' "$attached" | awk 'NF' | wc -l)
    [ "$count" -eq 0 ] && return 0
    if [ "$count" -gt 1 ]; then
      error "more than one security key is attached (serials: $serials). "\
"choose one with --device SERIAL." 1
    fi
    selected="$attached"
  else
    selected=$(printf '%s\n' "$attached" | awk -v want="$device" '$1 == want { print; exit }')
    if [ -z "$selected" ]; then
      error "no security key with serial '$device' is attached "\
"(attached: ${serials:-none})." 1
    fi
  fi
  local serial="${selected%% *}"
  local reader_slot_number="${selected##* }"
  local reader_name
  reader_name=$(security_key_reader_name "$reader_slot_number") || exit $?
  printf '%s\t%s\n' "$serial" "$reader_name"
}
