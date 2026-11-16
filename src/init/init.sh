################################################################################
# initialize security related system - storage or device
#
# parameters
#   system
#     the security related system to initialize
#     allowed values are
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
  local rc=0
  case "$system" in
    yubikey)
      error "'sca init yubikey' was replaced by 'sca security_key init [--roll-keys] [--device SERIAL] <entity>'. see sca security_key init --help" 1
      ;;
    openssl_ca_db|sca_usb_stick|demo)
      shift
      eval init_$system "$@"
      rc=$?
      ;;
    *)
    read -r -d '' message <<- ____EOM
      invalid value for '$system' system (first) argument.
      supported values are 'openssl_ca_db' 'sca_usb_stick' and 'demo'.
      use sca init -h for help.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "init: finish (system=${system}, rc=${rc})"
  return $rc
}
################################################################################
# help for initializing security related system - storage or device
#
init_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
  }
