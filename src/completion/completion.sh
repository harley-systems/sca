################################################################################
# completion related command
#
# parameters
#   shell
#     optional parameter. default value is bash. specifies the shell for which
#     to generate the completion script. for future use.
#     currently, the only allowed value is 'bash'
#
completion() {

  local OPTS=`getopt -o h --long help -n 'completion' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca completion -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        completion_help
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

  local shell=${1:-bash}
  log_detailed "copmletion: start (config_verb=${shell})"
  case "$shell" in
    bash)
      shift
      echo '
@@@BASH COMPLETION@@@
'
      ;;
    *)
      read -r -d '' message <<- ____EOM
      invalid value '$shell' for shell (first) argument.
      supported valueis 'bash'.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "copmletion: finish (config_verb=${shell})"
}
completion_help() {
  echo "
@@@HELP@@@
  "
}
