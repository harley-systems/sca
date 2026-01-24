################################################################################
# export security documents like certificates, public keys and requests
#
# the documents are stored in the {transfer_folder} in a tar gzip archive
# suitable for sending by email or other channels.
#
# parameters
#   document_type
#     the type of security document you want to create
#     allowed values are:
#         'crt_pub_ssh'
#           certificates and public key in multiple formats
#         'csr'
#           certificate signature request
#   entity  simple certificate authoriry v0.0.1
#     the entity for which to display the document
#     allowed values are 'ca' 'user' 'host' and 'service'
#
export_() {

  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      export_help
      return
      ;;
  esac


  local document_type=$1
  local entity=$2
  log_detailed "export_: start (document_type=${document_type}, entity=${entity})"
  case "$document_type" in
    crt_pub_ssh|csr|p12)
      shift
      eval export_$document_type "$@"
      ;;
    *)
    read -r -d '' message <<- ____EOM
      invalid value '$document_type' for document_type (first) argument.
      supported values are crt_pub_ssh|csr|p12.
____EOM
    error "$message" 1
    ;;
  esac
  log_detailed "export_: finish (document_type=${document_type}, entity=${entity})"
}
export_help() {
  echo "
@@@HELP@@@
    "
  }
