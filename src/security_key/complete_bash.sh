_sca_security_key_complete() {
  local security_key_verb_index=$1
  local subcommand_index=$((security_key_verb_index+1))
  while [[ ${COMP_WORDS[$subcommand_index]} == -* ]]; do
    if [ $COMP_CWORD == $subcommand_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      return
    fi
    subcommand_index=$((subcommand_index+1))
  done
  if [ -z "${COMP_WORDS[$subcommand_index]}" ]; then
    suggestions=($(compgen -W "get_crt id init upload wait_for" -- "$current_word"))
  else
    case "${COMP_WORDS[$subcommand_index]}" in
      get_crt )
        _sca_security_key_get_crt_complete $subcommand_index
      ;;
      id )
        _sca_security_key_id_complete $subcommand_index
      ;;
      init )
        _sca_security_key_init_complete $subcommand_index
      ;;
      upload )
        _sca_security_key_upload_complete $subcommand_index
      ;;
      wait_for )
        _sca_security_key_wait_for_complete $subcommand_index
      ;;
      *)
        suggestions=($(compgen -W "get_crt id init upload wait_for" -- "$current_word"))
      ;;
    esac
  fi
}
_sca_security_key_get_crt_complete() {
  local get_crt_index=$1
  local entity_index=$((get_crt_index+1))
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      return
    fi
    entity_index=$((entity_index+1))
  done
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        :
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_security_key_id_complete() {
  local id_index=$1
  local entity_index=$((id_index+1))
  local type=''
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -t --help --security-key-type" -- "$current_word"))
      return
    fi
    if [ ${COMP_WORDS[$entity_index]} == --security-key-type ] || [ ${COMP_WORDS[$entity_index]} == -t ]; then
      if [  $((entity_index+1)) == $COMP_CWORD ]; then
        suggestions=($(compgen -W "yubikey pkcs11" -- "$current_word"))
        return
      else
        if [ $((entity_index+1)) -lt ${#COMP_WORDS[@]} ]; then
          type=${COMP_WORDS[$((entity_index+1))]}
          entity_index=$((entity_index+1))
        fi
      fi
    fi
    entity_index=$((entity_index+1))
  done
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        :
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_security_key_init_complete() {
  local init_index=$1
  local entity_index=$((init_index+1))
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -r --help --roll-keys" -- "$current_word"))
      return
    fi
    entity_index=$((entity_index+1))
  done
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        :
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_security_key_upload_complete() {
  local upload_index=$1
  local entity_index=$((upload_index+1))
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      return
    fi
    entity_index=$((entity_index+1))
  done
  local document_index=$((entity_index+1))
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user )
        if [ $document_index == $COMP_CWORD ]; then
          suggestions=($(compgen -W "crt key" -- "$current_word"))
        fi
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_security_key_wait_for_complete() {
  local wait_for_index=$1
  local entity_index=$((wait_for_index+1))
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      return
    fi
    entity_index=$((entity_index+1))
  done
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        :
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
