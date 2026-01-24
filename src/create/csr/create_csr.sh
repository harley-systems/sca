################################################################################
# creating entity certificate signing request $<entity>_csr_file
#
# parameters
#   entity
#     the entity for which to create certificate signature reuest document
#     allowed values are 'ca' 'subca' 'user' 'host' and 'service'
#
create_csr() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create csr' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca create csr -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_csr_help
        return
      ;;
      -f | --force )
        force=true;
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
  local entity="$1"
  local use_openssl_config_file="${sca_conf_folder}${entity}.ini"
  log_detailed "create_csr: start (entity='${entity}', use_openssl_config_file='${use_openssl_config_file}', force='${force}')"
  local entity_key_file=$(eval echo \$${entity}_key_file)
  local entity_csr_file=$(eval echo \$${entity}_csr_file)
  if [ -f "$entity_csr_file" ]; then
    if [ $force = false ]; then
      error "a certificate signature request already exist in the file system. "\
"if you wish to backup existing one and generate a new one, use the "\
"--force option." 1
    else
      mv "$entity_csr_file" "$entity_csr_file.$RANDOM.bak"
    fi
  fi
  local openssl_command=""
  # check if the key file exists in the file system
  if [ -f "$entity_key_file" ]; then
    log_detailed "create_csr: entity key file '${entity_key_file}' was found. using it to create the csr."
    openssl_command="$redirect_err openssl req \
      -config $use_openssl_config_file \
      -sha256 \
      -new \
      -key $entity_key_file \
      -nodes \
      -out $entity_csr_file "
  else
    # the key file is not present in the file system
    log_detailed "create_csr: entity key file '${entity_key_file}' was not found in the file system."

    # if entity key is configured to reside in the yubikey, use it to sign the
    # certificate signature request
    # TODO: validate that the key within the yubikey is related to the entity at hand
    local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
    if [ $entity_use_security_key = true ]; then
      log_detailed "create_csr: entity key file is stored in a security key."
      local entity_pkcs11_id=$(eval echo \$${entity}_pkcs11_id)
      # if not already connected, prompt and wait for the relevant security key
      # to be inserted
      local security_key_opensc_reader_slot_number=$(security_key_wait_for $entity | tail -n 1)
      local sign_by_entity_pkcs11_id=$(eval echo \${${entity}_pkcs11_id})
      # check if entity key is protected by pin
      local apply_pin=$(get_yubikey_pin_parameter $entity)
      warn_yubikey_touch_expected $entity
      openssl_command="${redirect_err} openssl req \
        -config $use_openssl_config_file \
        -sha256 \
        -new \
        -nodes \
        -engine pkcs11 \
        -keyform engine \
        -keyfile ${sign_by_entity_pkcs11_id} \
        -out $entity_csr_file ${apply_pin}"
    else
      # the entity key file doesn't exist and it has not been configured to
      # reside within yubikey
      error "create_csr: unable to find the '${entity}' key file "\
"'${entity_key_file}' and key is not configured to be stored in security "\
"key device. check the configuration." 1
    fi
  fi
  log_verbose "${openssl_command}"
  eval "${openssl_command}"

  if [ ! "$?" = "0" ]; then
    error "create_csr: error while running the openssl command." 1
  fi

  log_detailed "create_csr: finish (entity='${entity}', use_openssl_config_file='${use_openssl_config_file}', force='${force}')"
}

create_csr_help() {
  echo "
@@@HELP@@@
"
}
