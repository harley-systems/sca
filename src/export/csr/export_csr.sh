################################################################################
# export entity csr request archive
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'user' 'host' and 'service'
#     the entity for which to export public documents
#     allowed values are 'ca' 'subca'
export_csr() {

  local OPTS=`getopt -o h --long help -n "export csr" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca export csr -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        export_csr_help
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

  local entity=$1
  local entity_transfer_files_folder=$(eval echo \${${entity}_transfer_files_folder})
  local csr_archive=$(eval echo ${transfer_folder}\${${entity}_csr_filename}.tgz)
  log_detailed "export_csr: start (entity=${entity} transfer_folder ${transfer_folder} entity_transfer_files_folder ${entity_transfer_files_folder} csr_archive=${csr_archive})"
  #
  mkdir -p ${entity_transfer_files_folder}
  # copy the generated request to transfer_folder
  eval cp \${${entity}_csr_file} ${entity_transfer_files_folder}
  # create request archive
  pushd . > /dev/null
  cd ${key_folder}
  local redirect_output='> /dev/null'
  [[ $verbosity == vv* ]] && redirect_output=">> ${log_file}"
  local tar_command="tar cvzf ${csr_archive} \${${entity}_files_folder_suffix}\${${entity}_csr_filename} $redirect_output"
  eval "$tar_command"
  popd > /dev/null
  log_detailed "export_csr: finish (entity=${entity})"
}
export_csr_help() {
    echo "
@@@HELP@@@
  "
}
