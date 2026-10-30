security_key_verify() {
  local device=''
  local OPTS=$(getopt -o h --long help,device: -n "sca security_key verify" -- "$@")
  if [ $? != 0 ]; then error "failed parsing options. use sca security_key verify -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_verify_help
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

  local entity=$1
  log_detailed "security_key_verify: started (entity='$entity', device:'$device')"

  # Validate entity
  local allowed_values=(ca subca user service host)
  if [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]]; then
    error "security_key_verify: invalid entity '$entity'. Supported: ca, subca, user, service, host" 1
  fi

  # Resolve the ykcs11 module: the configured ykcs11_module wins; if that file
  # is missing, look in a few common install locations before giving up
  local configured_ykcs11_module="${ykcs11_module:-$ykcs11_module_default}"
  local ykcs11_module="$configured_ykcs11_module"
  if [ ! -f "$ykcs11_module" ]; then
    log_detailed "security_key_verify: ykcs11 module not found at configured path '$configured_ykcs11_module', searching common locations"
    ykcs11_module=""
    local candidate
    for candidate in \
      /usr/lib/*-linux-gnu/libykcs11.so /usr/lib/*-linux-gnu/libykcs11.so.* \
      /usr/lib64/libykcs11.so /usr/lib64/libykcs11.so.* \
      /usr/lib/libykcs11.so /usr/lib/libykcs11.so.* \
      /usr/local/lib/libykcs11.so /usr/local/lib/libykcs11.so.* \
      /usr/local/lib/libykcs11.dylib /opt/homebrew/lib/libykcs11.dylib \
      ~/.nix-profile/lib/libykcs11.so /run/current-system/sw/lib/libykcs11.so; do
      if [ -f "$candidate" ]; then
        ykcs11_module="$candidate"
        break
      fi
    done
    if [ -z "$ykcs11_module" ]; then
      error "ykcs11 module not found at '$configured_ykcs11_module' or in common locations. Install the YubiKey PKCS#11 module (ykcs11, part of yubico-piv-tool) and set ykcs11_module in ${config_file:-~/.sca/config/sca.config} to its full path." 1
    fi
  fi
  log_detailed "security_key_verify: using ykcs11 module '$ykcs11_module'"

  # Check if pkcs11-tool is available
  if ! command -v pkcs11-tool &> /dev/null; then
    error "pkcs11-tool not found. Install with: sudo apt install opensc" 1
  fi

  # pkcs11-tool signs with the first token it finds unless told which one, so
  # more than one key attached is refused unless --device names one. ykcs11
  # labels each token "YubiKey PIV #<serial>", and that label is how the named
  # key is selected. with a single key and no --device nothing is added, as
  # before.
  local selected_device
  selected_device=$(security_key_select_device "$device") || exit $?
  local device_serial="${selected_device%%$'\t'*}"
  local token_option=()
  local ykman_device_option=''
  if [ -n "$device" ]; then
    [[ "$device_serial" =~ ^[0-9]+$ ]] || \
      error "security_key_verify: the key '$device' has no YubiKey hardware "\
"serial to select it by. check that ykman is installed." 1
    token_option=(--token-label "YubiKey PIV #${device_serial}")
    ykman_device_option="--device ${device_serial} "
  fi
  log_detailed "security_key_verify: selected device '${device_serial}'"

  # Get the PKCS#11 ID for the entity from configuration
  local entity_pkcs11_id=$(eval echo \$${entity}_pkcs11_id)
  if [ -z "$entity_pkcs11_id" ]; then
    # Fall back to default slot mappings
    case "$entity" in
      ca)
        entity_pkcs11_id="05"  # slot 82
        ;;
      subca)
        entity_pkcs11_id="02"  # slot 9c
        ;;
      user)
        entity_pkcs11_id="01"  # slot 9a
        ;;
      service|host)
        entity_pkcs11_id="03"  # slot 9d
        ;;
    esac
  fi

  # Get YubiKey slot for display
  local yubikey_slot=$(map_pkcs11_id_to_yubikey_slot_id "$entity_pkcs11_id")

  echo "Verifying private key for '$entity' in slot $yubikey_slot (PKCS#11 ID: $entity_pkcs11_id)..."

  # Check for PIN file first, otherwise prompt
  local pin=""
  local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)

  if [ -n "$entity_pin_file" ] && [ -f "$entity_pin_file" ]; then
    pin=$(cat "$entity_pin_file")
    if [ -n "$pin" ]; then
      log_detailed "security_key_verify: using PIN from file $entity_pin_file"
    fi
  fi

  # If no PIN from file, prompt interactively
  if [ -z "$pin" ]; then
    read -s -p "Enter YubiKey PIN: " pin
    echo ""
  fi

  if [ -z "$pin" ]; then
    error "PIN is required" 1
  fi

  # Create temporary test file
  local test_file=$(mktemp)
  local sig_file=$(mktemp)
  echo "sca-verify-test-$(date +%s)" > "$test_file"

  # say so before blocking on the card. every other command that performs a
  # private key operation already calls this; verify did not, so the command
  # simply stopped with no hint that it was waiting for a finger.
  warn_yubikey_touch_expected $entity

  # Attempt to sign with the provided PIN
  local sign_output
  sign_output=$(pkcs11-tool --module "$ykcs11_module" "${token_option[@]}" \
    --sign --mechanism RSA-PKCS \
    --id "$entity_pkcs11_id" --pin "$pin" -i "$test_file" -o "$sig_file" 2>&1)
  local sign_result=$?

  # Clean up test file
  rm -f "$test_file"

  if [ $sign_result -eq 0 ] && [ -f "$sig_file" ] && [ -s "$sig_file" ]; then
    local sig_size=$(stat -c%s "$sig_file" 2>/dev/null || stat -f%z "$sig_file" 2>/dev/null)
    rm -f "$sig_file"
    echo ""
    echo "SUCCESS: Private key for '$entity' is present and working."
    echo "  Slot:           $yubikey_slot"
    echo "  PKCS#11 ID:     $entity_pkcs11_id"
    echo "  Signature size: $sig_size bytes"
  else
    rm -f "$sig_file"
    echo ""
    echo "FAILED: Could not sign with private key for '$entity'."
    echo "  Slot:       $yubikey_slot"
    echo "  PKCS#11 ID: $entity_pkcs11_id"
    if echo "$sign_output" | grep -q "CKR_KEY_HANDLE_INVALID\|no key"; then
      echo "  Reason:     No private key found in slot"
    elif echo "$sign_output" | grep -q "CKR_PIN"; then
      echo "  Reason:     PIN error (wrong PIN or PIN blocked)"
      echo "              if the PIN is blocked, recover it with the stored PUK:"
      echo "              sca security_key unblock_pin ${ykman_device_option}$entity"
    elif echo "$sign_output" | grep -q "CKR_USER_NOT_LOGGED_IN"; then
      # ykcs11 reports an un-confirmed touch as CKR_USER_NOT_LOGGED_IN, which
      # reads like a PIN or login fault and sends people off changing PIN
      # policies. on a slot with touch-policy always or cached it is far more
      # often a touch that was never given.
      echo "  Reason:     the key did not confirm the operation"
      echo "              on a slot with touch-policy 'always' or 'cached' this"
      echo "              is usually a touch that was not given, rather than a"
      echo "              PIN problem -- ykcs11 reports both the same way."
      echo "              check with: ykman ${ykman_device_option}piv keys info $yubikey_slot"
    else
      echo "  Details:    $sign_output"
    fi
    return 1
  fi

  log_detailed "security_key_verify: finished (entity='$entity')"
}
security_key_verify_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
