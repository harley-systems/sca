list_users() {
  local output_format=$1
  shift;

  local OPTS=`getopt -o h --long help -n 'list users' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca list users -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        list_users_help
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

  log_detailed "list_users: start (user_files_folder=${user_files_folder})"

  local parent_folder=$(dirname ${user_files_folder})
  if [ -d "${parent_folder}" ]; then

    case $output_format in
      ids)
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename | paste -sd " " -)"
        ;;
      wide)
        echo -e "name\t\tuser_name\tuser_surname\t\tuser_given_name\tuser_initials"
        echo "$(ls -d ${parent_folder}/*/| xargs -n 1 basename| xargs -n 1 -I {} sca -c $config_file config get user {} | sed -e 's/^"//g' | sed -e 's/"$//g')" | sed -e 's/" "/\t\t/g'
        ;;
      *)
        error "output format not supported." 1
        ;;
    esac

  else
    # parent folder doesn't exist. possibly missconfiguration. existing
    return
  fi

  log_detailed "list_users: finished (user_files_folder=${user_files_folder})"
}
list_users_help() {
  echo "
@@@HELP@@@
"
}
