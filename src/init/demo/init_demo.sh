################################################################################
# initialize the demo with ca subcas users services and hosts
#
# parameters
#   test_folder_data
#     root folder in which to keep the test data
#
init_demo() {

  local OPTS=`getopt -o h --long help -n "init demo" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca init demo -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        init_demo_help
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

  config_resolve
  local test_folder_data=${1:-$demo_folder}
  test_folder_data="$(cd "$(dirname "$test_folder_data")"; pwd)/$(basename "$test_folder_data")"/
  log_detailed "init_demo: start (test_folder_data=${test_folder_data})"
  if [ -d "$test_folder_data" ]; then
    read -p "folder $test_folder_data exists. remove?" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$test_folder_data"
    else
      return
    fi
  fi
  # make sure we set the demo folder for the configuration files created below
  # with the demo folder default configured to this demo folder.
  demo_folder_default=$test_folder_data
  init_demo_switch_to "ca" "$test_folder_data"
  local ca_transfer_folder=${transfer_folder}
  init_demo_switch_to "subca" "$test_folder_data"
  local subca_transfer_folder=${transfer_folder}
  init_demo_switch_to "user" "$test_folder_data"
  user_transfer_folder=${transfer_folder}
  log_detailed "init:demo: ca_transfer_folder: ${ca_transfer_folder} "\
    "subca_transfer_folder: ${subca_transfer_folder} "\
    "user_transfer_folder ${user_transfer_folder}"
  # ---------
  # create ca
  # ---------
  log_detailed "init_demo: creating CAs..."
  init_demo_switch_to "ca" "$test_folder_data"
  # save sb-ca configuration
  config save "${test_folder_data}ca-$name-sca.config"
  # without parameters
  request ca
  # with parameters
  request ca test TestInc

  # save test-ca configuration
  local old_ca_config=$(config_get ca)
  old_ca_config="${old_ca_config//[$'\t\r\n']}"

  log_detailed "init_demo: old_ca_config ${old_ca_config}"
  config set ca test TestInc
  config save "${test_folder_data}ca-$name-sca.config"
  config set ca "${old_ca_config}"

  # ---------------------
  # create subca requests
  # ---------------------
  log_detailed "init_demo: creating subca requests..."
  init_demo_switch_to "subca" "$test_folder_data"
  # save harley-subca configuration
  config save "${test_folder_data}subca-$subca-sca.config"
  # create subca request without parameters
  request subca
  # create subca request with parameters
  request subca daniel Daniel Korac Vladimir D.K.

  # save daniel-subca configuration
  local old_subca_config=$(config_get subca)
  old_subca_config="${old_subca_config//[$'\t\r\n']}"
  log_detailed "init_demo: old_subca_config ${old_subca_config}"
  config set subca daniel Daniel Korac Vladimir D.K.
  log_detailed "init_demo: saving config file for daniel ${test_folder_data}subca-$subca-sca.config"
  config save "${test_folder_data}subca-$subca-sca.config"
  config set subca "${old_subca_config}"
  log_detailed "init_demo: current subca ${subca}"

  # ------------------------
  # transfer subca requests
  # ------------------------
  init_demo_switch_to "ca" "$test_folder_data"
  log_detailed "init_demo: transfering subca requests to ca... subca_transfer_folder ${subca_transfer_folder} transfer_folder ${transfer_folder}"
  mv ${subca_transfer_folder}*.tgz ${transfer_folder}
  # ----------------------------
  # ca import requests
  # -----------------------------
  log_detailed "init_demo: importing subca requests into ca..."
  import
  # ------------------
  # ca approve subca's
  # -------------------
  log_detailed "init_demo: approving subca requests..."
  # approve subca without parameters
  approve subca
  # approve subca with parameters
  approve subca daniel
  log_detailed "init_demo: current subca (after approve) ${subca}"

  # ------------------------
  # transfer subca certificates
  # ------------------------
  log_detailed "init_demo: transfering subca certificates to subca..."
  init_demo_switch_to "subca" "$test_folder_data"
  mv ${ca_transfer_folder}*.tgz ${transfer_folder}
  # -------------------------
  # subca import certificates
  # -------------------------
  log_detailed "init_demo: subca importing certificates.."
  import
  # -------------------------
  # create user request
  # -------------------------
  log_detailed "init_demo: creating user request.."
  init_demo_switch_to "user" "$test_folder_data"
  # save filip-user configuration
  config save "${test_folder_data}user-$user-sca.config"
  request user
  # ------------------------
  # transfer user request
  # ------------------------
  log_detailed "init_demo: transfering user requests to subca..."
  init_demo_switch_to "subca" "$test_folder_data"
  mv ${user_transfer_folder}*.tgz ${transfer_folder}
  # ----------------------------
  # subca import requests
  # -----------------------------
  log_detailed "init_demo: importing user requests into subca..."
  import
  # --------------------------
  # subca approve user request
  # --------------------------
  log_detailed "init_demo: approving user request.."
  # approve user without parameters
  approve user
  # --------------------------
  # transfer user certificate
  # --------------------------
  log_detailed "init_demo: transfering user certificates to user..."
  init_demo_switch_to "user" "$test_folder_data"
  mv ${subca_transfer_folder}*.tgz ${transfer_folder}
  # --------------------------
  # user import certificate
  # --------------------------
  log_detailed "init_demo: user importing certicates.."
  import
  # -------------------------------------
  # user creates host and service request
  # -------------------------------------
  log_detailed "init_demo: creating host and service request.."
  request host
  request service
  request service gitlab
  request service k8s-dashboard
  request service k8s-monitoring
  request service heketi
  # -------------------------------
  # transfer user requests to subca
  # -------------------------------
  log_detailed "init_demo: transfering user requests to subca..."
  init_demo_switch_to "subca" "$test_folder_data"
  mv ${user_transfer_folder}*.tgz ${transfer_folder}
  # ----------------------------
  # subca import requests
  # -----------------------------
  log_detailed "init_demo: importing user requests into subca..."
  import
  # --------------------------
  # subca approve user request
  # --------------------------
  log_detailed "init_demo: approving user requests.."
  # approve host and service without parameters
  approve host
  approve service
  approve service gitlab
  approve service k8s-dashboard
  approve service k8s-monitoring
  approve service heketi
  # -----------------------------------------------
  # transfer host and service certificates to user
  # ------------------------------------------------
  log_detailed "init_demo: transfering host and service certificates to user..."
  init_demo_switch_to "user" "$test_folder_data"
  mv ${subca_transfer_folder}*.tgz ${transfer_folder}
  # --------------------------
  # user import certificates
  # --------------------------
  log_detailed "init_demo: user importing certicates.."
  import

  log_detailed "init_demo: finish (test_folder_data=${test_folder_data})"
}
init_demo_help() {
  echo "
@@@HELP@@@
    "
}
################################################################################
# utility function for demo initialization for switching the user/entity context
#
# parameters
#   user_kind
#     kind of user we want to perform the following sca actions as
#     allowed values are 'ca' 'subca' and 'user'
#   test_folder_data
#     root folder in which to keep the test data
#
init_demo_switch_to () {
  local user_kind=$1
  local test_folder_data=$2
  log_detailed "init_demo_switch_to: start (user_kind=${user_kind},test_folder_data=${test_folder_data} transfer_folder ${transfer_folder})"
  case "$user_kind" in
    ca|subca|user)
      log_detailed "init_demo_switch_to: switching to environment of role $user_kind and ensuring it's key and transfer folders exist"
      # load ca configuration
      export key_folder=${test_folder_data}${user_kind}-key/
      export transfer_folder=${test_folder_data}${user_kind}-transfer/
      config resolve
      mkdir -p ${key_folder}
      mkdir -p ${transfer_folder}
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$user_kind' for user_kind (first) argument.
        supported values are 'ca' 'subca' 'user'.
____EOM
      error "$message" 1
      ;;
  esac
  log_detailed "init_demo_switch_to: finish (user_kind=${user_kind},test_folder_data=${test_folder_data})"
}
