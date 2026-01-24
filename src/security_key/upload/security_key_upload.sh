security_key_upload() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n "sca security_key upload" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key upload -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_upload_help
        return
      ;;
      -f | --force )
        force=true
        shift
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
  local document=$2
  shift; shift
  log_detailed "security_key_upload: start (entity:'${entity}', document:'${document}')"
  local allowed_values=(ca subca user service host)
  [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]] && \
    error "security_key_upload: invalid value supplied for entity. use sca "\
"security_key upload -h for help." 1

  # TODO: check how to put to use the reader id we got in below commands
  # it is useful when having multiple yubikeys inserted.
  local wait_for_response=$(security_key_wait_for "$entity")

  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  log_detailed "security_key_upload: the wait for response was '${wait_for_response}'. "
  log_detailed "security_key_upload: the entity security_key_type '${entity_security_key_type}'. "

  # the slot is available for upload, so go ahead and do it
  case "$entity_security_key_type" in
    yubikey )
      local entity_pkcs11_id=$(eval echo \$${entity}_pkcs11_id)
      local entity_yubikey_slot=$(map_pkcs11_id_to_yubikey_slot_id $entity_pkcs11_id)
      local entity_management_key_file=$(eval echo \$${entity}_yubikey_key_file)
      local entity_management_key=$(cat "$entity_management_key_file")
      log_detailed "security_key_upload: the configured entity pkcs11 id '${entity_pkcs11_id}'. "
      log_detailed "security_key_upload: mapped yubikey slot id '${entity_yubikey_slot}'."
      log_detailed "security_key_upload: the management key file '${entity_management_key_file}'."
      local command_result=0
      local command_output=""
      case "$document" in
        crt )
          # check if the crt already exists in the upload destination slot
          yubico_piv_tool_command='yubico-piv-tool -a "read-certificate" \
            -s $entity_yubikey_slot | grep "Failed fetching certificate"'
          log_verbose "security_key_upload: running command ${yubico_piv_tool_command}"
          local entity_security_key_slot_empty=$(eval "${yubico_piv_tool_command}")
          log_detailed "security_key_upload: certificate lookup result at that slot '${entity_security_key_slot_empty}'."
          if [ -z "$entity_security_key_slot_empty" ]; then
            log_detailed "security_key_upload: certificate found in the slot."
            # slot contains a certificate
            if [ $force = true ]; then
              log_detailed "security_key_upload: due to force flag, deleting the existing certificate."
              yubico_piv_tool_command='yubico-piv-tool -a delete-certificate -s "$entity_yubikey_slot"'
              run_yubico_piv_tool_command "${yubico_piv_tool_command}" "${entity_management_key}"
            else
              error "security_key_upload: destination slot '$entity_yubikey_slot' already contains a "\
"certificate. please, check the "\
"configuration to see if the yubikey slot for entity $entity has been "\
"properly configured. remove any unwanted certificate from yubikey by "\
"issuing the following command: TODO:<add command here>" 1
            fi
          else
            log_detailed "security_key_upload: certificate not found in the slot."
          fi
          local entity_crt_file=$(eval echo \$${entity}_crt_file)
          log_detailed "security_key_upload: uploading the certificate ${entity_crt_file} to yubikey."
          yubico_piv_tool_command='<"${entity_crt_file}" yubico-piv-tool -a import-certificate -s "$entity_yubikey_slot"'
          run_yubico_piv_tool_command "${yubico_piv_tool_command}" "${entity_management_key}"
        ;;
        key )
          local entity_yubikey_pin_policy=$(eval echo \$${entity}_yubikey_pin_policy)
          local entity_yubikey_touch_policy=$(eval echo \$${entity}_yubikey_touch_policy)
          local entity_key_file=$(eval echo \$${entity}_key_file)
          log_detailed "security_key_upload: the entity's configured yubikey pin policy is '${entity_yubikey_pin_policy}'."
          log_detailed "security_key_upload: the entity's configured yubikey touch policy is '${entity_yubikey_touch_policy}'."
          # TODO: i did not investigate enough to find a way so far to check if a key is already present at
          # the entity_yubikey_slot. maybe it is possibly to determine by it's usage trial
          # in case it exists, we should err unless force is applied
          log_detailed "security_key_upload: uploading the key '${entity_key_file}' to yubikey."
          yubico_piv_tool_command='<"${entity_key_file}" yubico-piv-tool --pin-policy="${entity_yubikey_pin_policy}" --touch-policy="${entity_yubikey_touch_policy}" -a import-key -s "${entity_yubikey_slot}"'
          run_yubico_piv_tool_command "${yubico_piv_tool_command}" "${entity_management_key}"
        ;;
        * )
          error "security_key_upload: unknown document $document. supported "\
"values for document are crt and key. use sca security_key upload "\
"-h for help." 1
        ;;
      esac
    ;;
    pkcs11 )
      # TODO: implement for pkcs11
      :
    ;;
    * )
      error "create_crt: cann't upload to yubikey - unsupported entity hw key " \
"type: '$entity_security_key_type' configured for the entity '$entity'." 1
    ;;
  esac
  log_detailed "security_key_upload: finished (entity:'${entity}')"
}
security_key_upload_help() {
  echo "
@@@HELP@@@
"
}

run_yubico_piv_tool_command() {
  local cmd=$1
  local key=$2

  if [ ! "${key}" == "" ]; then
    log_detailed "run_yubico_piv_tool_command: entity management key is set, so applying the --key parameter"
    cmd="2>&1 ${yubico_piv_tool_command}"' --key="${entity_management_key}"'
  else
    cmd="2>&1 ${yubico_piv_tool_command} -k"
  fi
  log_verbose "run_yubico_piv_tool_command: running command ${cmd}"
  command_output=$(eval "${cmd}")
  command_result="$?"
  log_detailed "run_yubico_piv_tool_command: the command output was: '${command_output}'."
  if [ ! "${command_result}" == "0" ] || [[ "${command_output}" == *"Failed"* ]]; then
    error "run_yubico_piv_tool_command: error '${command_result}' while running the yubico-piv-tool command - output ${command_output}." ${command_result}
  fi
}
