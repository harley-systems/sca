################################################################################
# export PKCS#12 (.p12) bundle for entity
#
# Creates a .p12 file containing:
#   - Entity certificate
#   - Entity private key
#   - CA chain certificates (subca + root CA)
#
# parameters
#   entity
#     the entity for which to export p12 bundle
#     allowed values are 'user' 'host' and 'service'
#
export_p12() {

  local password=""
  local friendly_name=""
  local legacy=false
  local output_file=""

  local OPTS=`getopt -o hp:n:lo: --long help,password:,friendly-name:,legacy,output: -n "export p12" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca export p12 -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        export_p12_help
        return
        ;;
      -p | --password )
        password="$2"
        shift 2
        ;;
      -n | --friendly-name )
        friendly_name="$2"
        shift 2
        ;;
      -l | --legacy )
        legacy=true
        shift
        ;;
      -o | --output )
        output_file="$2"
        shift 2
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
  log_detailed "export_p12: start (entity=${entity})"

  # validate entity
  case "$entity" in
    user|host|service)
      ;;
    *)
      error "invalid entity '$entity'. allowed values are 'user', 'host', 'service'." 1
      ;;
  esac

  # get entity files
  local entity_crt_file=$(eval echo \${${entity}_crt_file})
  local entity_key_file=$(eval echo \${${entity}_key_file})
  local entity_name=$(eval echo \${${entity}})

  # validate certificate exists
  if [ ! -f "$entity_crt_file" ]; then
    error "certificate file '${entity_crt_file}' not found. create the certificate first." 1
  fi

  # validate key exists
  if [ ! -f "$entity_key_file" ]; then
    error "private key file '${entity_key_file}' not found." 1
  fi

  # validate CA certificates exist
  if [ ! -f "$subca_crt_file" ]; then
    error "sub-CA certificate file '${subca_crt_file}' not found." 1
  fi
  if [ ! -f "$ca_crt_file" ]; then
    error "root CA certificate file '${ca_crt_file}' not found." 1
  fi

  # prompt for password if not provided
  if [ -z "$password" ]; then
    read -s -p "Enter export password: " password
    echo
    read -s -p "Confirm export password: " password_confirm
    echo
    if [ "$password" != "$password_confirm" ]; then
      error "passwords do not match." 1
    fi
  fi

  # set friendly name if not provided
  if [ -z "$friendly_name" ]; then
    friendly_name="${entity_name}"
  fi

  # create temporary CA chain file
  local ca_chain_file=$(mktemp)
  cat "$subca_crt_file" "$ca_crt_file" > "$ca_chain_file"

  # set output file if not provided
  if [ -z "$output_file" ]; then
    local entity_transfer_folder=$(eval echo \${${entity}_transfer_files_folder})
    mkdir -p "$entity_transfer_folder"
    output_file="${entity_transfer_folder}${entity_name}.p12"
  fi

  # build openssl command
  local openssl_opts=""
  if [ "$legacy" = true ]; then
    # use legacy algorithms for compatibility with older software
    openssl_opts="-legacy"
  fi

  log_detailed "export_p12: creating p12 file '${output_file}'"
  log_detailed "export_p12: certificate='${entity_crt_file}'"
  log_detailed "export_p12: key='${entity_key_file}'"
  log_detailed "export_p12: ca_chain='${ca_chain_file}'"
  log_detailed "export_p12: friendly_name='${friendly_name}'"
  log_detailed "export_p12: legacy=${legacy}"

  # create p12 file
  openssl pkcs12 -export \
    -in "$entity_crt_file" \
    -inkey "$entity_key_file" \
    -certfile "$ca_chain_file" \
    -out "$output_file" \
    -passout pass:"$password" \
    -name "$friendly_name" \
    $openssl_opts

  local result=$?

  # clean up temp file
  rm -f "$ca_chain_file"

  if [ $result -ne 0 ]; then
    error "failed to create p12 file." $result
  fi

  echo "p12 file created: ${output_file}"
  log_detailed "export_p12: finish (entity=${entity}, output=${output_file})"
}
export_p12_help() {
  echo "
@@@HELP@@@
  "
}
