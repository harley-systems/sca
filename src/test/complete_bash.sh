_sca_test_complete() {
  local test_verb_index=$1
  local option_index=$((test_verb_index+1))

  while [[ ${COMP_WORDS[$option_index]} == -* ]]; do
    if [ $COMP_CWORD == $option_index ]; then
      suggestions=($(compgen -W "-has --help --air-gapped --skip-air-gapped-tests" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    option_index=$((option_index+1))
  done
}
