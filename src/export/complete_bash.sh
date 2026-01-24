_sca_export_complete() {
  local export_verb_index=$1
  local document_type_index=$((export_verb_index+1))

  while [[ ${COMP_WORDS[$document_type_index]} == -* ]]; do
    if [ $COMP_CWORD == $document_type_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    document_type_index=$((document_type_index+1))
  done

  if [ -z "${COMP_WORDS[$document_type_index]}" ]; then
    suggestions=($(compgen -W "crt_pub_ssh csr p12" -- "$current_word"))
  else

    local entity_index=$((document_type_index+1))
    while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
      if [ $COMP_CWORD == $entity_index ]; then
        suggestions=($(compgen -W "-h --help" -- "$current_word"))
        COMPREPLY=("${suggestions[@]}")
        return
      fi
      entity_index=$((entity_index+1))
    done

    case "${COMP_WORDS[$document_type_index]}" in
      crt_pub_ssh|csr)
        if [ -z "${COMP_WORDS[$entity_index]}" ]; then
          suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
        else
          case "${COMP_WORDS[$entity_index]}" in
            ca|subca|host|service|user)
              local entities
              if [ -z $config_file ]; then
                entities=$(sca list ${COMP_WORDS[$entity_index]}s)
              else
                entities=$(sca -c $config_file list ${COMP_WORDS[$entity_index]}s)
              fi
              suggestions=($(compgen -W "$entities" -- "$current_word"))
              ;;
            *)
              suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
              ;;
          esac
        fi
        ;;
      p12)
        if [ -z "${COMP_WORDS[$entity_index]}" ]; then
          suggestions=($(compgen -W "host service user" -- "$current_word"))
        else
          case "${COMP_WORDS[$entity_index]}" in
            host|service|user)
              local entities
              if [ -z $config_file ]; then
                entities=$(sca list ${COMP_WORDS[$entity_index]}s)
              else
                entities=$(sca -c $config_file list ${COMP_WORDS[$entity_index]}s)
              fi
              suggestions=($(compgen -W "$entities" -- "$current_word"))
              ;;
            *)
              suggestions=($(compgen -W "host service user" -- "$current_word"))
              ;;
          esac
        fi
        ;;
      *)
        suggestions=($(compgen -W "crt_pub_ssh csr p12" -- "$current_word"))
        ;;
    esac
  fi

}
