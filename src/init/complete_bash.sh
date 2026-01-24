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
      suggestions=($(compgen -W "-h -s -t -i -x -y -q -o -n --help --skip-cleanup --test-image --include-apt-mirror --exclude-pkcs11-support --yubikey-support --no-cache-squashfs --no-cache-iso --no-cache" -- "$current_word"))
      COMPREPLY=("${suggestions[@]}")
      return
    fi
    ubuntu_version_id_index=$((ubuntu_version_id_index+1))
  done

  if [ -z "${COMP_WORDS[$ubuntu_version_id_index]}" ]; then
    suggestions=($(compgen -W "18.04.1-bionic 16.04.4-xenial 16.04.3-xenial 16.04.2-xenial 16.04.1-xenial 14.04.5-trusty 14.04.4-trusty 14.04.3-trusty 14.04.2-trusty 14.04.1-trusty" -- "$current_word"))
  else
      case "${COMP_WORDS[$ubuntu_version_id_index]}" in
        18.04.01-bionic|16.04.04-xenial|16.04.03-xenial|16.04.02-xenial|16.04.01-xenial|14.04.05-trusty|14.04.04-trusty|14.04.03-trusty|14.04.02-trusty|14.04.01-trusty)
          :
          ;;
        *)
          suggestions=($(compgen -W "18.04.1-bionic 16.04.4-xenial 16.04.3-xenial 16.04.2-xenial 16.04.1-xenial 14.04.5-trusty 14.04.4-trusty 14.04.3-trusty 14.04.2-trusty 14.04.1-trusty" -- "$current_word"))
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
