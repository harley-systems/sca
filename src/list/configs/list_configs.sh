list_configs() {
  local output_format=$1
  shift;

  local OPTS=`getopt -o h --long help -n 'list configs' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list configs -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_configs_help
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
  log_detailed "list_configs: start (sca_conf_folder=${sca_conf_folder},demo_folder=${demo_folder})"

  case $output_format in
    ids)
      local demo_folder_configs
      local sca_conf_folder_configs="$(ls ${sca_conf_folder}*.config| xargs -n 1 basename | paste -sd " " -)"
      if [ -d ${demo_folder} ]; then
        demo_folder_configs="$(ls ${demo_folder}*.config| xargs -n 1 basename | paste -sd " " -)"
      fi
      echo "$sca_conf_folder_configs $demo_folder_configs"
      ;;
    wide)
      echo -e "filename"
      local demo_folder_configs
      local sca_conf_folder_configs="$(ls ${sca_conf_folder}*.config| xargs -n 1 basename)"
      echo "$sca_conf_folder_configs"
      if [ -d ${demo_folder} ]; then
        demo_folder_configs="$(ls ${demo_folder}*.config| xargs -n 1 basename)"
        echo "$demo_folder_configs"
      fi
      ;;
    *)
      error "output format not supported." 1
      ;;
  esac


  log_detailed "list_configs: finished (sca_config_file=${sca_config_file},sca_conventions_file=${sca_conventions_file})"

}
list_configs_help() {
  echo "
@@@HELP@@@
"
}
