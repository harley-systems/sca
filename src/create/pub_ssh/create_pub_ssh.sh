################################################################################
# create public key in form suitable for ssh
#
# parameters
#   entity
#     the entity for which to create the public key file in ssh format
#     allowed values are 'ca' 'user' 'host' and 'service'
#
create_pub_ssh() {
  local force=false
  local OPTS=`getopt -o hf --long help,force -n 'create pub_ssh' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca create pub_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_pub_ssh_help
        return
      ;;
      -f | --force )
        force=true;
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
  log_detailed "create_pub_ssh: start (entity='${entity}', force='${force}')"

  local entity_pub_file=$(eval echo \${${entity}_pub_file})
  local entity_pub_ssh_file=$(eval echo \${${entity}_pub_ssh_file})
  if [ -f $entity_pub_ssh_file ]; then
    if [ $force = false ]; then
      error "create_pub_ssh: the '$entity_pub_ssh_file' already exists. use "\
"--force to backup existing, and generate new one." 1
    else
      mv "$entity_pub_ssh_file" "$entity_pub_ssh_file.$RANDOM.bak"
    fi
  fi
  if ! [ -f $entity_pub_file ]; then
    local entity_use_security_key=$(eval echo \$${entity}_use_security_key)
    if [ $entity_use_security_key = false ]; then
      error "create_pub_ssh: the entity public key not found in file-system and "\
        "the entity is not stored on secure key. please, check the configuration." 1
    else
      create_pub "$entity"
    fi
  fi
  local ssh_keygen_command="ssh-keygen \
    -i \
    -mPKCS8 \
    -f $entity_pub_file \
    > $entity_pub_ssh_file"

  log_verbose "$ssh_keygen_command"
  eval "$ssh_keygen_command"

  log_detailed "create_pub_ssh: finish (entity='${entity}', force='${force}')"
}
create_pub_ssh_help() {
  echo "
@@@HELP@@@
"
}
