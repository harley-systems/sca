################################################################################
# approve csr for entity and issue crt pub and pub_ssh
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'subca' 'host' 'service' 'user'
#   entity_id
#     the id of the entity to approve
#     valid values are the ids of the existing entities with certificates
#     capable of signing other certificates. normally, those are ca and subca
#     ids.
#   sign_by_entity
#     the entity to use for signing on the certificate.
#     optional. specified under option -s or --sign-by .
#     if not set, default resolves to subca unless entity is 'subca'. in that
#     case the default value for sign_by_entity parameter is 'ca'.
#
approve() {

  # read the options
  local force=false
  local OPTS=`getopt -o hfs: --long help,force,sign-by: -n 'approve' -- "$@"`
  local sign_by_entity
  if [ $? != 0 ] ; then error "failed parsing options. use sca approve -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        approve_help
        return
        ;;
      -f | --force )
        force=true
        shift
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
  local entity_id=$2

  if [ -z "$sign_by_entity" ]; then
    # if not provided with sign by entity, resolve it automatically according
    # to some default logic:
    [[ $entity == subca ]] && sign_by_entity=ca || sign_by_entity=subca
  fi
  log_detailed "approve: start (entity=${entity}, entity_id=${entity_id}, sign_by_entity=${sign_by_entity})"

  # in case entity id and possibly other info was passed, we want to
  # save the current entity information and temporarily configure
  # the default for the eneiety to the provided entity info

  shift

  case $entity in
    ca)
      current_entity_value=$name
      ;;
    subca|user|service|host)
      current_entity_value=$(eval echo \$$entity)
      ;;
  esac
  local current_entity_id=$(get_current_entity_id $entity)
  old_entity=''
  if [[ ! -z $entity_id ]] && [[ "$entity_id" != $current_entity_id ]]; then
    log_detailed "approve: temporarily switching entity"
    old_entity=$(config_get "${entity}")
    old_entity="${old_entity//[$'\t\r\n']}"
    #old_entity=${old_entity@Q}
    log_detailed "approve: old_entity saved ${old_entity}"
    new_entity="$@"
    new_entity=${new_entity@Q}
    log_detailed "approve: temporarily setting configuration for ${entity} to ${new_entity}"
    config_set $entity "${new_entity}"
  fi

  # ca's are self approved. exit without doing anything.
  if [[ $entity == ca ]]; then
    log_detailed "approve: finish (entity=${entity})"
    return 0
  fi

  case "$sign_by_entity" in
    ca)
      export OPENSSL_CONF=${sca_conf_folder}ca.ini
      ;;
    subca)
      export OPENSSL_CONF=${sca_conf_folder}subca.ini
      ;;
    *)
      read -r -d '' message <<- ____EOM
      invalid value '$entity' for entity (first) argument.
      supported values are 'ca' 'subca', 'user', 'host', 'service'.
____EOM
      ;;
  esac

  local use_force=''
  [ $force = true ] && use_force='--force'
  create crt_pub_ssh $use_force $entity $sign_by_entity
  export_ crt_pub_ssh $entity

  # now we want to restore the original current entity info
  if ! [ -z "$old_entity" ]; then
    log_detailed "approve: setting entity back for ${entity} to ${old_entity}"
    config_set ${entity} "${old_entity}"
  fi


  log_detailed "approve: finish (entity=${entity})"
}
approve_help() {
  echo "
@@@HELP@@@
  "
}
get_current_entity_id() {
  local entity="$1"
  local current_entity_id=''
  case $entity in
    ca)
      current_entity_id="$name"
      ;;
    subca|user|service|host)
      current_entity_id=$(eval echo \$$entity)
      ;;
    * )
      error "get_current_entity_id: unknown entity type." 1
  esac
  echo "$current_entity_id"
}
get_default_entity_id() {
  local entity="$1"
  local current_default_entity_id=''
  case $entity in
    ca)
      current_default_entity_id="$name_default"
      ;;
    subca|user|service|host)
      current_default_entity_id=$(eval echo \$${entity}_default)
      ;;
    * )
      error "get_default_entity_id: unknown entity type." 1
  esac
  echo "$current_default_entity_id"
}
