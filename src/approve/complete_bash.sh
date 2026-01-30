_sca_approve_complete() {
  local approve_index=$1
  local entity_index=$((approve_index+1))

  # find the sca verb index on the command line by skipping over any options
  # that are specified on the command line
  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    # ${COMP_WORDS[$sca_verb_index]} is an option

    # in case the cursor is at the current $sca_verb_index word, return
    # sca options as completion suggestions
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h --help -f --force -s --sign-by" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi

    # the cursor is not on the current $sca_verb_index

    # check if current option at $sca_verb_index is the configuration file option
    if [ ${COMP_WORDS[$entity_index]} == --sign-by ] || [ ${COMP_WORDS[$entity_index]} == -s ]; then

      # check if the cursor is now on the next option to process. in other words
      # check if the following option at $entity_index+1 is the current word
      if [  $((entity_index+1)) == $COMP_CWORD ]; then

        # cursor is now on the next option to process, after the -s option. completing...

        suggestions=($(compgen -W "ca subca" -- "$current_word"))
        COMPREPLY=("${suggestions[@]}")
        return
      else

        # following option at $sca_verb_index+1 is not the current word.

        # check if the configuration file has been already specified after the
        # current option at $sca_verb_index
        if [ $((entity_index+1)) -lt ${#COMP_WORDS[@]} ]; then

          # the configuration file has been already specified after the
          # current option

          sign_by_entity=${COMP_WORDS[$((entity_index+1))]}

          entity_index=$((entity_index+1))
        fi
      fi
    fi
    entity_index=$((entity_index+1))
  done


  local entity_id_index=$((entity_index+1))
  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "subca host service user" -- "$current_word"))
  else
      case "${COMP_WORDS[$entity_index]}" in
        subca|host|service|user)
          if [ $entity_id_index == $COMP_CWORD ]; then
            local entity_ids=$(sca list ${COMP_WORDS[$entity_index]}s)
            suggestions=($(compgen -W "$entity_ids" -- "$current_word"))
          fi
          ;;
        *)
          suggestions=($(compgen -W "subca host service user" -- "$current_word"))
          ;;
      esac
  fi
}
