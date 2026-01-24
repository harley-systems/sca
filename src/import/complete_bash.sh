_sca_import_complete() {
  local import_verb_index=$1
  local options_index=$((import_verb_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done

}
