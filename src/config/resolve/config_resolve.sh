################################################################################
# resolve configuration settings values based on the sca.config environment
# variables
config_resolve() {

  local OPTS=`getopt -o h --long help -n 'config resolve' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config resolve -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_resolve_help
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

  local conventions=${1:-$conventions_file}
  log_detailed "config_resolve: applying conventions as specified in file '${conventions}'."
  . $conventions
  get_relative_subfolder ca_files_folder_suffix ${key_folder} ${ca_crt_file}
  get_relative_subfolder subca_files_folder_suffix ${key_folder} ${subca_crt_file}
  get_relative_subfolder service_files_folder_suffix ${key_folder} ${service_crt_file}
  get_relative_subfolder host_files_folder_suffix ${key_folder} ${host_crt_file}
  get_relative_subfolder user_files_folder_suffix ${key_folder} ${user_crt_file}

  if [[ $verbosity == vv* ]]; then redirect_err="2>>${log_file}"; else redirect_err='2> /dev/null'; fi
  if [[ $verbosity == vv* ]]; then redirect_err_out="2>&1 1>>${log_file}"; else redirect_err_out='2>&1 1> /dev/null'; fi

}
config_resolve_help() {
  echo "
@@@HELP@@@
"
}
