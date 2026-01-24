config_save() {
  local OPTS=`getopt -o h --long help -n 'config save' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config save -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_save_help
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
  log_detailed "config_save: start (sca_config_file=${sca_config_file})"

  [ -z ${sca_conf_folder} ] && sca_conf_folder=~/.sca/config/

  sca_config_content='
#################################################
# settings
# default value for verbosity level - none, v, vv
export verbosity_default='$verbosity'
#
export name_default='$name'
#
export caps_name_default='$caps_name'
#
export domain_default='$domain'
#
export ca_bits_default='$ca_bits'
#
export subca_default='$subca'
#
export subca_name_default='$subca_name'
#
export subca_surname_default='$subca_surname'
#
export subca_given_name_default='$subca_given_name'
#
export subca_initials_default='$subca_initials'
#
export subca_bits_default='$subca_bits'
#
export service_default='$service'
#
export service_bits_default='$service_bits'
#
export host_default='$host'
#
export host_bits_default='$host_bits'
#
export user_default='$user'
#
export user_name_default='$user_name'
#
export user_surname_default='$user_surname'
#
export user_given_name_default='$user_given_name'
#
export user_initials_default='$user_initials'
#
export user_bits_default='$user_bits'
#
export suffix_default='$suffix'
#
export caps_suffix_default="'$caps_suffix'"

#################################################
# folder settings
#
export demo_folder_default='$demo_folder'
#
export key_folder_default='$key_folder'
#
export transfer_folder_default='$transfer_folder'
# the folder containing the sca script
export sca_folder_default='$sca_folder'
# the folder in which to keep openssl configuration files and template
export sca_conf_folder_default='$sca_conf_folder'
  '
  # create sca_config if not present, otherwise ask to remove existing and
  # create if confirmed
  if [ -f ${sca_config_file} ]; then
    read -p "file $sca_config_file exists. remove?" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm "$sca_config_file"
    else
      return
    fi
  fi

  echo "${sca_config_content}" > ${sca_config_file}

  log_detailed "config_save: finished (sca_config_file=${sca_config_file})"
}
config_save_help() {
  echo "
@@@HELP@@@
"
}
