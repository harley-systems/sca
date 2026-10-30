_sca_init_complete() {
  local init_verb_index=$1
  local system_index=$((init_verb_index+1))

  while [[ ${COMP_WORDS[$system_index]} == -* ]]; do
    if [ $COMP_CWORD == $system_index ]; then
      suggestions=($(compgen -W "-h -s -t -i --help --skip-cleanup --test-image --include-apt-mirror" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    system_index=$((system_index+1))
  done


  if [ -z "${COMP_WORDS[$system_index]}" ]; then
    suggestions=($(compgen -W "yubikey openssl_ca_db sca_usb_stick demo" -- "$current_word"))
  else
    case "${COMP_WORDS[$system_index]}" in
      yubikey)
        _sca_init_yubikey_complete $system_index
        ;;
      openssl_ca_db)
        _sca_init_openssl_ca_db_complete $system_index
        ;;
      sca_usb_stick)
        _sca_init_sca_usb_stick_complete $system_index
        ;;
      demo)
        _sca_init_demo_complete $system_index
        ;;
      *)
        suggestions=($(compgen -W "yubikey openssl_ca_db sca_usb_stick demo" -- "$current_word"))
        ;;
    esac
  fi

}
_sca_init_yubikey_complete() {
  local yubikey_index=$1
  local options_index=$((yubikey_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h -r --help --roll_keys" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done
}
_sca_init_openssl_ca_db_complete() {
  local openssl_ca_db_index=$1
  local options_index=$((openssl_ca_db_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done
}
_sca_init_sca_usb_stick_complete() {
  local sca_usb_stick_index=$1
  local ubuntu_version_id_index=$((sca_usb_stick_index+1))

  while [[ ${COMP_WORDS[$ubuntu_version_id_index]} == -* ]]; do
    if [ $COMP_CWORD == $ubuntu_version_id_index ]; then
      suggestions=($(compgen -W "-h -s -t -i -x -y -o -n --help --skip-cleanup --test-image --include-apt-mirror --exclude-pkcs11-support --yubikey-support --no-cache-iso --no-cache" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    ubuntu_version_id_index=$((ubuntu_version_id_index+1))
  done

  if [ -z "${COMP_WORDS[$ubuntu_version_id_index]}" ]; then
    suggestions=($(compgen -W "@@@UBUNTU VERSION ID@@@" -- "$current_word"))
  else
      case "${COMP_WORDS[$ubuntu_version_id_index]}" in
        @@@UBUNTU VERSION ID@@@)
          :
          ;;
        *)
          suggestions=($(compgen -W "@@@UBUNTU VERSION ID@@@" -- "$current_word"))
          ;;
      esac
  fi
}
_sca_init_demo_complete() {
  local demo_index=$1
  local options_index=$((demo_index+1))

  while [[ ${COMP_WORDS[$options_index]} == -* ]]; do
    if [ $COMP_CWORD == $options_index ]; then
      suggestions=($(compgen -W "-h --help" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    options_index=$((options_index+1))
  done

}
