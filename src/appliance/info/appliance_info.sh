################################################################################
# describe the board and what verify would look at, without judging it.
# always exits 0, so it is the command to run when verify fails.
#
# with no profile matching the board and no --board, the board-independent
# facts are still shown.
#
# options
#   --board BOARD - use this board profile instead of detecting the board
appliance_info() {
  local board=''
  local OPTS=`getopt -o h --long help,board: -n "sca appliance info" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca appliance info -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        appliance_info_help
        return
      ;;
      --board )
        board=$2
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
  log_detailed "appliance_info: started (board:'$board')"
  local appliance_board=''
  if [ -n "$board" ]; then
    appliance_resolve_board "$board"
  else
    # detection failing is information here, not an error
    appliance_board=$(appliance_resolve_board '' 2>/dev/null && echo "$appliance_board")
  fi
  board=$appliance_board

  local model=$(tr -d '\0' 2>/dev/null < "$(appliance_path /proc/device-tree/model)")
  appliance_info_row model "${model:-unknown}"
  if [ -n "$board" ]; then
    appliance_info_row profile "$board ($(appliance_profile_get "$board" name))"
    local key
    for key in verified irreversible base_image base_image_check \
        boot_enable_method rtc_method i2c_bus root_transports; do
      appliance_info_row "" "${key}: $(appliance_profile_get "$board" "$key")"
    done
  else
    appliance_info_row profile "none matches; known boards: $(appliance_boards | paste -sd ' ' -)"
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

  if [ -n "$board" ]; then
    local unit units=''
    for unit in $(appliance_profile_get "$board" masked_units); do
      units="${units}${unit} $(appliance_gather_unit_state "$unit")"$'\n'
    done
    appliance_info_rows units "${units:-none listed}"

    local probe_label=$(appliance_profile_get "$board" probe_label)
    if appliance_gather_probe "$board"; then
      appliance_info_rows "${probe_label:-probe}" "${appliance_probe_value:-(empty)}"
    else
      appliance_info_row "${probe_label:-probe}" "$appliance_probe_error"
    fi
  fi
  log_detailed "appliance_info: finished (board:'$board')"
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
