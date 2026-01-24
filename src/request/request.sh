################################################################################
# initialize new entity and create it's csr request archive
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'ca' 'subca' 'host' 'service' 'user'
#
request() {

  local OPTS=`getopt -o h --long help -n 'request' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca request -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        request_help
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
  local entity_id=$2
  local old_entity
  local new_entity

  log_detailed "request: start (entity=${entity}, entity_id=${entity_id})"
  eval OPENSSL_CONF=${sca_conf_folder}${entity}.ini
  log_detailed "request: using OPENSSL_CONF $OPENSSL_CONF"
  log_detailed "request: params before shift ${@@Q}"
  shift
  log_detailed "request: params after shift ${@@Q}"
  log_detailed "request: params length after shift ${#@}"
  # in case entity id and possibly other info was passed, we want to
  # save the current entity information and temporarily configure
  # the default for the eneiety to the provided entity info

  case $entity in
    ca)
      current_entity_value=$name
      ;;
    subca|user|service|host)
      current_entity_value=$(eval "echo \$$entity")
      ;;
  esac
  old_entity=''
  if [[ ! -z $entity_id ]] && [[ "$entity_id" != $current_entity_value ]]; then
    log_detailed "request: temporarily switching entity"
    old_entity=$(config_get "${entity}")
    old_entity="${old_entity//[$'\t\r\n']}"
    #old_entity=${old_entity@Q}
    log_detailed "request: old_entity saved ${old_entity}"
    new_entity=""
    log_detailed "request: new_entity ${@@Q}"
    log_detailed "request: temporarily setting configuration for ${entity} to ${@@Q}"
    config_set $entity ${@@Q}
  fi

  create_key ${entity}
  [[ $entity == ca || $entity == subca ]] && init_openssl_ca_db $entity
  create_csr ${entity}
  log_detailed $(display_csr ${entity})
  if [[ $entity == ca ]]; then
    create crt_pub_ssh ca ca
  else
    export_ csr ${entity}
  fi

  if ! [ -z "$old_entity" ]; then
    log_detailed "request: setting entity back for ${entity} to ${old_entity}"
    config_set ${entity} ${old_entity}
  fi

  log_detailed "request:  finish (entity=${entity})"
}
request_help() {
  echo "
@@@HELP@@@
    "
  }
