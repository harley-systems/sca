_sca_install_complete() {
  local install_verb_index=$1
  local option_index=$((install_verb_index+1))

  while [[ ${COMP_WORDS[$option_index]} == -* ]]; do
    if [ $COMP_CWORD == $option_index ]; then
      suggestions=($(compgen -W "-h -a -f -y -x -n --help --air-gapped --force --yubikey-support --exclude-pkcs11-support --dry-run" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi

    option_index=$((option_index+1))
  done
}
