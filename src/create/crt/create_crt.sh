################################################################################
# create certificate signed by an authoritive entity by approving relevant csr
#
# parameters
#   entity
#       the entity for which to create the certificate
#       allowed values are 'ca' 'user' 'host' and 'service'
#   sign_by_entity
#       the entity to use to sign the issued certificate
#       allowed values are 'ca' and 'subca'
#     default value - 'subca'
#
create_crt() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create crt' -- "$@"`
  if [ $? != 0 ] ; then
    error "failed parsing options. use sca create crt -h for help." 1;
  fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_crt_help
        return
      ;;
      -f | --force )
        force=true
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

  # resolve sign_by_entity
  local sign_by_entity="${2:-none}"
  if [ "${sign_by_entity}" == "none" ]; then
    if [ "$1" == "ca" ] || [ "$1" == "subca" ]; then
      # if not specified, and the entity is either ca or subca, than use ca as sign_by_entity default
      sign_by_entity="ca"
    else
      # if not specified, and the entity is subca, than use ca as sign_by_entity default
      sign_by_entity="subca"
    fi
  fi
  log_detailed "create_crt: start (entity='${entity}', "\
"sign_by_entity='${sign_by_entity}', force='$force')"
  local selfsign=""
  [[ "$entity" == "$sign_by_entity" ]] && selfsign="-selfsign"
  export OPENSSL_CONF="${sca_conf_folder}${sign_by_entity}.ini"
  local sign_by_entity_key_file=$(eval echo \$${sign_by_entity}_key_file)
  local entity_csr_file=$(eval echo \${${entity}_csr_file})
  local entity_crt_file=$(eval echo \${${entity}_crt_file})
  local entity_extensions="${entity}_with_san_ext"
  local openssl_command=""
  local entity_pin=""

  # check if the certificate file already exists in the file system
  if [ -f $entity_crt_file ]; then
    if [ $force = false ]; then
      error "create_crt: the certificate file ($entity_crt_file) for entity "\
"'$entity' already exists in the file-system. use --force if you want to "\
"generate a new certificate" 1
    else
      mv $entity_crt_file $entity_crt_file.$RANDOM.bak
    fi
  fi
  # check if the sign_by_entity_key_file exists in the filesystem.
  if [ -f "$sign_by_entity_key_file" ]; then
    # if so, use it to issue signed certificate
    openssl_command="$redirect_err openssl ca \
      -name $sign_by_entity \
      -batch \
      -create_serial \
      -in $entity_csr_file \
      -out $entity_crt_file \
      -extensions $entity_extensions \
      -keyfile $sign_by_entity_key_file \
      -preserveDN \
      $selfsign "
  else
    # check if the signing entity (sign_by_entity) is configured to be stored in hw device
    local sign_by_entity_use_security_key=$(eval echo \$${sign_by_entity}_use_security_key)
    if [ $sign_by_entity_use_security_key = true ]; then
      local sign_by_entity_security_key_type=$(eval echo \$${sign_by_entity}_security_key_type)
      local sign_by_entity_pkcs11_id=$(eval echo \${${sign_by_entity}_pkcs11_id})
      local security_key_opensc_reader_slot_number=$(security_key_wait_for $sign_by_entity)
      # TODO: see if below is bullshit or needed. this mapping looks stinky - i don't believe that the opensc slot number retrieved above relates to the p11tools token index.
      readarray slot_map < <( p11tool --list-tokens | grep -oP "(?<=URL: ).*" )
      log_detailed "create_crt: slot_map retrieved. there are ${#slot_map[@]} items."
      log_detailed "create_crt: opensc reader slot number '${security_key_opensc_reader_slot_number}' mapped to pkcs11 id is '${slot_map[${security_key_opensc_reader_slot_number}]::-1}'."
      log_detailed "create_crt: sign_by_entity_pkcs11_id '${sign_by_entity_pkcs11_id}'."
      local mapped_slot_id="${slot_map[${security_key_opensc_reader_slot_number}]::-1}"
      local entity_pin=$(get_yubikey_pin_parameter $sign_by_entity)
      local pin_uri_fragment=""
      [ -n "$entity_pin" ] && pin_uri_fragment=";pin-value=${entity_pin}"
      local pkcs11_keyfile="pkcs11:id=%${sign_by_entity_pkcs11_id};type=private${pin_uri_fragment}"
      warn_yubikey_touch_expected $sign_by_entity
      openssl_command="$redirect_err openssl ca \
        -name $sign_by_entity \
        -batch \
        -create_serial \
        -in ${entity_csr_file} \
        -out ${entity_crt_file} \
        -extensions $entity_extensions \
        -engine pkcs11 \
        -keyform engine \
        -keyfile \"${pkcs11_keyfile}\" \
        -preserveDN $selfsign"
      #  -keyfile ${mapped_slot_id}:${sign_by_entity_pkcs11_id} \
    else
      error "create_crt: Unable to find key file $sign_by_entity_key_file for"\
"$sign_by_entity entity " 1
    fi
  fi

# pkcs url for slot with private key stored
# encoded
# pkcs11:model=PKCS%2315%20emulated;manufacturer=piv_II;serial=f6907938c58b8aeb;token=PIV%20Card%20Holder%20pin%20%28PIV_II%29;id=%01;object=PIV%20AUTH%20pubkey;type=public
# decoded
# pkcs11:model=PKCS#15 emulated;manufacturer=piv_II;serial=f6907938c58b8aeb;token=PIV Card Holder pin (PIV_II);id=;object=PIV AUTH pubkey;type=public



  # in following cases it makes sense to upload intermediately upon signing crt:

  # example 1: sign_by_entity = ca, entity = ca
  #   this is the configured default ca it makes sense to upload it
  # local should_upload_to_security_key=false
  # local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
  # if [ $entity_use_security_key = true ] && [ "$sign_by_entity" == "ca" ] && \
  #     [ "$entity" == "ca" ]; then
  #   local default_ca_id=$(get_default_entity_id ca)
  #   local current_ca_id=$(get_current_entity_id ca)
  #   # we assume that the configured default entity id is the owner of the key
  #   # this sca shall manage.
  #   log_detailed "create_crt: default_ca_id='$default_ca_id', current_ca_id='$current_ca_id'"
  #   [ "$default_ca_id" == "$current_entity_id" ] && should_upload_to_security_key=true
  # fi

  # TODO: implement additional checks if we need to upload the crt into yubikey
  # example 2: sign_by_entity = ca, entity = subca
  #   this is a subca held by the same person that has the ca key
  # example 3: sign_by_entity = subca, entity = user
  #   this is a user held by the same person that has the subca key
  # example 4: sign_by_entity = subca, entity = service/host
  #   this is a host or a service and we are running on the machine with the
  #   hw key module, so upload it
  # TODO: also, update craete_key accordinglycccccc

  # TODO: bundle all certificates - useful for serivces like https
  # cat ${service_crt_file} \
  #     ${user_crt_file} \
  #     ${ca_crt_file} \
  #   > ${service_key_file_prefix}bundle-crt.pem

  log_verbose "$openssl_command"
  if [ -n "$entity_pin" ]; then
    eval "$openssl_command" <<< "$entity_pin"
  else
    eval "$openssl_command"
  fi
  [ ! "$?" = "0" ] && error "create_crt: error while running the openssl command." 1

  # if [ $should_upload_to_security_key = true ]; then
  #   local use_force=''
  #   [ $force = true ] && use_force=' --force '
  #   security_key_upload $use_force $entity crt
  # fi
  local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
  if [ $entity_use_security_key = true ]; then
    local use_force=''
    [ $force = true ] && use_force='--force'
    security_key_upload $use_force $entity crt
  fi

  # Also create pub and pub_ssh files from the certificate
  local use_force=''
  [ $force = true ] && use_force='--force'
  create_pub $use_force $entity
  create_pub_ssh $use_force $entity

  log_detailed "create_crt: finish (entity='${entity}', "\
"sign_by_entity='${sign_by_entity}', force='$force')"
}

create_crt_help() {
  echo "
@@@HELP@@@
"
}
