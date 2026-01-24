################################################################################
# Inspect the generated entity certificate signing request
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'subca' 'user' 'host' and 'service'
#
display_csr() {
  local OPTS=`getopt -o h --long help -n "display csr" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca display csr -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        display_csr_help
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
  log_detailed "display_csr: start (entity=${entity}, entity_id=${entity_id})"


  local current_entity_id=$(get_current_entity_id $entity)
  log_detailed "display_csr: current_entity_id $current_entity_id"
  local old_entity=''
  if [[ ! -z "$entity_id" ]] && [[ "$entity_id" != $current_entity_id ]]; then
    old_entity=$(config_get $entity)
    old_entity="${old_entity//[$'\t\r\n']}"
    #old_entity=${old_entity@Q}
    log_detailed "display_csr: old_entity saved ${old_entity}"
    log_detailed "display_csr: temporarily setting configuration for ${entity} to ${new_entity}"
    config_set $entity ${entity_id}
  fi

  local entity_csr_file=$(eval echo \${${entity}_csr_file})
  if ! [ -f $entity_csr_file ]; then
    error "display_csr: certificate signature file doesn't exist. check the "\
"configuration." 1
  fi
  local openssl_command="openssl req -in $entity_csr_file -text"

  log_verbose "$openssl_command"
  eval $openssl_command

  if ! [ -z "$old_entity" ]; then
    log_detailed "display_csr: setting entity back for ${entity} to ${old_entity}"
    config_set ${entity} ${old_entity}
  fi

  log_detailed "display_csr: finish (entity=${entity}, entity_id=${entity_id}, old_entity_id=$old_entity_id))"
}
display_csr_help() {
    echo "
@@@HELP@@@
  "
}
