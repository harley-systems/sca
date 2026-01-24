list_hosts() {
  local output_format=$1
  shift;

  local OPTS=`getopt -o h --long help -n 'list hosts' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list hosts -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_hosts_help
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

  log_detailed "list_hosts: start (host_files_folder=${host_files_folder})"

  local parent_folder=$(dirname ${host_files_folder})
  if [ -d "${parent_folder}" ]; then

    case $output_format in
      ids)
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | paste -sd " " -)"
        ;;
      wide)
        echo -e "name\t\t\t"
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename)"
        ;;
      *)
        error "output format not supported." 1
        ;;
    esac

  else
    # parent folder doesn't exist. possibly missconfiguration. existing
    return
  fi

  log_detailed "list_hosts: finished (host_files_folder=${host_files_folder})"
}
list_hosts_help() {
  echo "
@@@HELP@@@
"
}
