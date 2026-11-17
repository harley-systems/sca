config_save() {
  local OPTS
  OPTS=$(getopt -o h --long help -n 'config save' -- "$@") || error "failed parsing options. use sca config save -h for help." 1
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

  [ -z "${sca_conf_folder}" ] && sca_conf_folder=~/.sca/config/

  # every value is written with printf %q, so the file sources back to
  # exactly these values and nothing in a value runs
  sca_config_content="$(cat <<EOF

#################################################
# settings
# default value for verbosity level - none, v, vv
export verbosity_default=$(printf %q "${verbosity}")
#
export name_default=$(printf %q "${name}")
#
export caps_name_default=$(printf %q "${caps_name}")
#
export domain_default=$(printf %q "${domain}")
#
export ca_bits_default=$(printf %q "${ca_bits}")
#
export subca_default=$(printf %q "${subca}")
#
export subca_name_default=$(printf %q "${subca_name}")
#
export subca_surname_default=$(printf %q "${subca_surname}")
#
export subca_given_name_default=$(printf %q "${subca_given_name}")
#
export subca_initials_default=$(printf %q "${subca_initials}")
#
export subca_bits_default=$(printf %q "${subca_bits}")
#
export service_default=$(printf %q "${service}")
#
export service_bits_default=$(printf %q "${service_bits}")
#
export host_default=$(printf %q "${host}")
#
export host_bits_default=$(printf %q "${host_bits}")
#
export user_default=$(printf %q "${user}")
#
export user_name_default=$(printf %q "${user_name}")
#
export user_surname_default=$(printf %q "${user_surname}")
#
export user_given_name_default=$(printf %q "${user_given_name}")
#
export user_initials_default=$(printf %q "${user_initials}")
#
export user_bits_default=$(printf %q "${user_bits}")
#
export suffix_default=$(printf %q "${suffix}")
#
export caps_suffix_default=$(printf %q "${caps_suffix}")

#################################################
# folder settings
#
export demo_folder_default=$(printf %q "${demo_folder}")
#
export key_folder_default=$(printf %q "${key_folder}")
#
export transfer_folder_default=$(printf %q "${transfer_folder}")
# the folder containing the sca script
export sca_folder_default=$(printf %q "${sca_folder}")
# the folder in which to keep openssl configuration files and template
export sca_conf_folder_default=$(printf %q "${sca_conf_folder}")
EOF
)"
  # create sca_config if not present, otherwise ask to remove existing and
  # create if confirmed
  if [ -f "${sca_config_file}" ]; then
    read -p "file $sca_config_file exists. remove?" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm "$sca_config_file"
    else
      return
    fi
  fi

  echo "${sca_config_content}" > "${sca_config_file}"

  log_detailed "config_save: finished (sca_config_file=${sca_config_file})"
}
config_save_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
