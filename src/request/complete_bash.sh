_sca_request_complete() {
  local request_verb_index=$1
  local entity_index=$((request_verb_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    entity_index=$((entity_index+1))
  done

  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
    case "${COMP_WORDS[$entity_index]}" in
      ca|subca|host|service|user)
        :
        ;;
      *)
        suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        ;;
    esac
  fi
}
