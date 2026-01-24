_sca_create_complete() {
  local create_verb_index=$1
  local document_type_index=$((create_verb_index+1))

  while [[ ${COMP_WORDS[$document_type_index]} == -* ]]; do
    if [ $COMP_CWORD == $document_type_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    document_type_index=$((document_type_index+1))
  done

  if [ -z "${COMP_WORDS[$document_type_index]}" ]; then
    suggestions=($(compgen -W "key csr crt pub pub_ssh crt_pub_ssh" -- "$current_word"))
  else
    case "${COMP_WORDS[$document_type_index]}" in
      key)
        _sca_create_key_complete $document_type_index
        ;;
      csr)
        _sca_create_csr_complete $document_type_index
        ;;
      crt)
        _sca_create_crt_complete $document_type_index
        ;;
      pub)
        _sca_create_pub_complete $document_type_index
        ;;
      pub_ssh)
        _sca_create_pub_ssh_complete $document_type_index
        ;;
      crt_pub_ssh)
        _sca_create_crt_pub_ssh_complete $document_type_index
        ;;
      *)
        suggestions=($(compgen -W "key csr crt pub pub_ssh crt_pub_ssh" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_create_crt_complete() {
  local crt_index=$1
  local entity_index=$((crt_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    entity_index=$((entity_index+1))
  done

  local sign_by_index=$((entity_index+1))
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case  "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        if [ $COMP_CWORD == $sign_by_index ]; then
          suggestions=($(compgen -W "ca subca user" -- "$current_word"))
        fi
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_create_crt_pub_ssh_complete() {
  local crt_pub_ssh_index=$1
  local entity_index=$((crt_pub_ssh_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
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
_sca_create_csr_complete() {
  local csr_index=$1
  local entity_index=$((csr_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
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
_sca_create_key_complete() {
  local key_index=$1
  local entity_index=$((key_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
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
_sca_create_pub_complete() {
  local pub_index=$1
  local entity_index=$((pub_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
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
_sca_create_pub_ssh_complete() {
  local pub_ssh_index=$1
  local entity_index=$((pub_ssh_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -f --help --force" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
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
