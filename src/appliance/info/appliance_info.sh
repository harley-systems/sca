################################################################################
# describe the platform and what verify would look at, without judging it.
# always exits 0, so it is the command to run when verify fails.
#
# with no profile matching the platform and no --platform, the
# platform-independent facts are still shown.
#
# options
#   --platform PLATFORM - use this platform profile instead of detecting it
appliance_info() {
  local platform=''
  local OPTS=`getopt -o h --long help,platform: -n "sca appliance info" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca appliance info -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        appliance_info_help
        return
      ;;
      --platform )
        platform=$2
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
  log_detailed "appliance_info: started (platform:'$platform')"
  local appliance_platform=''
  if [ -n "$platform" ]; then
    appliance_resolve_platform "$platform"
  else
    # detection failing is information here, not an error
    appliance_platform=$(appliance_resolve_platform '' 2>/dev/null && echo "$appliance_platform")
  fi
  platform=$appliance_platform

  local model=$(tr -d '\0' 2>/dev/null < "$(appliance_path /proc/device-tree/model)")
  appliance_info_row model "${model:-unknown}"
  if [ -n "$platform" ]; then
    appliance_info_row profile "$platform ($(appliance_profile_get "$platform" name))"
    local key
    for key in verified arch irreversible base_image base_image_check \
        boot_prep rtc rtc_method i2c_bus root_transports; do
      appliance_info_row "" "${key}: $(appliance_profile_get "$platform" "$key")"
    done
  else
    appliance_info_row profile "none matches; known platforms: $(appliance_platforms | paste -sd ' ' -)"
  fi

  local rtcs=$(appliance_gather_rtcs)
  appliance_info_rows rtc "${rtcs:-no rtc}"

  if appliance_gather_root; then
    appliance_info_row root "${appliance_root_source} on ${appliance_root_disk}, transport: ${appliance_root_tran:-none}"
  else
    appliance_info_row root "$appliance_root_error"
  fi

  if appliance_gather_ntp; then
    appliance_info_row ntp "NTP=${appliance_ntp} NTPSynchronized=${appliance_ntp_synced}"
  else
    appliance_info_row ntp "$appliance_ntp_error"
  fi

  if [ -n "$platform" ]; then
    local unit units=''
    for unit in $(appliance_profile_get "$platform" masked_units); do
      units="${units}${unit} $(appliance_gather_unit_state "$unit")"$'\n'
    done
    appliance_info_rows units "${units:-none listed}"

    local probe_label=$(appliance_profile_get "$platform" probe_label)
    if [ "$(appliance_profile_get "$platform" boot_prep)" = none ]; then
      appliance_info_row "${probe_label:-boot}" "n/a - platform boots USB natively"
    elif appliance_gather_probe "$platform"; then
      appliance_info_rows "${probe_label:-boot}" "${appliance_probe_value:-(empty)}"
    else
      appliance_info_row "${probe_label:-boot}" "$appliance_probe_error"
    fi
  fi
  log_detailed "appliance_info: finished (platform:'$platform')"
  return 0
}
# print one row of info
#
# parameters
#   label - what is shown, empty for a continuation row
#   value - what was found
appliance_info_row() {
  printf '  %-9s %s\n' "$1" "$2"
}
# print a multi-line value, the label on its first line only
appliance_info_rows() {
  local label=$1 line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    appliance_info_row "$label" "$line"
    label=''
  done <<< "$2"
}
appliance_info_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
