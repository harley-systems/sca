_sca_config_complete() {
  local config_verb_index=$1
  local config_operation_index=$((config_verb_index+1))

  while [[ ${COMP_WORDS[$config_operation_index]} == -* ]]; do
    if [ $COMP_CWORD == $config_operation_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    config_operation_index=$((config_operation_index+1))
  done


  if [ -z "${COMP_WORDS[$config_operation_index]}" ]; then
    suggestions=($(compgen -W "create resolve set get load save reset" -- "$current_word"))
  else
    case "${COMP_WORDS[$config_operation_index]}" in
      create)
        _sca_config_create_complete $config_operation_index
        ;;
      get)
        _sca_config_get_complete $config_operation_index
        ;;
      load)
        _sca_config_load_complete $config_operation_index
        ;;
      reset)
        _sca_config_reset_complete $config_operation_index
        ;;
      resolve)
        _sca_config_resolve_complete $config_operation_index
        ;;
      save)
        _sca_config_save_complete $config_operation_index
        ;;
      set)
        _sca_config_set_complete $config_operation_index
        ;;
      *)
        suggestions=($(compgen -W "create resolve set get load save reset" -- "$current_word"))
        ;;
    esac
  fi
}
_sca_config_create_complete() {
  local create_verb_index=$1
  local entity_index=$((create_verb_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -r --help --recreate" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    entity_index=$((entity_index+1))
  done

  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user all" -- "$current_word"))
  else
      case "${COMP_WORDS[$entity_index]}" in
        ca|subca|host|service|user|all)
          :
          ;;
        *)
          suggestions=($(compgen -W "ca subca host service user all" -- "$current_word"))
          ;;
      esac
  fi
}
_sca_config_get_complete() {
  local get_verb_index=$1
  local entity_index=$((get_verb_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    entity_index=$((entity_index+1))
  done

  local entity_id_index=$((entity_index+1))
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
      case "${COMP_WORDS[$entity_index]}" in
        ca|subca|host|service|user)
          if [ $entity_id_index == $COMP_CWORD ]; then
            if [ -z $config_file ]; then
              entities=$(sca list ${COMP_WORDS[$entity_index]}s)
            else
              entities=$(sca -c $config_file list ${COMP_WORDS[$entity_index]}s)
            fi
            suggestions=($(compgen -W "$entities" -- "$current_word"))
          fi
          ;;
        *)
          suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
          ;;
      esac
  fi
}
_sca_config_load_complete() {
  local load_verb_index=$1
  local config_file_index=$((load_verb_index+1))

  while [[ ${COMP_WORDS[$config_file_index]} == -* ]]; do
    if [ $COMP_CWORD == $config_file_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    config_file_index=$((config_file_index+1))
  done

  if [ -z "${COMP_WORDS[$config_file_index]}" ]; then
    if [ -z $config_file ]; then
      confgurations=$(sca list configs)
    else
      confgurations=$(sca -c $config_file list configs)
    fi
    suggestions=($(compgen -W "$confgurations" -- "$current_word"))
  else
    if [ $config_file_index == $COMP_CWORD ]; then
      if [ -z $config_file ]; then
        confgurations=$(sca list configs)
      else
        confgurations=$(sca -c $config_file list configs)
      fi
      suggestions=($(compgen -W "$confgurations" -- "$current_word"))
    fi
  fi
}
_sca_config_reset_complete() {
  local reset_verb_index=$1
  local options_index=$((reset_verb_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done
}
_sca_config_resolve_complete() {
  local resolve_verb_index=$1
  local options_index=$((resolve_verb_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done
}
_sca_config_save_complete() {
  local save_verb_index=$1
  local options_index=$((save_verb_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done
}
_sca_config_set_complete() {
  local set_verb_index=$1
  local entity_index=$((set_verb_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    entity_index=$((entity_index+1))
  done

  local entity_id_index=$((entity_index+1))
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
  else
      case "${COMP_WORDS[$entity_index]}" in
        ca|subca|host|service|user)
          if [ $entity_id_index == $COMP_CWORD ]; then
            if [ -z $config_file ]; then
              entities=$(sca list ${COMP_WORDS[$entity_index]}s)
            else
              entities=$(sca -c $config_file list ${COMP_WORDS[$entity_index]}s)
            fi
            suggestions=($(compgen -W "$entities" -- "$current_word"))
          fi
          ;;
        *)
          suggestions=($(compgen -W "ca subca host service user" -- "$current_word"))
          ;;
      esac
  fi
}
