################################################################################
# create a secrurity related document
#
# parameters
#   document_type
#     the type of security document you want to create
#     allowed values are
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
#         'crt_pub_ssh'
#           macro for referring to certificate, public key and public key in ssh form.
#   entity
#     the entity for which to export public documents
#     allowed values are 'ca' 'subca' 'user' 'host' and 'service'
#
create() {
  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      create_help
      return
      ;;
  esac

  local document_type=$1
  log_detailed "create: start (document_type=${document_type})"
  case "$document_type" in
    key|csr|crt|crl|pub|pub_ssh|crt_pub_ssh)
      shift
      eval create_$document_type "$@"
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$document_type' for document_type (first) argument.
        supported values are 'key' 'csr' 'crt' 'crl' 'pub' 'pub_ssh' 'crt_pub_ssh'.
____EOM
      error "$message" 1
      ;;
  esac
  log_detailed "create: finish (document_type=${document_type})"
}
create_help() {
  echo "
@@@HELP@@@
"
}
