################################################################################
# generating the entity private key ${<entity>_key_file}
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'ca' 'subca' 'user' 'host' and 'service'
#
create_key() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create key' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca create key -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_key_help
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
  local entity=$1
  log_detailed "create_key: start (entity='${entity}', force='${force}')"
  eval mkdir -p \${${entity}_private_folder}
  local entity_key_file=$(eval echo \$${entity}_key_file)
  local entity_bits=$(eval echo \$${entity}_bits)
  # check if the key file exists
  if [ -f "$entity_key_file" ]; then
    if [ $force = true ]; then
      mv "${entity_key_file}" "${entity_key_file}.$RANDOM.bak"
    else
      error "create_key: key file ${entity_key_file} for entity ${entity} already exist. "\
"use with care --force to overwrite if that's what you really need." 1
    fi
  fi
  # if the entity is ca/subca
  if [ "${entity}" == "ca" ] || [ "${entity}" == "subca" ]; then
    # check if the newcerts folder exists
    local entity_new_certs_dir=$(eval echo \$${entity}_new_certs_dir)
    log_detailed "create_key:  newcerts folder is '${entity_new_certs_dir}'."
    if [ -d "${entity_new_certs_dir}" ]; then
      if [ $force = true ]; then
        log_detailed "create_key: removing old newcerts folder ${entity_new_certs_dir}."
        rm -rf "${entity_new_certs_dir}"
      else
        error "create_key: newcerts folder ${entity_new_certs_dir} exists. plesae check the "\
"folder. if not needed, add --force flag parameter to remove it." 1
      fi
    fi
    log_detailed "creating the newcerts directory for the entity"
    mkdir -p "${entity_new_certs_dir}"

    # check if the database file exists
    local entity_database_file=$(eval echo \$${entity}_database_file)
    log_detailed "create_key:  database file is '${entity_database_file}'."
    if [ -d "${entity_database_file}" ]; then
      if [ $force = true ]; then
        log_detailed "create_key: removing old database file ${entity_database_file}."
        rm "${entity_database_file}"
      else
        error "create_key: database file ${entity_database_file} exists. plesae check the "\
"file. if not needed, add --force flag parameter to remove it." 1
      fi
    fi
    log_detailed "creating the database file for the entity"
    touch "${entity_database_file}"
    echo "unique_subject = no" > "${entity_database_file}.attr"

    # TODO: continue initializing and handing existing ca/subca files and folders below

  fi
  # store the key in hardware key device if configured to do so
  local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  # if the entity is configured to use the security key
  if [ $entity_use_security_key = true ] && [ "${entity_security_key_type}" == "yubikey" ]; then
    # we are creating yubikey security key. initialize it's files if they are not present

    # check if the entity yubikey management key file exists
    local entity_yubikey_key_file=$(eval echo \$${entity}_yubikey_key_file)
    local entity_yubikey_key=""
    log_detailed "create_key: entity yubikey key file is ${entity_yubikey_key_file}."
    if [ -f "${entity_yubikey_key_file}" ]; then
      log_detailed "create_key: entity yubikey key file exists."
      entity_yubikey_key=$(cat ${entity_yubikey_key_file})
    else
      log_detailed "create_key: entity yubikey key file doesn't exist. "\
"initializing an empty one at configured location. if this is the first security "\
"key use, consider using 'sca security_key init' - see output of 'sca security_key init "\
"--help' to read further in that case."
      touch "${entity_yubikey_key_file}"
    fi
    if [ "${entity_yubikey_key}" == "" ]; then
      log_detailed "create_key: entity yubikey key file doesn't exist or is empty ."\
"either type it in each time or add it to the file '${entity_yubikey_key_file}'."
    else
      log_detailed "create_key: entity yubikey key file is set. will use it to "\
"upload the yubikey key to the security key."
    fi

    # check if the entity yubikey pin file exists
    local entity_yubikey_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
    local entity_yubikey_pin=""
    log_detailed "create_key: entity yubikey pin file is ${entity_yubikey_pin_file}."
    if [ -f "${entity_yubikey_pin_file}" ]; then
      log_detailed "create_key: entity yubikey pin file exists."
      entity_yubikey_pin=$(cat ${entity_yubikey_pin_file})
    else
      log_detailed "create_key: entity yubikey pin file doesn't exist. "\
"initializing an empty one at configured location. if this is the first security "\
"key use, consider using 'sca security_key init' - see output of 'sca security_key init "\
"--help' to read further in that case."
      touch "${entity_yubikey_pin_file}"
    fi
    if [ "${entity_yubikey_pin}" == "" ]; then
      log_detailed "create_key: entity yubikey pin file doesn't exist or is empty ."\
"either type it in each time or add it to the file '${entity_yubikey_pin_file}'."
    else
      log_detailed "create_key: entity yubikey pin file is set. will use it to "\
"upload the yubikey key to the security key."
    fi

    # check if the entity yubikey puk file exists
    local entity_yubikey_puk_file=$(eval echo \$${entity}_yubikey_puk_file)
    local entity_yubikey_puk=""
    log_detailed "create_key: entity yubikey puk file is ${entity_yubikey_puk_file}."
    if [ -f "${entity_yubikey_puk_file}" ]; then
      log_detailed "create_key: entity yubikey puk file exists."
      entity_yubikey_puk=$(cat ${entity_yubikey_puk_file})
    else
      log_detailed "create_key: entity yubikey puk file doesn't exist. "\
"initializing an empty one at configured location. if this is the first security "\
"key use, consider using 'sca security_key init' - see output of 'sca security_key init "\
"--help' to read further in that case."
      touch "${entity_yubikey_puk_file}"
    fi
    if [ "${entity_yubikey_puk}" == "" ]; then
      log_detailed "create_key: entity yubikey puk file dosn't exist or is empty ."\
"either type it in each time or add it to the file '${entity_yubikey_puk_file}'."
    else
      log_detailed "create_key: entity yubikey puk file is set. will use it to "\
"upload the yubikey key to the security key."
    fi
    # end of yubikey files initialization
  fi # of if the entity is configured to use the security key
  local openssl_command="$redirect_err openssl genrsa -out ${entity_key_file} ${entity_bits}"
  log_verbose "$openssl_command"
  # generate the key for the entity
  eval "$openssl_command"

  if [ $entity_use_security_key = true ]; then

#    local should_upload_to_security_key=false
    # we assume that the configured default entity id is the owner of the key
    # this sca shall manage.
#    log_detailed "create_key: default_entity_id='$default_entity_id', current_entity_id='$current_entity_id'"
#    if [ "$entity" == "ca" ] || [ "$entity" == "subca" ]; then
#      local default_entity_id=$(get_default_entity_id ${entity})
#      local current_entity_id=$(get_current_entity_id ${entity})
#      [ "$default_entity_id" = "$current_entity_id" ] && should_upload_to_security_key=true
#    fi

    # TODO: implement additional checks if we need to upload the key into yubikey
    # example 2: sign_by_entity = ca, entity = subca
    #   this is a subca held by the same person that has the ca key
    # example 3: sign_by_entity = subca, entity = user
    #   this is a user held by the same person that has the subca key
    # example 4: sign_by_entity = subca, entity = service/host
    #   this is a host or a service and we are running on the machine with the
    #   hw key module, so upload it

#    if [ $should_upload_to_security_key = true ]; then
#      local use_force=''
#      [ $force = true ] && use_force=' --force '
#      security_key_upload $use_force $entity key
#    fi

    local use_force=''
    [ $force = true ] && use_force=' --force '
    security_key_upload $use_force $entity key

  fi
  # datefudge is available for install in universe (not in main restricted),
  # so skipping it for now. uncomment the line if you got it to even more reduce
  # chance of hacking by randomizing the create date of the certificate.

  # in case the entity is ca - so we are generating a Root CA certificate
  # add additional security by using randomizing the certificate creation date.
  #
  # datefudge "2014-01-01 UTC" \
  #openssl req -new -sha256 -x509 -set_serial 1 -days 1000000 \
  #  -config ${ca_csr_ini_file} \
  #  -key ${ca_key_file} \
  #  -out ${ca_crt_file}
  # echo generating ca private key $ca_key_file and certificate signing request $ca_csr_file
  #openssl req -new -newkey rsa:3744 -keyout ${ca_key_file} -out ${ca_csr_file} -nodes
  log_detailed "create_key: finish (entity='${entity}', force='${force}')"
}

create_key_help() {
  echo "
@@@HELP@@@
"
}
