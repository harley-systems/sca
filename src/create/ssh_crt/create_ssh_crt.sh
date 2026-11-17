################################################################################
# create an OpenSSH certificate for a user or a host, signed by a ca or subca
#
# parameters
#   entity
#     the entity whose OpenSSH public key is certified
#     allowed values are 'user' and 'host'
#   sign_by_entity
#     the entity to use to sign the certificate
#     allowed values are 'ca' and 'subca'
#     default value - 'subca'
#
create_ssh_crt() {
  local force=false
  local validity=''
  local principals=''
  local pub_file=''
  local OPTS
  OPTS=$(getopt -o hf --long help,force,validity:,principals:,pub: \
    -n 'create ssh_crt' -- "$@")
  if [ $? != 0 ] ; then
    error "failed parsing options. use sca create ssh_crt -h for help." 1
  fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        create_ssh_crt_help
        return
      ;;
      -f | --force )
        force=true
        shift
      ;;
      --validity )
        validity=$2
        shift 2
      ;;
      --principals )
        principals=$2
        shift 2
      ;;
      --pub )
        pub_file=$2
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
  local entity="$1"
  local sign_by_entity="${2:-subca}"
  log_detailed "create_ssh_crt: start (entity='${entity}', "\
"sign_by_entity='${sign_by_entity}', force='$force')"

  case "$entity" in
    user|host ) ;;
    * )
      error "create_ssh_crt: invalid entity '$entity'. supported values are "\
"'user' and 'host'." 1
    ;;
  esac
  case "$sign_by_entity" in
    ca|subca ) ;;
    * )
      error "create_ssh_crt: invalid signing entity '$sign_by_entity'. "\
"supported values are 'ca' and 'subca'." 1
    ;;
  esac
  if ! command -v ssh-keygen > /dev/null; then
    error "create_ssh_crt: ssh-keygen not found. install the OpenSSH client "\
"(on ubuntu: sudo apt install openssh-client)." 1
  fi

  # a config or conventions file made before ssh_crt existed has none of the
  # settings below, so they fall back to the same defaults new files get
  [ -z "$validity" ] && validity="${ssh_crt_validity:-${ssh_crt_validity_default:-+52w}}"
  local entity_filename_prefix_name="${entity}_filename_prefix"
  local entity_filename_prefix="${!entity_filename_prefix_name}"
  local entity_cert_file_name="${entity}_pub_ssh_cert_file"
  local entity_cert_file="${!entity_cert_file_name}"
  [ -z "$entity_cert_file" ] && entity_cert_file="${entity_filename_prefix}pub-ssh-cert.pub"
  local identity cert_type_option=()
  if [ "$entity" = user ]; then
    # the principal must match the login name on the server, so it is the
    # account id (user), not the display name (user_name)
    identity="${user}@${full_domain}"
    [ -z "$principals" ] && principals="$user"
  else
    local fqdn="${host_dns_name:-${host}.${full_domain}}"
    identity="$fqdn"
    [ -z "$principals" ] && principals="$fqdn"
    cert_type_option=(-h)
  fi

  # the key to sign
  if [ -z "$pub_file" ]; then
    local pub_file_name="${entity}_pub_ssh_file"
    pub_file="${!pub_file_name}"
    if [ ! -s "$pub_file" ]; then
      error "create_ssh_crt: the OpenSSH public key of '$entity' ($pub_file) "\
"was not found. create it with 'sca create pub_ssh $entity', or name another "\
"public key with --pub <file>." 1
    fi
  elif [ ! -f "$pub_file" ]; then
    error "create_ssh_crt: the public key file '$pub_file' was not found." 1
  fi
  if grep -q "PRIVATE KEY" "$pub_file" || ! ssh-keygen -l -f "$pub_file" > /dev/null 2>&1; then
    error "create_ssh_crt: '$pub_file' is not an OpenSSH public key. it should "\
"hold a single line such as 'ssh-ed25519 AAAA... comment'." 1
  fi

  # refuse before signing, so that a refusal never costs a pin or a touch. the
  # backup waits until the new certificate is signed, so a failed signing
  # leaves the existing one in place.
  if [ -f "$entity_cert_file" ] && [ $force = false ]; then
    error "create_ssh_crt: the '$entity_cert_file' already exists. use "\
"--force to backup existing, and generate new one." 1
  fi

  # the signer: a configured security key wins over a key file, as in create crt
  local sign_by_entity_key_file_name="${sign_by_entity}_key_file"
  local sign_by_entity_key_file="${!sign_by_entity_key_file_name}"
  local sign_by_entity_use_security_key_name="${sign_by_entity}_use_security_key"
  local sign_by_entity_use_security_key="${!sign_by_entity_use_security_key_name}"
  local sign_by_entity_pub_ssh_file_name="${sign_by_entity}_pub_ssh_file"
  local sign_by_entity_pub_ssh_file="${!sign_by_entity_pub_ssh_file_name}"
  local use_token=false
  if [ "$sign_by_entity_use_security_key" = true ]; then
    use_token=true
    if [ -f "$sign_by_entity_key_file" ]; then
      (>&2 echo "warning: '$sign_by_entity' is configured to use a security key, but a "\
"private key file for it also exists at $sign_by_entity_key_file - the security key will be "\
"used. that file is a copy of a key meant to never leave the token, so "\
"consider removing it.")
    fi
  elif [ ! -f "$sign_by_entity_key_file" ]; then
    error "create_ssh_crt: unable to find the key file $sign_by_entity_key_file "\
"for the '$sign_by_entity' entity, and it is not configured to use a security key." 1
  fi
  # the CA public key: ssh-keygen picks the token key matching it, and it is
  # the line servers and clients are told to trust
  if [ ! -s "$sign_by_entity_pub_ssh_file" ]; then
    log_detailed "create_ssh_crt: creating the missing $sign_by_entity_pub_ssh_file"
    create_pub_ssh --force "$sign_by_entity"
    [ -s "$sign_by_entity_pub_ssh_file" ] || error "create_ssh_crt: could not "\
"create the OpenSSH public key of '$sign_by_entity' ($sign_by_entity_pub_ssh_file)." 1
  fi

  # ssh-keygen writes <input minus .pub>-cert.pub next to its input, so the key
  # is signed in a work folder and the certificate moved to its place after
  local work_folder
  work_folder=$(mktemp -d) || error "create_ssh_crt: could not create a temporary folder." 1
  trap "rm -rf '$work_folder'" EXIT
  cp "$pub_file" "$work_folder/key.pub"

  # -q: ssh-keygen's "Signed ... key" line names the temporary file; the real
  # path is printed below. errors and the PIN prompt are still shown.
  local ssh_keygen_command=(ssh-keygen -q)
  local ssh_keygen_env=()
  if [ $use_token = true ]; then
    local ykcs11_module_path
    ykcs11_module_path=$(security_key_ykcs11_module) || exit $?
    security_key_wait_for "$sign_by_entity" > /dev/null || exit $?
    ssh_keygen_command+=(-s "$sign_by_entity_pub_ssh_file" -D "$ykcs11_module_path")
    # ssh-keygen reads the token PIN from the terminal, never from stdin, and
    # -P would put it on the command line. an askpass helper hands it the PIN
    # file's content instead; only the file's path is ever in the environment.
    local pin_file
    pin_file=$(get_yubikey_pin_file_parameter "$sign_by_entity")
    if [ -n "$pin_file" ]; then
      log_detailed "create_ssh_crt: the PIN is read from $pin_file"
      printf '#!/bin/sh\nexit 0\n' > "$work_folder/probe"
      printf '#!/bin/sh\nexec cat "$SCA_SSH_CRT_PIN_FILE"\n' > "$work_folder/askpass"
      chmod 700 "$work_folder/probe" "$work_folder/askpass"
      "$work_folder/probe" 2> /dev/null || error "create_ssh_crt: can not "\
"run programs from the temporary folder $work_folder, which ssh-keygen needs to "\
"be handed the PIN. set TMPDIR to a folder that allows it." 1
      ssh_keygen_env=(SCA_SSH_CRT_PIN_FILE="$pin_file" \
        SSH_ASKPASS="$work_folder/askpass" SSH_ASKPASS_REQUIRE=force)
    fi
    warn_yubikey_touch_expected "$sign_by_entity"
  else
    log_detailed "create_ssh_crt: signing with the key file $sign_by_entity_key_file"
    ssh_keygen_command+=(-s "$sign_by_entity_key_file")
  fi
  ssh_keygen_command+=("${cert_type_option[@]}" -I "$identity" \
    -n "$principals" -V "$validity" "$work_folder/key.pub")

  log_verbose "$(printf '%q ' "${ssh_keygen_command[@]}")"
  if ! env "${ssh_keygen_env[@]}" "${ssh_keygen_command[@]}" < /dev/null; then
    error "create_ssh_crt: error while running ssh-keygen to sign the key." 1
  fi
  [ -f "$entity_cert_file" ] && mv "$entity_cert_file" "$entity_cert_file.$RANDOM.bak"
  mkdir -p "$(dirname "$entity_cert_file")"
  mv "$work_folder/key-cert.pub" "$entity_cert_file" || \
    error "create_ssh_crt: could not write $entity_cert_file." 1
  rm -rf "$work_folder"
  trap - EXIT
  log_detailed "create_ssh_crt: certificate
$(ssh-keygen -L -f "$entity_cert_file")"

  echo "OpenSSH $entity certificate written to $entity_cert_file"
  echo
  if [ "$entity" = user ]; then
    cat <<____EOM
next steps:
  - on each server, copy $sign_by_entity_pub_ssh_file
    to /etc/ssh/, add to sshd_config
      TrustedUserCAKeys /etc/ssh/$(basename "$sign_by_entity_pub_ssh_file")
    and reload sshd.
  - on the client, put the certificate next to the private key as
    <private key>-cert.pub; ssh picks it up from there. for a key held by an
    agent or a token, add to ~/.ssh/config
      CertificateFile $entity_cert_file
____EOM
  else
    cat <<____EOM
next steps:
  - on the host, copy the certificate to /etc/ssh/, add to sshd_config
      HostCertificate /etc/ssh/$(basename "$entity_cert_file")
    and reload sshd.
  - on each client, add to ~/.ssh/known_hosts
      @cert-authority *.${full_domain} $(cat "$sign_by_entity_pub_ssh_file")
____EOM
  fi

  log_detailed "create_ssh_crt: finish (entity='${entity}', "\
"sign_by_entity='${sign_by_entity}', force='$force')"
}
create_ssh_crt_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
