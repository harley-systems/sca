################################################################################
# print security document to standard output in human readable form
#
# parameters
#   document_type
#     the type of security document you want to create
#     allowed values are:
#         'key'
#           private key
#         'csr'
#           certificate signature request
#         'crt'
#           x509 certificate in pkcs8 form in a pem file
#         'pub'
#           public key in pkcs8 form in a pem file
#         'pub_ssh'
#           public key in format suitable for OpenSSH.
#   entity
#     the entity for which to display the document
#     allowed valuethe simple certificate authority is a shell script that
#     addresses this challenges are 'ca' 'user' 'host' and 'service'
#
display() {

  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      display_help
      return
      ;;
  esac

  local document_type=$1
  local entity=$2
  local entity_id=$3

  log_detailed "display: start (document_type=${document_type}, entity=${entity}, entity_id=${entity_id})"

  case "$document_type" in
    csr|crt)
      shift
      eval display_$document_type "$@"
    ;;
    key|pub|pub_ssh)
      OPTS=`getopt -o h --long help -n "display $document_type" -- "$@"`
      if [ $? != 0 ] ; then error "failed parsing options. use sca display $document_type -h for help." 1; fi
      eval set -- "$OPTS"
      while true; do
        case "$1" in
          -h | --help )
            display_generic_help
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
      local current_entity_id=$(get_current_entity_id $entity)
      local old_entity=''
      if ! [ -z "$entity_id" ] && [[ "$entity_id" != $current_entity_id ]]; then
        old_entity=$(config_get $entity)
        old_entity="${old_entity//[$'\t\r\n']}}"
        #old_entity=${old_entity//\"/\\\"}
        log_detailed "display: old_entity saved ${old_entity}"
        new_entity=$(config_get $entity $entity_id)
        new_entity="${new_entity//[$'\t\r\n']}}"
        new_entity=${new_entity@Q}
        log_detailed "display: temporarily setting configuration for ${entity} to ${new_entity}"
        config_set $entity ${new_entity}
      fi
      local entity_document_file=$(eval echo \$${entity}_${document_type}_file)
      if [ ! -f "${entity_document_file}" ]; then
        if [ "$document_type" = "key" ]; then
          error "the security document is not available." 1
        else
          local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
          if [ $entity_use_security_key = false ]; then
            error "the security document is not available." 1
          else
            # create pub_ssh and in turn pub and crt files in file system
            if [ "$document_type" = "pub" ]; then
              create_pub $entity
            else
              create_pub_ssh $entity
            fi
          fi
        fi
      fi
      cat $entity_document_file
      if ! [ -z "$old_entity" ]; then
        log_detailed "display: setting entity back for ${entity} to ${old_entity}"
        config_set ${entity} ${old_entity}
      fi
    ;;
    *)
      read -r -d '' message <<- ____EOM
      invalid value '$document_type' for document_type (first) argument.
      supported values are 'key' 'csr' 'crt' 'pub' 'pub_ssh'.
      use sca display -h for help.
____EOM
      error "$message" 1
    ;;
  esac


  log_detailed "display: finish (document_type=${document_type}, entity=${entity})"

}
display_help() {
  echo "
@@@HELP@@@
  "
}
display_generic_help() {
  echo "
@@@GENERIC HELP@@@
  "
}
