################################################################################
# create openssl configuration file for given entity
#
# parameters
#   entity
#     entity for which to create the openssl
#     allowed values are 'ca', 'subca', 'user', 'host', 'service' and 'all'
#
config_create() {
  local recreate=false

  local OPTS
  OPTS=$(getopt -o hr --long help,recreate -n 'config create' -- "$@") || error "failed parsing options. use sca config create -h for help." 1
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_create_help
        return
        ;;
      -r | --recreate  )
        recreate=true
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


  local entity="$1"
  log_detailed "config_create: start (entity=${entity})"

  sca_config_content='
@@@DEFAULT SCA CONFIG@@@
'
  config_create_set_library_defaults
  [ -z "${sca_conf_folder}" ] && sca_conf_folder=~/.sca/config/
  mkdir -p "${sca_conf_folder}"
  local random_number="$RANDOM"
  # create sca_config if not present or recreate requested
  if [ ! -f "${config_file}" ]; then
    log_detailed "config_create: config file not found. creating '$config_file'."
    echo "${sca_config_content}" > ${config_file}
  else
    # otherwise use existing or recreate depending on recreate flag
    if [ $recreate = true ]; then
      log_detailed "config_create: backing up the existing config file '${config_file}' to '${config_file}.${random_number}.bak'."
      mv "${config_file}" "${config_file}.${random_number}.bak"
      echo "${sca_config_content}" > ${config_file}
    else
      log_detailed "config_create: found existing configuration file ${config_file}. will use it."
    fi
  fi

  local sca_conventions_content='
  @@@DEFAULT CONVENTIONS@@@
  '

  # create conventions_file if not present or recreate requested
  if [ ! -f "${conventions_file}" ]; then
    log_detailed "config_create: conventions file '${conventions_file}' not found, so creating one from scratch."
    echo "${sca_conventions_content}" > "${conventions_file}"
  else
    if [ $recreate = true ]; then
      log_detailed "config_create: backing up the exising conventions file '${conventions_file}' to '${conventions_file}.${random_number}.bak'."
      mv "${conventions_file}" "${conventions_file}.$random_number.bak"
      echo "${sca_conventions_content}" > "${conventions_file}"
    else
      log_detailed "config_create: found existing conventions file ${conventions_file}. will use it."
    fi
  fi

  config_load "${config_file}" "${conventions_file}"

  local sca_config_content='
  @@@DEFAULT OPENSSL CONFIG@@@
  '

  # create openssl_template if not present.
  local openssl_template_file="${sca_conf_folder}openssl_template.ini"
  if [ ! -f "${openssl_template_file}" ]; then
    echo "${sca_config_content}" > "${openssl_template_file}"
  else
    if [ $recreate = true ]; then
      mv "${openssl_template_file}" "${openssl_template_file}.$random_number.bak"
      echo "${sca_config_content}" > "${openssl_template_file}"
    else
      sca_config_content=$(<"${openssl_template_file}")
    fi
  fi

  # create openssl configurations for each entity type
  local generate_openssl_template_for_entities=()
  case "$entity" in
    ca|subca|user|host|service)
      generate_openssl_template_for_entities+=("$entity")
      ;;
    all)
      generate_openssl_template_for_entities+=("ca" "subca" "user" "host" "service")
      ;;
    *)
      read -r -d '' message <<- ____EOM
invalid value '$entity' for first argument - the entity.
supported entities are 'ca' 'subca' 'user' 'host' 'service' and 'all'.
____EOM
      error "$message" 1
      ;;
  esac
  local pkcs11_block_marker="#PKCS11-BLOCK"
  local pkcs11_block_content='
  @@@PKCS11 OPENSSL CONFIG@@@
  '
  local command_result=0
  local pkcs11_block_content_escaped=$(common_sed_escape_for_substitute "$pkcs11_block_content")
  for current_entity in "${generate_openssl_template_for_entities[@]}"
  do
    local current_entity_use_security_key=$(eval echo \$\{${current_entity}_use_security_key\})
    local current_entity_openssl_config_file=${sca_conf_folder}$current_entity.ini
    log_detailed "config_create: the entity ${current_entity} use security key configuration is set to '${current_entity_use_security_key}'."
    log_detailed "config_create: the entity ${current_entity} openssl config file location '${current_entity_openssl_config_file}'."
    if [ "$current_entity_use_security_key" = true ]; then
      log_detailed "config_create: the entity ${current_entity} uses security key. adding pkcs section"
      # insert pkcs11 related lines if current default entity is using security key
      # by replacing the comment #PKCS11. also, change the [ entity_req ] section
      # name to [ req ]
      local tmp="${current_entity_openssl_config_file}".tmp
      <<<"${sca_config_content}" >"${tmp}" \
        sed -e ':a' -e '$!{N;ba' -e '}' -e "s/$pkcs11_block_marker/$pkcs11_block_content_escaped/"
      command_result="$?"
      if [ ! "${command_result}" == "0" ] ; then
        error "config_create: error while replacing pkcs11 section in openssl config for ${current_entity}." ${command_result}
      fi
      <"${tmp}"  >"${current_entity_openssl_config_file}" \
        sed -e "s/\[ ${current_entity}_req \]/\[ req \]/g"
      command_result="$?"
      rm "${tmp}"
      if [ ! "${command_result}" == "0" ] ; then
        error "config_create: error while generating openssl config for ${current_entity}." ${command_result}
      fi

    else
      # change the [ entity_req ] section name to [ req ]
      <<<"$sca_config_content" >"${current_entity_openssl_config_file}" \
        sed -e "s/\[ ${current_entity}_req \]/\[ req \]/g"
        command_result="$?"
      if [ ! "${command_result}" == "0" ] ; then
        error "config_create: error while generating openssl config for ${current_entity}." ${command_result}
      fi
    fi

  done

  log_detailed "config_create: finish (entity='${entity}')"
}
################################################################################
# sets the pkcs11 library *_default lines in sca_config_content to the
# libraries found on this host, or to their path in this host's multiarch
# folder when they aren't installed yet
config_create_set_library_defaults() {
  local setting relative_path library line
  for setting in pkcs11_engine:engines-3/pkcs11.so \
    opensc_pkcs11_module:opensc-pkcs11.so ykcs11_module:libykcs11.so; do
    relative_path="${setting#*:}"
    setting="${setting%%:*}"
    if ! library="$(find_pkcs11_library "${relative_path}")"; then
      log_detailed "config_create: ${relative_path} not found on this host. defaulting ${setting} to '${library}'."
    fi
    # quoted for sourcing, in case the path holds spaces
    line="export ${setting}_default=$(printf %q "${library}")"
    # the trailing '.' keeps the content's trailing newlines
    sca_config_content="$(sed -e "s/^export ${setting}_default=.*/$(common_sed_escape_for_substitute "${line}")/" <<<"${sca_config_content}"; echo .)"
    sca_config_content="${sca_config_content%$'\n.'}"
  done
}
config_create_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
