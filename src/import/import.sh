################################################################################
# import files from archives in $transfer_folder into $key_folder
#
import() {

  local OPTS=`getopt -o h --long help -n 'import' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca import -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        import_help
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

  log_detailed "import: start (transfer_folder ${transfer_folder} key_folder ${key_folder})"
  pushd . > /dev/null
  cd ${key_folder}

  local redirect_output='> /dev/null'
  [[ $verbosity = vv* ]] && redirect_output=">> $log_file"
  local extract_command="ls ${transfer_folder}*.tgz | xargs -I {} tar xvzf {} $redirect_output"
  bash -c "${extract_command}"
  mkdir -p ${transfer_folder}imported/
  mv ${transfer_folder}*.tgz ${transfer_folder}imported/
  popd > /dev/null

  # TODO: upload relevant certificates that has been imported to yubikey.
  # for example, in case we're the one that requested it, and the entity has
  # been configured to be held in the key.


  # TODO: check if the destination yubikey slot doesn't already have an
  # uploaded certificate


  log_detailed "import: finish"
}
import_help() {
  echo "
@@@HELP@@@
    "
  }
