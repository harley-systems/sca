config_reset() {
  local OPTS=`getopt -o h --long help -n 'config reset' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config reset -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_reset_help
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

  local sca_config_file=$1
  shift
  log_detailed "config_reset: start"

  export verbosity=$verbosity_default
  export name=$name_default
  export caps_name=$caps_name_default
  export domain=$domain_default
  export ca_bits=$ca_bits_default
  export subca=$subca_default
  export subca_name=$subca_name_default
  export subca_surname=$subca_surname_default
  export subca_given_name=$subca_given_name_default
  export subca_initials=$subca_initials_default
  export subca_bits=$subca_bits_default
  export service=$service_default
  export service_bits=$service_bits_default
  export host=$host_default
  export host_bits=$host_bits_default
  export user=$user_default
  export user_name=$user_name_default
  export user_surname=$user_surname_default
  export user_given_name=$user_given_name_default
  export user_initial=$user_initials_default
  export user_bits=$user_bits_default
  export suffix=$suffix_default
  export caps_suffix="$caps_suffix_default"
  export demo_folder=$demp_folder_default
  export key_folder=$key_folder_default
  export transfer_folder=$transfer_folder_default
  export sca_folder=$sca_folder_default
  export sca_conf_folder=$sca_conf_folder_default

  log_detailed "config_reset: finished"
}
config_reset_help() {
  echo "
@@@HELP@@@
"
}
