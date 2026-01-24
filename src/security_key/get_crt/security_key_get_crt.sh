security_key_get_crt() {
  local OPTS=`getopt -o h --long help -n "sca security_key get_crt" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key get_crt -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_id_help
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
  log_detailed "security_key_get_crt: started (entity='$entity')"
  local allowed_values=(ca subca user service host)
  [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]] && \
    error "security_key_wait_for: invalid value supplied for entity. use sca "\
"security_key wait_for -h for help." 1
  local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
  if [ $entity_use_security_key = false ]; then
    error "security_key_get_crt: the entity has not been configured to use "\
"security key. please, check configuration." 1
  fi
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  local security_key_opensc_reader_slot_number=$(security_key_wait_for $entity)
  case $entity_security_key_type in
    "yubikey" )
      local entity_pkcs11_id=$(eval echo \$${entity}_pkcs11_id)
      local entity_yubikey_slot=$(map_pkcs11_id_to_yubikey_slot_id $entity_pkcs11_id)
      local entity_certificate=$(2>&1 yubico-piv-tool -a "read-certificate" \
        -s $entity_yubikey_slot)
      local entity_security_key_slot_empty=$(echo "${entity_certificate}" | grep "Failed fetching certificate")
      if ! [ -z "$entity_security_key_slot_empty" ]; then
        error "create_pub: can not find the certificate for the entity "\
"'$entity' on security key." 1
      fi
      local entity_files_folder=$(eval echo \$${entity}_files_folder)
      local entity_crt_file=$(eval echo \$${entity}_crt_file)
      mkdir -p $entity_files_folder
      echo "${entity_certificate}" > "${entity_crt_file}"
    ;;
    "pkcs11" )
      # TODO: implement certificate retrieval over pkcs/piv interface
      :
    ;;
    * )
      error "create_pub: unsupported security key type configured "\
"'$entity_security_key_type' for entity '$entity'. check configuration." 1
    ;;
  esac
  log_detailed "security_key_get_crt: finished (entity='$entity')"
}
