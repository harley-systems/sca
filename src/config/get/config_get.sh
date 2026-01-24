################################################################################
# get a configuration setting value
#
# parameters
#   setting_name
#     name of the configuration parameter to set
#     allowed values are 'ca' 'subca' 'user' 'host' 'service'
#
config_get() {

  OPTS=`getopt -o h --long help -n 'config get' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca config get -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        config_get_help
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

  setting_name=$1
  log_detailed "config_get: start (setting_name=${setting_name}, info=$@, config_file=$config_file)"
  case "$setting_name" in
    ca|subca|user|host|service)
      shift
      eval config_get_$setting_name "$@"
      ;;
    *)
    read -r -d '' message <<- ____EOM
      invalid value '$setting_name' for setting_name (first) argument.
      supported values are 'ca' 'subca' 'user' 'host' 'service'.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "config_get: finish (setting_name=${setting_name}, info=$@, config_file=$config_file))"
}
config_get_help() {
  echo "
@@@HELP@@@
  "
}
################################################################################
# get a ca configuration settings
#
# returns string in form:
#
#   "<ca_name>" "<caps_name>"
#
# where:
#   ca_name
#     name of the ca
#   caps_name
#     the name of the ca as it will appear in texts - for example name with
#     capitalized first letters.
#
config_get_ca() {
  local ca_id=$1

  log_detailed "config_get_ca: start (ca_id=${ca_id})"

  if [[ -z "$ca_id" ]] || [[ $ca_id == $name ]]; then
    echo \"$name\" \"$caps_name\"
  else
    local ca_document=$(display_crt ca ${ca_id})
    [ -z "${ca_document}" ] && ca_document=$(display_csr ca ${ca_id})
    [ -z "${ca_document}" ] && return
    local ca_name=$(echo "${ca_document}" | grep  'Subject:' | awk 'NF>1{print $NF}' | cut -f 2 -d '@' | cut -f 1 -d '.')
    [ -z "${ca_name}" ] && return
    local ca_caps_name=$(echo "${ca_document}" | grep Subject: | grep -o 'O = .*, OU = ')
    [ ! -z "${ca_caps_name}" ] && ca_caps_name=${ca_caps_name::-7}
    [ ! -z "${ca_caps_name}" ] && ca_caps_name=${ca_caps_name:4}
    echo \"${ca_name}\" \"${ca_caps_name}\"
  fi

  log_detailed "config_get_ca: finished (ca_id=${ca_id})"

}
################################################################################
# get a subca configuration settings
#
# returns string in form:
#
#   "<subca>" "<subca_name>" "<subca_surname>" "<subca_given_name>" "<subca_initials>"
#
# where:
#   subca
#     id of the subca
#   subca_name
#     name of the subca
#   subca_surname
#     surname of the subca
#   subca_given_name
#     given name of the subca
#   subca_initials
#     initials of the subca
#
config_get_subca() {
  local subca_id=$1

  log_detailed "config_get_subca: start (subca_id=${subca_id})"

  if [ -z "$subca_id" ] || [ $subca_id == $subca ]; then
    echo \"$subca\" \"$subca_name\" \"$subca_surname\" \"$subca_given_name\" \"$subca_initials\"
  else
    local subca_document=$(display_crt subca ${subca_id})
    [ -z "${subca_document}" ] && subca_document=$(display_csr subca ${subca_id})
    [ -z "${subca_document}" ] && return
    local the_subca_name=$(echo "${subca_document}" | grep Subject: | grep -o 'name = .*, SN = ' | cut -f 3 -d ' ')
    [ ! -z "${the_subca_name}" ] && the_subca_name=${the_subca_name::-1}
    local the_subca_surname=$(echo "${subca_document}"  | grep Subject: | grep -o ' SN = .*, GN = ' | cut -f 4 -d ' ')
    [ ! -z "${the_subca_surname}" ] && the_subca_surname=${the_subca_surname::-1}
    local the_subca_given_name=$(echo "${subca_document}"  | grep -o ' GN = .*, initials = ' | cut -f 4 -d ' ')
    [ ! -z "${the_subca_given_name}" ] && the_subca_given_name=${the_subca_given_name::-1}
    local the_subca_initials=$(echo "${subca_document}"  | grep Subject: | awk 'NF>1{print $NF}' | cut -f 1 -d '@')
    local the_subca=$subca_id
    echo \"$the_subca\" \"$the_subca_name\" \"$the_subca_surname\" \"$the_subca_given_name\" \"$the_subca_initials\"
  fi


  log_detailed "config_get_subca: finished (subca_id=${subca_id})"

}
################################################################################
# get a user configuration settings
#
# returns string in form:
#
#   "<user>" "<user_name>" "<user_surname>" "<user_given_name>" "<user_initials>"
#
# where:
#   user
#     id of the user
#   user_name
#     name of the user
#   user_surname
#     surname of the user
#   user_given_name
#     given name of the user
#   user_initials
#     initials of the user
#
config_get_user() {
  local user_id=$1

  log_detailed "config_get_user: start (user_id=${user_id})"

  if [ -z "$user_id" ] || [ $user_id == $user ]; then
    echo \"$user\" \"$user_name\" \"$user_surname\" \"$user_given_name\" \"$user_initials\"
  else
    local user_document=$(display_crt user ${user_id})
    [ -z "${user_document}" ] && user_document=$(display_csr user ${user_id})
    [ -z "${user_document}" ] && return
    local the_user_name=$(echo "${user_document}" | grep Subject: | grep -o 'name = .*, SN = ' | cut -f 3 -d ' ')
    [ ! -z "${the_user_name}" ] && the_user_name=${the_user_name::-1}
    local the_user_surname=$(echo "${user_document}" | grep Subject: | grep -o ' SN = .*, GN = ' | cut -f 4 -d ' ')
    [ ! -z "${the_user_surname}" ] && the_user_surname=${the_user_surname::-1}
    local the_user_given_name=$(echo "${user_document}" | grep -o ' GN = .*, initials = ' | cut -f 4 -d ' ')
    [ ! -z "${the_user_given_name}" ] && the_user_given_name=${the_user_given_name::-1}
    local the_user_initials=$(echo "${user_document}" | grep Subject: | grep -o ' initials = .*, C = ' | cut -f 4 -d ' ')
    [ ! -z "${the_user_initials}" ] && the_user_initials=${the_user_initials::-1}
    local the_user=$user_id
    echo \"$the_user\" \"$the_user_name\" \"$the_user_surname\" \"$the_user_given_name\" \"$the_user_initials\"
  fi

  log_detailed "config_get_user: finidhed (user_id=${user_id})"
}
################################################################################
# get a host configuration settings
#
# returns string in form:
#
#   "<host_name>"
#
# where:
#   host_name
#     name of the host
#
config_get_host() {
  local host_id=$1

  log_detailed "config_get_host: start (host_id=${host_id})"

  if [ -z "$host_id" ] || [ $host_id == $host ]; then
    echo \"$host\"
  else
    local host_document=$(display_crt host ${host_id})
    [ -z "${host_document}" ] && host_document=$(display_csr host ${host_id})
    [ -z "${host_document}" ] && return
    local host_name=$(echo "${host_document}" | grep  'Subject:' | awk 'NF>1{print $NF}')
    echo \"$host_name\"
  fi

  log_detailed "config_get_host: finished (host_id=${host_id})"
}
################################################################################
# get a user configuration settings
#
# returns string in form:
#
#   "<service_name>"
#
# where:
#   service_name
#     name of the service
#
config_get_service() {
  local service_id=$1

  log_detailed "config_get_service: start (service_id=${service_id})"

  if [ -z "$service_id" ] || [ $service_id == $service ]; then
    echo \"$service\"
  else
    local service_document=$(display_crt service ${service_id})
    [ -z "${service_document}" ] && service_document=$(display_csr service ${service_id})
    [ -z "${service_document}" ] && return

    local service_name=$(echo "${service_document}" | grep  'Subject:' | awk 'NF>1{print $NF}')
    echo \"$service_name\"
  fi

  log_detailed "config_get_service: finished (service_id=${service_id})"
}
