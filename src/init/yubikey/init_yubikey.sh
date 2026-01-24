################################################################################
# initialize yubikey security device
#
# used for first-time hardware security device setup
#
# parameters
#   ???
#
# TODO: check if this is still needed. It seems that the whole command has a
# newer version in security_key_init.sh ????????????????????????
# It seems it is not needed, as the amount of required common functionality
# for security keys has grown, this functionality has been migrated there
# also, there we intend to allow for support fir additional types of security keys
#
init_yubikey() {
  local roll_keys=false

  OPTS=`getopt -o hr --long help,roll-keys -n "init yubikey" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca init yubikey -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        init_yubikey_help
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

  local card_not_present=$(piv-tool --name | grep "Card not present")
  if [ -z ${card_not_present} ]; then
    log_detailed "init_yubikey: piv card is detected"
  else
    log_detailed "init_yubikey: piv card is not inserted"
  fi

  local default_management_key='010203040506070801020304050607080102030405060708'
  local default_pin='123456'
  local default_puk='12345678'

  local entity_yubikey_key_file=$(eval echo \$${entity}_yubikey_key_file)
  local entity_yubikey_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
  local entity_yubikey_puk_file=$(eval echo \$${entity}_yubikey_puk_file)

  # check if the management key file already exists on the disk
  if [ -f $entity_yubikey_key_file ] || [ -f $entity_yubikey_pin_file ] || [ -f $entity_yubikey_puk_file ] ; then
    if [ $roll_keys = false ]; then
      error "init_yubikey: yubikey management key, pin and/or puk file already exist.
        In case you want to roll existing keys use the --roll-keys parameter." 1
    else
      if [ -f $entity_yubikey_key_file ] && [ -f $entity_yubikey_pin_file ] && [ -f $entity_yubikey_puk_file ]; then
        local old_management_key=$(cat $entity_yubikey_key_file)
        local old_pin=$(cat $entity_yubikey_pin_file)
        local old_puk=$(cat $entity_yubikey_puk_file)
        mv $entity_yubikey_key_file $entity_yubikey_key_file.$RANDOM.bak
        mv $entity_yubikey_pin_file $entity_yubikey_pin_file.$RANDOM.bak
        mv $entity_yubikey_puk_file $entity_yubikey_puk_file.$RANDOM.bak
      else
        error "init_yubikey: roll keys requested while some of the files are missing.
          Check yubikey management key, pin and puk configuraiton." 1
      fi
    fi
  else
    if [ $roll_keys = true ]; then
      error "init_yubikey: requested to roll keys but at least one of the
        configured entity keys doesn't exist." 1
    else
      local old_management_key=$default_management_key
      local old_pin=$default_pin
      local old_puk=$default_puk
    fi
  fi

  local management_key=`dd if=/dev/random bs=1 count=24 2>/dev/null | hexdump -v -e '/1 "%02X"'`
  echo ${management_key} > ${entity_yubikey_key_file}
  local pin=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-6`
  echo ${pin} > ${entity_yubikey_pin_file}
  local puk=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-8`
  echo ${puk} > ${entity_yubikey_puk_file}

  # set the management key
  eval yubico-piv-tool -k ${old_management_key} -a set-mgm-key -n ${management_key} ${redirect_err_out}
  if [ $? != 0 ]; then
    error "Error while setting the management key. Was your yubikey already
      initialized? If so, you need to configure your yubikey management key, pin
      and puk. For further information type 'sca init yubikey --help'" 1
  fi
  eval yubico-piv-tool -k ${management_key} -a change-pin -P ${old_pin} -N ${pin} ${redirect_err_out}
  if [ $? != 0 ]; then
    error "Error while setting the pin access code. Was your yubikey already
      initialized? If so, you need to configure your yubikey management key, pin
      and puk. For further information type 'sca init yubikey --help'" 1
  fi
  eval yubico-piv-tool -k ${management_key} -a change-puk -P ${old_puk} -N ${puk} ${redirect_err_out}
  if [ $? != 0 ]; then
    error "Error while setting the puk access code. Was your yubikey already
      initialized? If so, you need to configure your yubikey management key, pin
      and puk. For further information type 'sca init yubikey --help'" 1
  fi
}

init_yubikey_help() {
  echo "
@@@HELP@@@
    "
}
