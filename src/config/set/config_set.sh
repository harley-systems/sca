################################################################################
# persist a configuration value to the config file
#
# parameters
#   var_name - the variable name (without _default suffix)
#   value    - the value to set
#
config_set_persist() {
  local var_name="$1"
  local value="$2"
  if [ -n "$config_file" ] && [ -f "$config_file" ]; then
    sed -i "s/^export ${var_name}_default=.*/export ${var_name}_default=${value}/" "$config_file"
    log_detailed "config_set_persist: updated ${var_name}_default=${value} in ${config_file}"
  fi
}

################################################################################
# set a configuration setting value
#
# parameters
#   setting_name
#     name of the configuration parameter to set
#     allowed values are 'ca' 'subca' 'user' 'host' 'service'
#
config_set() {

  OPTS=`getopt -o h --long help -n 'config set' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config set -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "${1}" in
      -h | --help )
        config_set_help
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

  setting_name="${1}"
  shift
  log_detailed "config_set: start (setting_name=${setting_name}, info=$@)"
  case "$setting_name" in
    ca|subca|user|host|service)
      log_detailed "config_set: parameters $@"
      eval config_set_$setting_name $@
      ;;
    *)
    read -r -d '' message <<- ____EOM
      invalid value '$setting_name' for setting_name (first) argument.
      supported values are 'ca' 'subca' 'user' 'host' 'service'.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "config_set: finish (setting_name=${setting_name})"
}
config_set_help() {
  echo "
@@@HELP@@@
  "
}
################################################################################
# set a ca configuration settings
#
# parameters
#   key value - set a specific ca setting (e.g., security_key_id "XX-XX-XX")
#   OR positional: ca_name caps_name (legacy)
#
config_set_ca() {
  # Check if first arg looks like a setting name (contains underscore or known setting)
  local known_settings="name caps_name domain bits use_security_key security_key_type security_key_id pkcs11_id yubikey_slot yubikey_pin_policy yubikey_touch_policy"
  if echo "$known_settings" | grep -qw "$1"; then
    # key-value mode: config set ca <key> <value>
    local key="$1"
    local value="$2"
    if [ "$key" = "name" ] || [ "$key" = "caps_name" ] || [ "$key" = "domain" ]; then
      # These are global settings without ca_ prefix
      export "$key"="$value"
      config_set_persist "$key" "$value"
    else
      # CA-specific settings with ca_ prefix
      export "ca_$key"="$value"
      config_set_persist "ca_$key" "$value"
    fi
    log_detailed "config_set_ca: set ${key}=${value}"
  else
    # legacy positional mode: config set ca <name> <caps_name>
    export name="${1:-$name}"
    export caps_name="${2:-$caps_name}"
    log_detailed "config_set_ca: name:${1} caps_name:${2}"
    config_set_persist "name" "$name"
    config_set_persist "caps_name" "$caps_name"
  fi
  config resolve
}
################################################################################
# set a subca configuration settings
#
# parameters
#   key value - set a specific subca setting
#   OR positional: subca subca_name subca_surname subca_given_name subca_initials (legacy)
#
config_set_subca() {
  local known_settings="subca name surname given_name initials use_security_key security_key_type security_key_id pkcs11_id yubikey_slot yubikey_pin_policy yubikey_touch_policy"
  if echo "$known_settings" | grep -qw "$1"; then
    # key-value mode
    local key="$1"
    local value="$2"
    if [ "$key" = "subca" ]; then
      export subca="$value"
      config_set_persist "subca" "$value"
    else
      export "subca_$key"="$value"
      config_set_persist "subca_$key" "$value"
    fi
    log_detailed "config_set_subca: set ${key}=${value}"
  else
    # legacy positional mode
    export subca=${1:-$subca}
    export subca_name=${2:-$subca_name}
    export subca_surname=${3:-$subca_surname}
    export subca_given_name=${4:-$subca_given_name}
    export subca_initials=${5:-$subca_initials}
    log_detailed "config_set_subca: subca:$1 subca_name:$2 subca_surname:$3 subca_given_name:$4 subca_initials:$5"
    config_set_persist "subca" "$subca"
    config_set_persist "subca_name" "$subca_name"
    config_set_persist "subca_surname" "$subca_surname"
    config_set_persist "subca_given_name" "$subca_given_name"
    config_set_persist "subca_initials" "$subca_initials"
  fi
  config resolve
}
################################################################################
# set a user configuration settings
#
# parameters
#   key value - set a specific user setting
#   OR positional: user user_name user_surname user_given_name user_initials (legacy)
#
config_set_user() {
  local known_settings="user name surname given_name initials use_security_key security_key_type security_key_id pkcs11_id yubikey_slot yubikey_pin_policy yubikey_touch_policy"
  if echo "$known_settings" | grep -qw "$1"; then
    # key-value mode
    local key="$1"
    local value="$2"
    if [ "$key" = "user" ]; then
      export user="$value"
      config_set_persist "user" "$value"
    else
      export "user_$key"="$value"
      config_set_persist "user_$key" "$value"
    fi
    log_detailed "config_set_user: set ${key}=${value}"
  else
    # legacy positional mode
    export user=${1:-$user}
    export user_name=${2:-$user_name}
    export user_surname=${3:-$user_surname}
    export user_given_name=${4:-$user_given_name}
    export user_initials=${5:-$user_initials}
    log_detailed "config_set_user: user:$1 user_name:$2 user_surname:$3 user_given_name:$4 user_initials:$5"
    config_set_persist "user" "$user"
    config_set_persist "user_name" "$user_name"
    config_set_persist "user_surname" "$user_surname"
    config_set_persist "user_given_name" "$user_given_name"
    config_set_persist "user_initials" "$user_initials"
  fi
  config resolve
}
################################################################################
# set a host configuration settings
#
# parameters
#   key value - set a specific host setting
#   OR positional: host (legacy)
#
config_set_host() {
  local known_settings="host use_security_key security_key_type security_key_id pkcs11_id yubikey_slot yubikey_pin_policy yubikey_touch_policy"
  if echo "$known_settings" | grep -qw "$1"; then
    # key-value mode
    local key="$1"
    local value="$2"
    if [ "$key" = "host" ]; then
      export host="$value"
      config_set_persist "host" "$value"
    else
      export "host_$key"="$value"
      config_set_persist "host_$key" "$value"
    fi
    log_detailed "config_set_host: set ${key}=${value}"
  else
    # legacy positional mode
    export host=${1:-$host}
    log_detailed "config_set_host: host:$1"
    config_set_persist "host" "$host"
  fi
  config resolve
}
################################################################################
# set a service configuration settings
#
# parameters
#   key value - set a specific service setting
#   OR positional: service (legacy)
#
config_set_service() {
  local known_settings="service use_security_key security_key_type security_key_id pkcs11_id yubikey_slot yubikey_pin_policy yubikey_touch_policy"
  if echo "$known_settings" | grep -qw "$1"; then
    # key-value mode
    local key="$1"
    local value="$2"
    if [ "$key" = "service" ]; then
      export service="$value"
      config_set_persist "service" "$value"
    else
      export "service_$key"="$value"
      config_set_persist "service_$key" "$value"
    fi
    log_detailed "config_set_service: set ${key}=${value}"
  else
    # legacy positional mode
    export service=${1:-$service}
    log_detailed "config_set_service: service:$1"
    config_set_persist "service" "$service"
  fi
  config resolve
}
