################################################################################
# export public security documents for entity (crt, pub and ssh)
#
# parameters
#   entity
#     the entity for which to export public documents
#     allowed values are 'user' 'host' and 'service'
#
export_crt_pub_ssh() {

  local OPTS=`getopt -o h --long help -n "export crt_pub_ssh" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca export crt_pub_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        export_crt_pub_ssh_help
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
  log_detailed "export_crt_pub_ssh: start (entity=${entity})"
  #  ensure destination folders exist on the transfer medium
  eval mkdir -p ${ca_transfer_files_folder} ${subca_transfer_files_folder} \
        \${${entity}_transfer_files_folder}
  # copy relevant files to the transfer files folder
  cp ${ca_crt_file} ${ca_pub_file} ${ca_pub_ssh_file} \
    ${ca_transfer_files_folder}
  cp ${subca_crt_file} ${subca_pub_file} ${subca_pub_ssh_file} \
        ${subca_transfer_files_folder}
  eval cp \${${entity}_crt_file} \${${entity}_pub_file} \${${entity}_pub_ssh_file} \
        \${${entity}_transfer_files_folder}
  # create certificate archive
  pushd . > /dev/null
  cd ${key_folder}
  eval tar czf ${transfer_folder}\${${entity}_crt_filename}.tgz \
    ${ca_files_folder_suffix}${ca_crt_filename} \
    ${ca_files_folder_suffix}${ca_pub_filename} \
    ${ca_files_folder_suffix}${ca_pub_ssh_filename} \
    ${subca_files_folder_suffix}${subca_crt_filename} \
    ${subca_files_folder_suffix}${subca_pub_filename} \
    ${subca_files_folder_suffix}${subca_pub_ssh_filename} \
    \${${entity}_files_folder_suffix}\${${entity}_crt_filename} \
    \${${entity}_files_folder_suffix}\${${entity}_pub_filename} \
    \${${entity}_files_folder_suffix}\${${entity}_pub_ssh_filename}
  popd > /dev/null
  log_detailed "export_crt_pub_ssh: finish (entity=${entity})"
}
export_crt_pub_ssh_help() {
  echo "
@@@HELP@@@
  "
}
