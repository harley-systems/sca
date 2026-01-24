list() {

  local output_format='ids'
  local OPTS=`getopt -o ho: --long help,output-format: -n 'sca list' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_help
        return
        ;;
      -o | --output-format )
        output_format="$2"; shift; shift
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

  local list_entity=$1
  log_detailed "list: start (list_entity=${list_entity},output_format=${output_format})"
  case "$list_entity" in
    cas|subcas|users|hosts|services|configs)
      shift
      eval list_$list_entity "$output_format" "$@"
      ;;
    all)
      shift
      echo "ca's:"
      echo
      eval list_cas "$output_format" "$@"
      echo
      echo "subca's:"
      echo
      eval list_subcas "$output_format" "$@"
      echo
      echo "users's:"
      echo
      eval list_users "$output_format" "$@"
      echo
      echo "hosts's:"
      echo
      eval list_hosts "$output_format" "$@"
      echo
      echo "services's:"
      echo
      eval list_services "$output_format" "$@"
      echo
      echo "configs's:"
      echo
      eval list_configs "$output_format" "$@"
      echo
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$list_entity' for list_entity (first) argument.
        supported values are 'cas', 'subcas', 'users', 'hosts',' services' and
        'configs'.
        use sca list -h for help.
____EOM
      error "$message" 1
      ;;
  esac
  log_detailed "list: finish (list_entity=${list_entity},output_format=${output_format})"


}
list_help() {
  echo "
@@@HELP@@@
    "
  }
