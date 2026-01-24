security_key_init() {
  local roll_keys=false
  OPTS=`getopt -o hr --long help,roll-keys -n "sca security_key init" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key init -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_init_help
        return
      ;;
      -r | --roll-keys )
        roll_keys=true
        shift
      ;;
      -- )
        shift
        break
      ;;
      * )
        break
      ;;
    esac
  done
  local entity="$1"
  log_detailed "security_key_init: started (roll_keys=$roll_keys, entity=$entity)"
  local allowed_values=(ca subca user service host)
  [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]] && \
    error "security_key_wait_for: invalid value supplied for entity. use sca "\
"security_key wait_for -h for help." 1
  local reader_slot_number=$(security_key_wait_for "$entity")
  # TODO: default access keys depend on security_key_type - add case for it
  local default_management_key='010203040506070801020304050607080102030405060708'
  local default_pin='123456'
  local default_puk='12345678'
  local entity_management_key_file=$(eval echo \$${entity}_yubikey_key_file)
  local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
  local entity_puk_file=$(eval echo \$${entity}_yubikey_puk_file)
  # check if the management key file already exists on the disk
  local old_management_key
  local old_pin
  local old_puk
  if [ -f "$entity_management_key_file" ] || [ -f "$entity_pin_file" ] || [ -f "$entity_puk_file" ] ; then
    if [ $roll_keys = false ]; then
      error "security_key_init: management file, pin and/or puk file already exist."\
"In case you want to roll existing keys use the --roll-keys parameter." 1
    else
      if [ -f "$entity_management_key_file" ] && [ -f "$entity_pin_file" ] && [ -f "$entity_puk_file" ]; then
        old_management_key=$(cat "$entity_management_key_file")
        old_pin=$(cat "$entity_pin_file")
        old_puk=$(cat "$entity_puk_file")
        mv $entity_management_key_file $entity_management_key_file.$RANDOM.bak
        mv $entity_pin_file $entity_pin_file.$RANDOM.bak
        mv $entity_puk_file $entity_puk_file.$RANDOM.bak
      else
        error "security_key_init: roll keys requested while some of the files are missing."\
"Check management key, pin and puk configuraiton." 1
      fi
    fi
  else
    if [ $roll_keys = true ]; then
      error "security_key_init: requested to roll keys but at least one of the"\
"configured entity keys doesn't exist." 1
    else
      old_management_key="$default_management_key"
      old_pin="$default_pin"
      old_puk="$default_puk"
    fi
  fi
  local management_key=`dd if=/dev/random bs=1 count=24 2>/dev/null | hexdump -v -e '/1 "%02X"'`
  echo "${management_key}" > "${entity_management_key_file}"
  local pin=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-6`
  echo "${pin}" > ${entity_pin_file}
  local puk=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-8`
  echo "${puk}" > ${entity_puk_file}
  # set the management key, pin and puk
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  case "$entity_security_key_type" in
    yubikey )
      eval yubico-piv-tool -k ${old_management_key} -a set-mgm-key -n ${management_key} ${redirect_err_out}
      if [ $? != 0 ]; then
        error "security_key_init: Error while setting the management key. Was your yubikey already "\
"initialized? If so, you need to configure your yubikey management key, pin "\
"and puk. For further information type 'sca init yubikey --help'" 1
      fi
      eval yubico-piv-tool -k ${management_key} -a change-pin -P ${old_pin} -N ${pin} ${redirect_err_out}
      if [ $? != 0 ]; then
        error "security_key_init: Error while setting the pin access code. Was your yubikey already "\
"initialized? If so, you need to configure your yubikey management key, pin "\
"and puk. For further information type 'sca init yubikey --help'" 1
      fi
      eval yubico-piv-tool -k ${management_key} -a change-puk -P ${old_puk} -N ${puk} ${redirect_err_out}
      if [ $? != 0 ]; then
        error "security_key_init: Error while setting the puk access code. Was your yubikey already "\
"initialized? If so, you need to configure your yubikey management key, pin "\
"and puk. For further information type 'sca init yubikey --help'" 1
      fi
    ;;
    pkcs11 )
      # TODO: implement setting the access keys using pkcs11 apis / pkcs15-init
      :
    ;;
    * )
      error "security_key_init: Unsupported entity_security_key_type $entity_security_key_type." 1
  esac
  log_detailed "security_key_init: finished (roll_keys=$roll_keys, entity=$entity)"
}
security_key_init_help() {
  echo "
@@@HELP@@@
"
}
