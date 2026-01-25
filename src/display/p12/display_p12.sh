################################################################################
# Display PKCS#12 (.p12) bundle contents
#
# Shows certificates, key presence, and encryption info from a p12 file
#
# parameters
#   file
#     path to the .p12 file to display
#
display_p12() {
  local password=""
  local p12_file=""

  local OPTS=`getopt -o hp: --long help,password: -n "display p12" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca display p12 -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        display_p12_help
        return
        ;;
      -p | --password )
        password="$2"
        shift 2
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

  p12_file=$1
  log_detailed "display_p12: start (file=${p12_file})"

  # Validate file exists
  if [ -z "$p12_file" ]; then
    error "no p12 file specified. usage: sca display p12 <file>" 1
  fi

  if [ ! -f "$p12_file" ]; then
    error "file not found: ${p12_file}" 1
  fi

  # Prompt for password if not provided
  if [ -z "$password" ]; then
    read -s -p "Enter p12 password: " password
    echo
  fi

  # Get filename for display
  local filename=$(basename "$p12_file")

  echo "PKCS#12 Bundle: ${filename}"
  echo "========================================"
  echo ""

  # Get bundle info
  local info_output
  info_output=$(openssl pkcs12 -in "$p12_file" -info -noout -passin pass:"$password" 2>&1)
  if [ $? -ne 0 ]; then
    error "failed to read p12 file. check password." 1
  fi

  # Extract encryption info
  local mac_info=$(echo "$info_output" | grep "^MAC:" | head -1)
  local enc_info=$(echo "$info_output" | grep "PKCS7 Encrypted data:" | head -1)

  # Count certificates
  local cert_count=$(echo "$info_output" | grep -c "Certificate bag")
  local key_present=$(echo "$info_output" | grep -c "Shrouded Keybag")

  echo "Certificates (${cert_count}):"

  # Extract and display certificate details
  local cert_output
  cert_output=$(openssl pkcs12 -in "$p12_file" -nokeys -passin pass:"$password" -passout pass:"" 2>/dev/null)

  local cert_num=1
  while IFS= read -r line; do
    if [[ "$line" == "subject="* ]]; then
      local subject="${line#subject=}"
      # Extract CN from subject
      local cn=$(echo "$subject" | sed -n 's/.*CN = \([^,]*\).*/\1/p')
      if [ -z "$cn" ]; then
        cn=$(echo "$subject" | sed -n 's/.*CN=\([^,]*\).*/\1/p')
      fi
      [ -z "$cn" ] && cn="$subject"

      # Get expiry for this cert (next line after subject in our parsing)
      echo "  ${cert_num}. ${cn}"
      cert_num=$((cert_num + 1))
    fi
  done <<< "$(openssl pkcs12 -in "$p12_file" -nokeys -passin pass:"$password" -passout pass:"" 2>/dev/null | openssl x509 -noout -subject 2>/dev/null; \
             openssl pkcs12 -in "$p12_file" -nokeys -passin pass:"$password" -passout pass:"" -cacerts 2>/dev/null | while openssl x509 -noout -subject 2>/dev/null; do :; done)"

  # Simpler approach: just list all certs with their subjects and expiry
  echo ""
  echo "Certificate Details:"
  openssl pkcs12 -in "$p12_file" -nokeys -passin pass:"$password" -passout pass:"" 2>/dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' | \
    while openssl x509 -noout -subject -enddate 2>/dev/null; do :; done | \
    paste - - | \
    while IFS=$'\t' read -r subj exp; do
      local cn=$(echo "$subj" | sed -n 's/.*CN = \([^,]*\).*/\1/p')
      [ -z "$cn" ] && cn=$(echo "$subj" | sed -n 's/.*CN=\([^,]*\).*/\1/p')
      [ -z "$cn" ] && cn="${subj#subject=}"
      local expdate="${exp#notAfter=}"
      echo "  - ${cn}"
      echo "    Expires: ${expdate}"
    done

  echo ""
  if [ "$key_present" -gt 0 ]; then
    echo "Private Key: Present (encrypted)"
  else
    echo "Private Key: Not present"
  fi

  echo ""
  echo "Encryption:"
  if [ -n "$mac_info" ]; then
    echo "  ${mac_info}"
  fi
  if [ -n "$enc_info" ]; then
    local enc_method=$(echo "$enc_info" | sed 's/PKCS7 Encrypted data: /  /')
    echo "  ${enc_method}"
  fi

  log_detailed "display_p12: finish (file=${p12_file})"
}
display_p12_help() {
  echo "
@@@HELP@@@
  "
}
