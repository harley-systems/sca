################################################################################
# configuration related command
#
# parameters
#   config_verb
#     configuration operation to run
#     allowed values are 'create', 'resolve', 'set', 'get', 'load' and 'save'
#
config() {

  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      config_help
      return
      ;;
  esac

  local config_verb=$1
  log_detailed "config: start (config_verb=${config_verb})"
  case "$config_verb" in
    create|resolve|set|get|load|save|reset)
      shift
      eval config_$config_verb "$@"
      ;;
    *)
      read -r -d '' message <<- ____EOM
      invalid value '$config_verb' for config_verb (first) argument.
      supported values are 'create' 'resolve' 'set' and 'get'.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "config: finish (config_verb=${config_verb})"
}
config_help() {
  echo "
@@@HELP@@@
  "
}
