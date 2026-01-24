################################################################################
# create public key file
#
# parameters
#   entity
#     the entity for which to create the public key file
#     allowed values are 'ca' 'user' 'host' and 'service'
#
create_pub() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create pub' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca create pub -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_pub_help
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
  log_detailed "create_pub: start (entity='${entity}', force='${force}')"
  local entity_pub_file=$(eval echo \$${entity}_pub_file)
  local entity_crt_file=$(eval echo \$${entity}_crt_file)
  if [ -f "$entity_pub_file" ]; then
    if [ $force = false ]; then
      error "create_pub: the pub file already exists. use --force to backup and overwrite."
    else
      mv "$entity_pub_file" "$entity_pub_file.$RANDOM.bak"
    fi
  fi
  local openssl_command="openssl x509 \
    -pubkey \
    -noout \
    -in ${entity_crt_file} \
    > ${entity_pub_file} ${redirect_err}"

  if ! [ -f "$entity_crt_file" ]; then
    local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
    if [ $entity_use_security_key = false ]; then
      error "create_pub: can not find the certificate for the entity '$entity' "\
" on disk and it is not being stored on a security key." 1
    fi
    security_key_get_crt $entity
  fi

  log_verbose "$openssl_command"
  eval "$openssl_command"

  log_detailed "create_pub: finish (entity='${entity}', force='${force}')"
}

create_pub_help() {
  echo "
@@@HELP@@@
"
}
