_sca_completion_complete() {
  local completion_verb_index=$1
  local shell_index=$((completion_verb_index+1))

  # find the sca verb index on the command line by skipping over any options
  # that are specified on the command line
  while [[ ${COMP_WORDS[$shell_index]} == -* ]]; do
    # ${COMP_WORDS[$sca_verb_index]} is an option

    # in case the cursor is at the current $sca_verb_index word, return
    # sca options as completion suggestions
    if [ $COMP_CWORD == $shell_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi

    shell_index=$((shell_index+1))
  done

  if [ -z "${COMP_WORDS[$shell_index]}" ]; then
    suggestions=($(compgen -W "bash" -- "$current_word"))
  else
    case "${COMP_WORDS[$shell_index]}" in
      bash)
        return
        ;;
      *)
        suggestions=($(compgen -W "bash" -- "$current_word"))
        ;;
    esac
  fi
}
