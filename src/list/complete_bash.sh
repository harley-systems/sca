_sca_list_complete() {
  local list_verb_index=$1
  local entity_index=$((list_verb_index+1))

  while [[ ${COMP_WORDS[$entity_index]} == -* ]]; do
    if [ $COMP_CWORD == $entity_index ]; then
      suggestions=($(compgen -W "-h -o --help --output-format" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    if [ ${COMP_WORDS[$entity_index]} == --output-format ] || [ ${COMP_WORDS[$entity_index]} == -o ]; then
      if [  $((entity_index+1)) == $COMP_CWORD ]; then
        suggestions=($(compgen -W "ids wide" -- "$current_word"))
        COMPREPLY=("${suggestions[@]}")
        return
      else
        # following option at $sca_verb_index+1 is not the current word.

        # check if the configuration file has been already specified after the
        # current option at $sca_verb_index
        if [ $((entity_index+1)) -lt ${#COMP_WORDS[@]} ]; then

          # the configuration file has been already specified after the
          # current option

          local output_format=${COMP_WORDS[$((entity_index+1))]}

          entity_index=$((entity_index+1))
        fi
      fi
    fi

    entity_index=$((entity_index+1))
  done

  if [ -z "${COMP_WORDS[$entity_index]}" ]; then
    suggestions=($(compgen -W "cas subcas hosts services users configs all" -- "$current_word"))
  else
    case "${COMP_WORDS[$entity_index]}" in
      cas|subcas|hosts|services|users|configs|all)
        :
        ;;
      *)
        suggestions=($(compgen -W "cas subcas hosts services users configs all" -- "$current_word"))
        ;;
    esac
  fi


}
