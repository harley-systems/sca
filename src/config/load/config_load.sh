config_load() {

  local OPTS=`getopt -o h --long help -n 'config load' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config load -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_load_help
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
  local sca_conventions_file=$2
  shift

  log_detailed "config_load: start (sca_config_file=${sca_config_file},sca_conventions_file=${sca_conventions_file})"

  # loading configuration file with default values for non-derived and derived
  # configuration parameters
  . ${sca_config_file}

  # log the configuration loaded if requested
  log_extreemly_detailed "config_load: sca_config_content
$(<${sca_config_file})
end of sca_config_content."
  log_detailed "config_load: key_folder_default is ${key_folder_default}."

  # resolve configuration according to environment variables and above loaded
  # configuration defaults
  config_resolve $sca_conventions_file

  log_detailed "config_load: finished (sca_config_file=${sca_config_file})"
}
config_load_help() {
  echo "
@@@HELP@@@
"
}
