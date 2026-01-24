list_subcas() {
  local output_format=$1
  shift;

  local OPTS=`getopt -o h --long help -n 'list subcas' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list subcas -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_subcas_help
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

  log_detailed "list_subcas: start (subca_files_folder=${subca_files_folder})"

  local parent_folder=$(dirname ${subca_files_folder})
  if [ -d "${parent_folder}" ]; then

    case $output_format in
      ids)
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | grep -v newcerts | grep -v private | paste -sd " " -)"
        ;;
      wide)
      echo -e "name\t\tsubca_name\tsubca_surname\tsubca_given_name\tsubca_initials"
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | grep -v newcerts | grep -v private | xargs -n 1 -I {} sca -c $config_file config get subca {} | sed -e 's/^"//g' | sed -e 's/"$//g')" | sed -e 's/" "/\t\t/g'
        ;;
      *)
        error "output format not supported." 1
        ;;
    esac

  else
    # parent folder doesn't exist. possibly missconfiguration. existing
    return
  fi

  log_detailed "list_subcas: finished (subca_files_folder=${subca_files_folder})"
}
list_subcas_help() {
  echo "
@@@HELP@@@
"
}
