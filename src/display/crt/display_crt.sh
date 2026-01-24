################################################################################
# inspect security document by outputing it in readable form to standard output
#
# parameters
#   entity
#     the entity for which to display the document
#     allowed values are 'ca' 'user' 'host' and 'service'
#
display_crt() {
  local OPTS=`getopt -o h --long help -n "display crt" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca display crt -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        display_crt_help
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
  log_detailed "display_crt: start (entity=${entity}, entity_id=${entity_id})"
  local current_entity_id=$(get_current_entity_id $entity)
  log_detailed "display_crt: current_entity_id $current_entity_id"
  old_entity=''
  if [[ ! -z "$entity_id" ]] && [[ "$entity_id" != $current_entity_id ]]; then
    old_entity=$(config_get $entity)
    old_entity="${old_entity//[$'\t\r\n']}"
    #old_entity=${old_entity@Q}
    log_detailed "display_crt: old_entity saved ${old_entity}"
    log_detailed "display_crt: temporarily setting configuration for ${entity} to ${new_entity}"
    config_set $entity ${entity_id}
  fi
  local entity_crt_file=$(eval echo \${${entity}_crt_file})
  if ! [ -f "$entity_crt_file" ]; then
    local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
    if [ $entity_use_security_key = false ]; then
      error "display_crt: the certificate file not found in file-system and not "\
"using security key. check configuration." 1
    else
      security_key_get_crt $entity
    fi
  fi
  openssl x509 -text < "$entity_crt_file"
  if ! [ -z "$old_entity" ]; then
    log_detailed "display_crt: setting entity back for ${entity} to ${old_entity}"
    config_set ${entity} ${old_entity}
  fi

  log_detailed "display_crt: finish (entity=${entity}, entity_id=${entity_id}, old_entity_id=$old_entity_id)"
}
display_crt_help() {
    echo "
@@@HELP@@@
  "
}
