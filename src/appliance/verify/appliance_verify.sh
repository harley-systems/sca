################################################################################
# check that the appliance is set up as intended, one row per check, and exit
# non-zero if any check fails.
#
# five checks read only /proc, /sys, systemd and the journal, and so work on
# any platform. the sixth is the platform profile's probe, or n/a on a platform
# that needs no boot preparation. every check runs, even after one has failed,
# so one run shows everything that is wrong.
#
# options
#   --platform PLATFORM - use this platform profile instead of detecting it
appliance_verify() {
  local platform=''
  local OPTS=`getopt -o h --long help,platform: -n "sca appliance verify" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca appliance verify -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        appliance_verify_help
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
  log_detailed "appliance_verify: started (platform:'$platform')"
  local appliance_platform
  appliance_resolve_platform "$platform"
  platform=$appliance_platform

  if [ "$(appliance_profile_get "$platform" verified)" = no ]; then
    echo "profile ${platform} is a proposal (unverified)"
  fi

  local failed=0 detail
  local probe_label=$(appliance_profile_get "$platform" probe_label)
  if [ "$(appliance_profile_get "$platform" boot_prep)" = none ]; then
    appliance_verify_row "${probe_label:-boot}" "platform boots USB natively" n/a
  else
    appliance_verify_probe "$platform"
    appliance_verify_row "${probe_label:-boot}" "$detail" $?
  fi
  appliance_verify_root "$platform"
  appliance_verify_row root "$detail" $?
  appliance_verify_rtc "$platform"
  appliance_verify_row rtc "$detail" $?
  appliance_verify_clock
  appliance_verify_row clock "$detail" $?
  appliance_verify_units "$platform"
  appliance_verify_row hwclock "$detail" $?
  appliance_verify_power_cut
  appliance_verify_row "power cut" "$detail" $?

  log_detailed "appliance_verify: finished (platform:'$platform', failed:'$failed')"
  if [ $failed -gt 0 ]; then
    error "appliance verify: ${failed} check(s) failed" 1
  fi
}
# print one row of the verify table, and count a failure in the caller's
# 'failed'
#
# parameters
#   label  - what is checked
#   detail - what was found
#   status - the check's return code, 0 for ok, or 'n/a' for a check that does
#            not apply to the platform (not a failure)
appliance_verify_row() {
  local status=ok
  if [ "$3" = n/a ]; then
    status=n/a
  elif [ "$3" -ne 0 ]; then
    status=FAIL; failed=$((failed + 1))
  fi
  printf '  %-9s %-40s %s\n' "$1" "$2" "$status"
}
# each appliance_verify_<check> sets detail and returns 0 for ok, 1 for FAIL

# the platform-specific probe matches probe_expect and not probe_reject
appliance_verify_probe() {
  local platform=$1
  if ! appliance_gather_probe "$platform"; then
    detail=$appliance_probe_error
    return 1
  fi
  local expect=$(appliance_profile_get "$platform" probe_expect)
  local reject=$(appliance_profile_get "$platform" probe_reject)
  local matched=$(printf '%s\n' "$appliance_probe_value" | grep -E -m 1 -- "$expect")
  detail=${matched:-$(printf '%s\n' "$appliance_probe_value" | head -n 1)}
  [ -z "$detail" ] && detail='(empty)'
  if [ -z "$matched" ]; then
    detail="${detail} (expected /${expect}/)"
    return 1
  fi
  if [ -n "$reject" ] && printf '%s\n' "$appliance_probe_value" | grep -qE -- "$reject"; then
    detail="${detail} (matches /${reject}/)"
    return 1
  fi
  return 0
}
# the root file system is on a disk with one of the profile's transports
appliance_verify_root() {
  local platform=$1
  if ! appliance_gather_root; then
    detail=$appliance_root_error
    return 1
  fi
  local transports=$(appliance_profile_get "$platform" root_transports)
  detail="${appliance_root_source} (${appliance_root_tran:-no transport})"
  if [ -z "$appliance_root_tran" ] || [[ " ${transports} " != *" ${appliance_root_tran} "* ]]; then
    detail="${detail}, not ${transports}"
    return 1
  fi
  return 0
}
# rtc0 is the profile's battery-backed clock, and the kernel sets the time
# from it. when it is not, every rtc is listed: a PMIC clock holding rtc0 is
# the usual reason.
appliance_verify_rtc() {
  local platform=$1
  local rtc_name=$(appliance_profile_get "$platform" rtc_name)
  local rtc0=$(appliance_path /sys/class/rtc/rtc0)
  local name=$(cat "$rtc0/name" 2>/dev/null)
  local hctosys=$(cat "$rtc0/hctosys" 2>/dev/null)
  if [ -n "$name" ] && printf '%s\n' "$name" | grep -qE -- "$rtc_name" && [ "$hctosys" = 1 ]; then
    detail="${name%% *} is rtc0, hctosys=1"
    return 0
  fi
  local rtcs=$(appliance_gather_rtcs | paste -sd ';' - | sed 's/;/; /g')
  detail=${rtcs:-no rtc}
  return 1
}
# the time does not come from the network
appliance_verify_clock() {
  if ! appliance_gather_ntp; then
    detail=$appliance_ntp_error
    return 1
  fi
  if [ "$appliance_ntp_synced" = yes ]; then
    detail="synchronised by NTP: the time comes from the network"
    return 1
  fi
  if [ "$appliance_ntp" = yes ]; then
    detail="ntp enabled, not synchronised"
  else
    detail="not synchronised by NTP"
  fi
  return 0
}
# the units that would overwrite the rtc's time (fake-hwclock) are masked, or
# not installed
appliance_verify_units() {
  local platform=$1
  local units=$(appliance_profile_get "$platform" masked_units)
  local unit state bad='' count=0
  for unit in $units; do
    count=$((count + 1))
    state=$(appliance_gather_unit_state "$unit")
    case "$state" in
      masked|not-found ) ;;
      * ) bad="${bad:+${bad}, }${unit} is ${state:-unknown}" ;;
    esac
  done
  if [ -n "$bad" ]; then
    detail=$bad
    return 1
  fi
  detail="${count} unit(s) masked or absent"
  return 0
}
# the time the kernel took from rtc0 at boot is not earlier than the end of the
# previous boot, i.e. the clock kept running while the power was off
appliance_verify_power_cut() {
  local rtc0_name=$(cat "$(appliance_path /sys/class/rtc/rtc0/name)" 2>/dev/null)
  if [ -z "$rtc0_name" ]; then
    detail="no rtc0"
    return 1
  fi
  if ! appliance_gather_journal "$rtc0_name"; then
    detail=$appliance_journal_error
    return 1
  fi
  if [ -z "$appliance_previous_boot_epoch" ]; then
    detail="no previous boot recorded"
    return 0
  fi
  local behind=$((appliance_previous_boot_epoch - appliance_boot_clock_epoch))
  if [ $behind -gt 0 ]; then
    detail="boot clock ${behind}s behind the previous boot"
    return 1
  fi
  detail="clock kept through power-off"
  return 0
}
appliance_verify_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
