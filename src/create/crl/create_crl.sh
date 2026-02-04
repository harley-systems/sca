################################################################################
# generate certificate revocation list (CRL) for a certificate authority
#
# parameters
#   entity
#       the entity for which to generate the CRL
#       allowed values are 'ca' and 'subca'
#
create_crl() {
  local OPTS=`getopt -o h --long help -n 'create crl' -- "$@"`
  if [ $? != 0 ] ; then
    error "failed parsing options. use sca create crl -h for help." 1;
  fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_crl_help
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
  local entity="$1"

  log_detailed "create_crl: start (entity='${entity}')"

  if [ "$entity" != "ca" ] && [ "$entity" != "subca" ]; then
    error "create_crl: invalid entity '${entity}'. allowed values are 'ca' and 'subca'." 1
  fi

  export OPENSSL_CONF="${sca_conf_folder}${entity}.ini"
  local entity_key_file=$(eval echo \$${entity}_key_file)
  local entity_crl_file=$(eval echo \$${entity}_crl_file)
  local entity_crl_serial_file=$(eval echo \$${entity}_crl_serial_file)
  local openssl_command=""
  local entity_pin=""

  # initialize CRL serial if needed
  if [ ! -f "$entity_crl_serial_file" ] || [ ! -s "$entity_crl_serial_file" ]; then
    mkdir -p "$(dirname "$entity_crl_serial_file")"
    echo "01" > "$entity_crl_serial_file"
    log_detailed "create_crl: initialized CRL serial file $entity_crl_serial_file"
  fi

  # check if the entity_key_file exists in the filesystem
  if [ -f "$entity_key_file" ]; then
    # use filesystem key to generate CRL
    openssl_command="$redirect_err openssl ca \
      -name $entity \
      -gencrl \
      -out $entity_crl_file \
      -keyfile $entity_key_file"
  else
    # check if the entity is configured to use a hardware security key
    local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
    if [ $entity_use_security_key = true ]; then
      local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
      local entity_pkcs11_id=$(eval echo \${${entity}_pkcs11_id})
      local security_key_opensc_reader_slot_number=$(security_key_wait_for $entity)
      readarray slot_map < <( p11tool --list-tokens | grep -oP "(?<=URL: ).*" )
      log_detailed "create_crl: slot_map retrieved. there are ${#slot_map[@]} items."
      log_detailed "create_crl: opensc reader slot number '${security_key_opensc_reader_slot_number}' mapped to pkcs11 id is '${slot_map[${security_key_opensc_reader_slot_number}]::-1}'."
      local mapped_slot_id="${slot_map[${security_key_opensc_reader_slot_number}]::-1}"
      local entity_pin=$(get_yubikey_pin_parameter $entity)
      local pin_uri_fragment=""
      [ -n "$entity_pin" ] && pin_uri_fragment=";pin-value=${entity_pin}"
      local pkcs11_keyfile="pkcs11:id=%${entity_pkcs11_id};type=private${pin_uri_fragment}"
      export PKCS11_MODULE_PATH="${opensc_pkcs11_module}"
      warn_yubikey_touch_expected $entity
      openssl_command="$redirect_err openssl ca \
        -name $entity \
        -gencrl \
        -out $entity_crl_file \
        -engine pkcs11 \
        -keyform engine \
        -keyfile \"${pkcs11_keyfile}\""
    else
      error "create_crl: Unable to find key file $entity_key_file for"\
" $entity entity" 1
    fi
  fi

  log_verbose "$openssl_command"
  if [ -n "$entity_pin" ]; then
    eval "$openssl_command" <<< "$entity_pin"
  else
    eval "$openssl_command"
  fi
  [ ! "$?" = "0" ] && error "create_crl: error while running the openssl command." 1

  echo "CRL generated: $entity_crl_file"

  log_detailed "create_crl: finish (entity='${entity}')"
}

create_crl_help() {
  echo "
@@@HELP@@@
"
}
