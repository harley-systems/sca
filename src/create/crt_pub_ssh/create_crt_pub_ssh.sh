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
create_crt_pub_ssh() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create crt_pub_ssh' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca create crt_pub_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_crt_pub_ssh_help
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
  local sign_by_entity=${2:-subca}
  log_detailed "create_crt_pub_ssh: start (entity='${entity}', sign_by_entity='${sign_by_entity}', force='${force}')"
  local use_force=''
  [ $force = true ] && use_force=' --force '
  create crt $use_force ${entity} ${sign_by_entity}
  local crt=$(display_crt ${entity})
  log_detailed "${crt}"
  create pub $use_force ${entity}
  create pub_ssh $use_force ${entity}
  log_detailed "create_crt_pub_ssh: finish (entity='${entity}', sign_by_entity='${sign_by_entity}', force='${force}')"
}
create_crt_pub_ssh_help() {
  echo "
@@@HELP@@@
"
}
