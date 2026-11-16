list() {

  local output_format='ids'
  local OPTS
  OPTS=$(getopt -o ho: --long help,output-format: -n 'sca list' -- "$@") || error "failed parsing options. use sca list -h for help." 1
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
  local rc=0 list_rc=0
  case "$list_entity" in
    cas|subcas|users|hosts|services|configs)
      shift
      eval list_$list_entity "$output_format" "$@"
      rc=$?
      ;;
    all)
      shift
      echo "ca's:"
      echo
      eval list_cas "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      echo "subca's:"
      echo
      eval list_subcas "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      echo "users's:"
      echo
      eval list_users "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      echo "hosts's:"
      echo
      eval list_hosts "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      echo "services's:"
      echo
      eval list_services "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      echo "configs's:"
      echo
      eval list_configs "$output_format" "$@"
      list_rc=$?; [ $rc -eq 0 ] && rc=$list_rc
      echo
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$list_entity' for list_entity (first) argument.
        supported values are 'cas', 'subcas', 'users', 'hosts', 'services',
        'configs' and 'all'.
        use sca list -h for help.
____EOM
      error "$message" 1
      ;;
  esac
  log_detailed "list: finish (list_entity=${list_entity},output_format=${output_format},rc=${rc})"
  return $rc


}
list_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
  }
