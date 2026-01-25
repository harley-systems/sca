################################################################################
# inspect security document by outputing it in readable form to standard output
#
# parameters
#   entity
#     the entity for which to display the document
#     allowed values are 'ca' 'user' 'host' and 'service'
#
display_crt() {
  local from_disk=false
  local from_security_key=false
  local OPTS=`getopt -o h --long help,from-disk,from-security-key -n "display crt" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca display crt -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        display_crt_help
        return
        ;;
      --from-disk )
        from_disk=true
        shift
        ;;
      --from-security-key )
        from_security_key=true
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
  local entity=$1
  local entity_id=$2
  local old_entity
  local new_entity
  log_detailed "display_crt: start (entity=${entity}, entity_id=${entity_id}, from_disk=${from_disk}, from_security_key=${from_security_key})"
  local current_entity_id=$(get_current_entity_id $entity)
  log_detailed "display_crt: current_entity_id $current_entity_id"
  old_entity=''
  if [[ ! -z "$entity_id" ]] && [[ "$entity_id" != $current_entity_id ]]; then
    old_entity=$(config_get $entity)
    old_entity="${old_entity//[$'\t\r\n']}"
    #old_entity=${old_entity@Q}
    log_detailed "display_crt: old_entity saved ${old_entity}"
    log_detailed "display_crt: temporarily setting configuration for ${entity} to ${new_entity}"
    config_set $entity ${entity_id}
  fi

  # Determine source: security key or disk
  local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
  local use_security_key=false

  if [ "$from_security_key" = true ]; then
    use_security_key=true
  elif [ "$from_disk" = true ]; then
    use_security_key=false
  elif [ "$entity_use_security_key" = true ]; then
    use_security_key=true
  fi

  if [ "$use_security_key" = true ]; then
    # Wait for security key to be inserted
    log_detailed "display_crt: waiting for security key for $entity"
    security_key_wait_for "$entity"

    # Read certificate directly from YubiKey
    local entity_pkcs11_id=$(eval echo \$${entity}_pkcs11_id)
    local yubikey_slot=$(map_pkcs11_id_to_yubikey_slot_id "$entity_pkcs11_id")
    log_detailed "display_crt: reading from security key slot $yubikey_slot"
    local cert_pem
    cert_pem=$(yubico-piv-tool -a read-certificate -s "$yubikey_slot" 2>&1)
    if echo "$cert_pem" | grep -q "Failed\|error"; then
      error "display_crt: failed to read certificate from security key slot $yubikey_slot: $cert_pem" 1
    fi
    echo "$cert_pem" | openssl x509 -text
  else
    # Read from disk
    local entity_crt_file=$(eval echo \${${entity}_crt_file})
    if ! [ -f "$entity_crt_file" ]; then
      error "display_crt: certificate file not found: $entity_crt_file" 1
    fi
    openssl x509 -text < "$entity_crt_file"
  fi

  if ! [ -z "$old_entity" ]; then
    log_detailed "display_crt: setting entity back for ${entity} to ${old_entity}"
    config_set ${entity} ${old_entity}
  fi

  log_detailed "display_crt: finish (entity=${entity}, entity_id=${entity_id}, old_entity_id=$old_entity_id)"
}
display_crt_help() {
    echo "
@@@HELP@@@
  "
}
