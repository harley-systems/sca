security_key_init() {
  local roll_keys=false
  local device=''
  OPTS=`getopt -o hr --long help,roll-keys,device: -n "sca security_key init" -- "$@"`
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
      --device )
        device=$2
        shift;shift
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
    error "security_key_init: invalid value supplied for entity. use sca "\
"security_key init -h for help." 1
  # the key is waited for once, and then named on every yubico-piv-tool call:
  # left to itself, yubico-piv-tool uses the first reader it finds, which with
  # more than one key attached need not be the one just waited for.
  local device_option=()
  [ -n "$device" ] && device_option=(--device "$device")
  local reader_slot_number
  reader_slot_number=$(security_key_wait_for "${device_option[@]}" "$entity") || exit $?
  local reader_name
  reader_name=$(security_key_reader_name "$reader_slot_number") || exit $?
  # TODO: default access keys depend on security_key_type - add case for it
  local default_management_key='010203040506070801020304050607080102030405060708'
  local default_pin='123456'
  local default_puk='12345678'
  local entity_management_key_file=$(eval echo \$${entity}_yubikey_key_file)
  local entity_pin_file=$(eval echo \$${entity}_yubikey_pin_file)
  local entity_puk_file=$(eval echo \$${entity}_yubikey_puk_file)
  local entity_private_folder=$(eval echo \$${entity}_private_folder)
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
  # init may run before create key, so the private folder may not exist yet.
  # it holds the pin, puk and management key, so it is kept to its owner.
  [ -z "$entity_private_folder" ] && \
    error "security_key_init: no private folder is configured for '$entity'." 1
  mkdir -p "$entity_private_folder" && chmod 700 "$entity_private_folder" || \
    error "security_key_init: could not create the private folder "\
"'$entity_private_folder'. nothing was changed on the security key." 1
  local management_key=`dd if=/dev/random bs=1 count=24 2>/dev/null | hexdump -v -e '/1 "%02X"'`
  local pin=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-6`
  local puk=`dd if=/dev/random bs=1 count=6 2>/dev/null | hexdump -v -e '/1 "%u"'|cut -c1-8`
  # an empty value (dd or hexdump missing) would be set on the key as-is
  [ ${#management_key} -eq 48 ] && [ ${#pin} -eq 6 ] && [ ${#puk} -ge 6 ] || \
    error "security_key_init: could not generate the new access keys (are dd "\
"and hexdump installed?). nothing was changed on the security key." 1
  # the new values go to temporary files next to the final ones before the key
  # is touched, so that if the run is cut short there is still a record of them
  # on disk. they are moved into place only once it is known what the key holds.
  #
  # printf, not echo: the PIN file is handed to libp11 as pin-source=file:, and
  # libp11 only started ignoring a trailing newline in 0.4.17. Below that it
  # reads the newline as part of the PIN, the token rejects it, and the attempt
  # spends one of three retries. The other two are read with $(cat), which
  # strips it either way -- written the same here so the files stay consistent.
  local management_key_tmp pin_tmp puk_tmp
  management_key_tmp=$(umask 077; mktemp "${entity_management_key_file}.new.XXXXXX") && \
    pin_tmp=$(umask 077; mktemp "${entity_pin_file}.new.XXXXXX") && \
    puk_tmp=$(umask 077; mktemp "${entity_puk_file}.new.XXXXXX") && \
    printf '%s' "${management_key}" > "${management_key_tmp}" && \
    printf '%s' "${pin}" > "${pin_tmp}" && \
    printf '%s' "${puk}" > "${puk_tmp}"
  if [ $? != 0 ]; then
    rm -f "$management_key_tmp" "$pin_tmp" "$puk_tmp"
    error "security_key_init: could not write the new access keys to "\
"'$entity_private_folder'. nothing was changed on the security key." 1
  fi
  # set the management key, pin and puk
  local changed=()
  local failed=''
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  case "$entity_security_key_type" in
    yubikey )
      # quoted for eval: the reader name has spaces in it
      local reader_option=''
      [ -n "$reader_name" ] && reader_option='--reader "${reader_name}"'
      eval yubico-piv-tool ${reader_option} -k ${old_management_key} -a set-mgm-key -n ${management_key} ${redirect_err_out}
      if [ $? != 0 ]; then
        failed='management key'
      else
        changed+=('management key')
        eval yubico-piv-tool ${reader_option} -k ${management_key} -a change-pin -P ${old_pin} -N ${pin} ${redirect_err_out}
        if [ $? != 0 ]; then
          failed='pin'
        else
          changed+=('pin')
          eval yubico-piv-tool ${reader_option} -k ${management_key} -a change-puk -P ${old_puk} -N ${puk} ${redirect_err_out}
          if [ $? != 0 ]; then
            failed='puk'
          else
            changed+=('puk')
          fi
        fi
      fi
    ;;
    pkcs11 )
      # TODO: implement setting the access keys using pkcs11 apis / pkcs15-init
      changed=('management key' 'pin' 'puk')
    ;;
    * )
      rm -f "$management_key_tmp" "$pin_tmp" "$puk_tmp"
      error "security_key_init: Unsupported entity_security_key_type $entity_security_key_type." 1
  esac
  if [ ${#changed[@]} -eq 0 ]; then
    # nothing reached the key, so nothing on disk changes either
    rm -f "$management_key_tmp" "$pin_tmp" "$puk_tmp"
    error "security_key_init: Error while setting the management key. Was your "\
"yubikey already initialized? If so, you need to configure your yubikey "\
"management key, pin and puk. For further information type "\
"'sca security_key init --help'. Nothing was changed on the security key and "\
"the files were left as they were." 1
  fi
  # a step that failed after an earlier one succeeded leaves the key holding a
  # mix of new and old values. the files must say what the key holds, so the
  # credentials that were not changed keep their old values.
  [[ " ${changed[*]} " =~ " pin " ]] || printf '%s' "${old_pin}" > "${pin_tmp}"
  [[ " ${changed[*]} " =~ " puk " ]] || printf '%s' "${old_puk}" > "${puk_tmp}"
  if [ $roll_keys = true ]; then
    mv "$entity_management_key_file" "$entity_management_key_file.$RANDOM.bak"
    mv "$entity_pin_file" "$entity_pin_file.$RANDOM.bak"
    mv "$entity_puk_file" "$entity_puk_file.$RANDOM.bak"
  fi
  if ! { mv "$management_key_tmp" "$entity_management_key_file" && \
    mv "$pin_tmp" "$entity_pin_file" && mv "$puk_tmp" "$entity_puk_file"; }; then
    error "security_key_init: the security key was changed (${changed[*]}) but "\
"the files could not be moved into place. the values now on the key are in "\
"the temporary .new. files in '$entity_private_folder'." 1
  fi
  if [ -n "$failed" ]; then
    local changed_list=$(printf '%s, ' "${changed[@]}")
    error "security_key_init: Error while setting the $failed. The security key "\
"was partly changed. Changed on the key: ${changed_list%, }. The rest kept "\
"their old values. The files record what is on the key now. For further "\
"information type 'sca security_key init --help'." 1
  fi
  log_detailed "security_key_init: finished (roll_keys=$roll_keys, entity=$entity)"
}
security_key_init_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
