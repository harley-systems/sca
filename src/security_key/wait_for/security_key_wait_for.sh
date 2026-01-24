################################################################################
# awaits for the security key of the given entity
#
# below commands test if there is a card in a reader. possibly not necessary
#
# local card_not_present=$(piv-tool --name | grep "Card not present")
# if [ -z "${card_not_present}" ]; then
#   log_detailed "security_key_init: piv card is detected"
# else
#   log_detailed "security_key_init: piv card is not inserted"
# fi
security_key_wait_for() {
  local OPTS=`getopt -o h --long help -n "sca security_key wait_for" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key wait_for -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_wait_for_help
        return
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
  shift
  log_detailed "security_key_wait_for: started (entity='$entity')"
  local allowed_values=(ca subca user service host)
  [[ ! " ${allowed_values[@]} " =~ " ${entity} " ]] && \
    error "security_key_wait_for: invalid value supplied for entity. use sca "\
"security_key wait_for -h for help." 1
  local entity_security_key_id=$(eval echo \$${entity}_security_key_id)
  local entity_security_key_type=$(eval echo \$${entity}_security_key_type)
  # wait for the relevant yubikey_id (entity_yubikey_id)
  local previous_security_key_ids=()
  local first_time=true
  while true; do
    local current_security_key_ids=$(security_key_id --security-key-type $entity_security_key_type)
    if [ "$current_security_key_ids" != "- -" ]; then
      # we've retrieved some security key ids and their related reader numbers
      # now check if there's the one we're looking for
      local non_matched_keys=()
      local matched_keys=()
      while read -r current_security_key_id; do
        # if it is not the one we are looking for and it was not present in previous
        # itteration of the outer infinite loop, then we need to present the user
        # that they had just inserted a wrong security key.
        log_detailed "security_key_wait_for: now checking '$current_security_key_id' matches the configured one '$entity_security_key_id'"
        if [[ "$current_security_key_id" = "$entity_security_key_id"* ]]; then
          # we've got the correct security key inserted, se exit infinte loop
          matched_keys+=($current_security_key_id)
          break
        else
          # the current_security_key_id is no match
          # was it present in previous outer loop iteration
          if [[ ! " ${previous_security_key_ids[@]} " =~ " ${current_security_key_id} " ]]; then
            non_matched_keys+=("$current_security_key_id")
          fi
        fi
      done <<< "$current_security_key_ids"
      if [ ${#matched_keys[@]} -ne 0 ]; then
        # output reader number on the last output line to indicate in which
        # smart card reader is the awaited security key
        echo "${matched_keys[1]}"
        break
      else
        if [ ${#non_matched_keys[@]} -ne 0 ]; then
          (>&2 echo "detected insertion of a security key with a serial number "\
"different than the one configured for the '$entity'. please, check "\
"the configured security key id for the '$entity' or if the security "\
"key inseted is the intended one.")
          previous_security_key_ids+=("${non_matched_keys[@]}")
        fi
      fi
    else
      if [ $first_time = true ]; then
        (>&2 echo "please insert the security key for $entity")
      fi
    fi
    first_time=false
    sleep 1
  done
  log_detailed "security_key_wait_for: finished (entity=$entity)"
}
security_key_wait_for_help() {
  echo "
@@@HELP@@@
"
}
