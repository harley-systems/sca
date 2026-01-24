################################################################################
# initialize the openssl database directories and files for entity
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'ca' 'subca'
#
init_openssl_ca_db() {

  local OPTS=`getopt -o h --long help -n "init openssl_ca_db" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca init openssl_ca_db -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        init_openssl_ca_db_help
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
  log_detailed "init_openssl_ca_db: start (entity=${entity})"
  eval mkdir -p \${${entity}_new_certs_dir}
  eval touch \${${entity}_database_file}
  eval touch \${${entity}_database_file}.attr
  log_detailed "init_openssl_ca_db: finish (entity=${entity})"
}
init_openssl_ca_db_help() {
  echo "
@@@HELP@@@
    "
}
