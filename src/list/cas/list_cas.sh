list_cas() {
  local output_format=$1
  shift;

  local OPTS=`getopt -o h --long help -n 'sca list cas' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list cas -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_cas_help
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

  log_detailed "list_cas: start (ca_files_folder=${ca_files_folder},output_format=${output_format})"

  local parent_folder=$(dirname ${ca_files_folder})
  if [ -d "${parent_folder}" ]; then
    case $output_format in
      ids)
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | paste -sd " " -)"
        ;;
      wide)
        echo -e "name\tcaps_name"
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | xargs -n 1 -I {} sca -c $config_file config get ca {} | sed -e 's/^"//g' | sed -e 's/"$//g' )" | sed -e 's/" "/\t/g'
        ;;
      *)
        error "output format not supported." 1
        ;;
    esac
  else
    # parent folder doesn't exist. possibly missconfiguration. existing
    return
  fi

  log_detailed "list_cas: finished (ca_files_folder=${ca_files_folder},output_format=${output_format})"

}
list_cas_help() {
  echo "
@@@HELP@@@
"
}
