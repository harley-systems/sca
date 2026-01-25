security_key_verify() {
  local OPTS=$(getopt -o h --long help -n "sca security_key verify" -- "$@")
  if [ $? != 0 ]; then error "failed parsing options. use sca security_key verify -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_verify_help
        return
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
  log_detailed "security_key_verify: started (entity='$entity')"

  # Validate entity
  local allowed_values=(ca subca user service host)
  if [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]]; then
    error "security_key_verify: invalid entity '$entity'. Supported: ca, subca, user, service, host" 1
  fi

  # Check if ykcs11 module is available
  local ykcs11_module="/usr/lib/x86_64-linux-gnu/libykcs11.so"
  if [ ! -f "$ykcs11_module" ]; then
    error "ykcs11 module not found at $ykcs11_module. Install with: sudo apt install ykcs11" 1
  fi

  # Check if pkcs11-tool is available
  if ! command -v pkcs11-tool &> /dev/null; then
    error "pkcs11-tool not found. Install with: sudo apt install opensc" 1
  fi

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

  # Attempt to sign with the provided PIN
  local sign_output
  sign_output=$(pkcs11-tool --module "$ykcs11_module" --sign --mechanism RSA-PKCS \
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
    else
      echo "  Details:    $sign_output"
    fi
    return 1
  fi

  log_detailed "security_key_verify: finished (entity='$entity')"
}
security_key_verify_help() {
  echo "
@@@HELP@@@
"
}
