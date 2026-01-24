################################################################################
# initialize security related system - storage or device
#
# parameters
#   system
#     the security related system to initialize
#     allowed values are
#       'yubikey'
#       'openssl_ca_db'
#       'sca_usb_stick'
#       'demo'
#
init() {

  #local OPTS=`getopt -o h --long help -n 'init' -- "$@"`
  #if [ $? != 0 ] ; then error "failed parsing options. use sca init -h for help." 1; fi
  while true; do
    case "$1" in
      -h | --help )
        init_help
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

  local system=$1
  log_detailed "init: start (system=${system})"
  case "$system" in
    yubikey|openssl_ca_db|sca_usb_stick|demo)
      shift
      eval init_$system "$@"
      ;;
    *)
    read -r -d '' message <<- ____EOM
      invalid value for '$document_type' document_type (first) argument.
      supported values are 'yubikey' 'openssl_ca_db' 'sca_usb_stick' and 'demo'.
      use sca init -h for help.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "init: finish (system=${system})"
}
################################################################################
# help for initializing security related system - storage or device
#
init_help() {
  echo "
@@@HELP@@@
    "
  }
