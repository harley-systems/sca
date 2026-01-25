security_key_info() {
  local OPTS=$(getopt -o h --long help -n "sca security_key info" -- "$@")
  if [ $? != 0 ]; then error "failed parsing options. use sca security_key info -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_info_help
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

  log_detailed "security_key_info: started"

  # Check if yubico-piv-tool is available
  if ! command -v yubico-piv-tool &> /dev/null; then
    error "yubico-piv-tool not found. Install with: sudo apt install yubico-piv-tool" 1
  fi

  # Get status from yubico-piv-tool
  local status_output
  status_output=$(yubico-piv-tool -a status 2>&1)
  if [ $? -ne 0 ]; then
    if echo "$status_output" | grep -q "Failed to connect"; then
      error "No YubiKey detected. Please insert a YubiKey." 1
    fi
    error "Failed to read YubiKey: $status_output" 1
  fi

  echo "YubiKey PIV Slot Information"
  echo "============================"
  echo ""

  # Slots to check (standard + first retired slot commonly used for CA)
  local slots=("9a:PIV Authentication" "9c:Digital Signature" "9d:Key Management" "9e:Card Authentication" "82:Retired Key 1 (CA)")

  for slot_info in "${slots[@]}"; do
    local slot="${slot_info%%:*}"
    local slot_name="${slot_info#*:}"

    # Try to read certificate from slot
    local cert_output
    cert_output=$(yubico-piv-tool -a read-certificate -s "$slot" 2>&1)

    if echo "$cert_output" | grep -q "Failed\|error"; then
      continue
    fi

    # Parse certificate details
    local subject not_after key_algo
    subject=$(echo "$cert_output" | openssl x509 -noout -subject -nameopt multiline 2>/dev/null | grep "commonName" | sed 's/.*= //')
    [ -z "$subject" ] && subject=$(echo "$cert_output" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//' | cut -c1-50)
    not_after=$(echo "$cert_output" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    key_algo=$(echo "$cert_output" | openssl x509 -noout -text 2>/dev/null | grep "Public Key Algorithm" | head -1 | sed 's/.*: //')

    echo "Slot $slot ($slot_name):"
    echo "  Subject:   $subject"
    echo "  Expires:   $not_after"
    echo "  Algorithm: $key_algo"
    echo ""
  done

  echo "Note: Use 'sca security_key verify <entity>' to test if private keys are present."

  log_detailed "security_key_info: finished"
}
security_key_info_help() {
  echo "
@@@HELP@@@
"
}
