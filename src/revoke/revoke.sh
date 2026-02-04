################################################################################
# revoke a certificate and regenerate the CRL
#
# parameters
#   entity
#     the entity whose certificate to revoke
#     allowed values are 'subca' 'host' 'service' 'user'
#   sign_by_entity
#     the entity that signed the certificate being revoked.
#     optional. specified under option -s or --sign-by .
#     if not set, default resolves to subca unless entity is 'subca'. in that
#     case the default value for sign_by_entity parameter is 'ca'.
#
revoke() {

  # read the options
  local OPTS=`getopt -o hs: --long help,sign-by: -n 'revoke' -- "$@"`
  local sign_by_entity
  if [ $? != 0 ] ; then error "failed parsing options. use sca revoke -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        revoke_help
        return
        ;;
      -s | --sign-by)
        sign_by_entity=$2
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

  # read the parameters
  local entity=$1

  if [ -z "$entity" ]; then
    error "revoke: entity argument is required. use sca revoke -h for help." 1
  fi

  if [ -z "$sign_by_entity" ]; then
    [[ $entity == subca ]] && sign_by_entity=ca || sign_by_entity=subca
  fi
  log_detailed "revoke: start (entity=${entity}, sign_by_entity=${sign_by_entity})"

  export OPENSSL_CONF="${sca_conf_folder}${sign_by_entity}.ini"
  local sign_by_entity_key_file=$(eval echo \$${sign_by_entity}_key_file)
  local entity_crt_file=$(eval echo \${${entity}_crt_file})
  local openssl_command=""
  local entity_pin=""

  # verify certificate file exists
  if [ ! -f "$entity_crt_file" ]; then
    error "revoke: certificate file ($entity_crt_file) for entity "\
"'$entity' not found." 1
  fi

  # check if the sign_by_entity_key_file exists in the filesystem
  if [ -f "$sign_by_entity_key_file" ]; then
    openssl_command="$redirect_err openssl ca \
      -name $sign_by_entity \
      -revoke $entity_crt_file \
      -keyfile $sign_by_entity_key_file"
  else
    # check if the signing entity is configured to use a hardware security key
    local sign_by_entity_use_security_key=$(eval echo \$${sign_by_entity}_use_security_key)
    if [ $sign_by_entity_use_security_key = true ]; then
      local sign_by_entity_security_key_type=$(eval echo \$${sign_by_entity}_security_key_type)
      local sign_by_entity_pkcs11_id=$(eval echo \${${sign_by_entity}_pkcs11_id})
      local security_key_opensc_reader_slot_number=$(security_key_wait_for $sign_by_entity)
      readarray slot_map < <( p11tool --list-tokens | grep -oP "(?<=URL: ).*" )
      log_detailed "revoke: slot_map retrieved. there are ${#slot_map[@]} items."
      log_detailed "revoke: opensc reader slot number '${security_key_opensc_reader_slot_number}' mapped to pkcs11 id is '${slot_map[${security_key_opensc_reader_slot_number}]::-1}'."
      local mapped_slot_id="${slot_map[${security_key_opensc_reader_slot_number}]::-1}"
      local entity_pin=$(get_yubikey_pin_parameter $sign_by_entity)
      local pin_uri_fragment=""
      [ -n "$entity_pin" ] && pin_uri_fragment=";pin-value=${entity_pin}"
      local pkcs11_keyfile="pkcs11:id=%${sign_by_entity_pkcs11_id};type=private${pin_uri_fragment}"
      export PKCS11_MODULE_PATH="${opensc_pkcs11_module}"
      warn_yubikey_touch_expected $sign_by_entity
      openssl_command="$redirect_err openssl ca \
        -name $sign_by_entity \
        -revoke $entity_crt_file \
        -engine pkcs11 \
        -keyform engine \
        -keyfile \"${pkcs11_keyfile}\""
    else
      error "revoke: Unable to find key file $sign_by_entity_key_file for"\
" $sign_by_entity entity" 1
    fi
  fi

  log_verbose "$openssl_command"
  if [ -n "$entity_pin" ]; then
    eval "$openssl_command" <<< "$entity_pin"
  else
    eval "$openssl_command"
  fi
  [ ! "$?" = "0" ] && error "revoke: error while running the openssl revoke command." 1

  echo "Certificate revoked: $entity_crt_file"

  # regenerate the CRL
  echo "Regenerating CRL for $sign_by_entity..."
  create_crl $sign_by_entity

  log_detailed "revoke: finish (entity=${entity}, sign_by_entity=${sign_by_entity})"
}
revoke_help() {
  echo "
@@@HELP@@@
  "
}
