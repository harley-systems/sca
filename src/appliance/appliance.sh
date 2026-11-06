################################################################################
# check and describe the platform the sca appliance runs on
appliance() {
  # Check for help flag - don't use getopt since sub-commands have their own options
  case "$1" in
    -h | --help )
      appliance_help
      return
      ;;
  esac

  local appliance_command=$1
  shift
  log_detailed "appliance: start (appliance_command=${appliance_command})"
  case "$appliance_command" in
    info|verify )
      appliance_$appliance_command "$@"
      ;;
    *)
      read -r -d '' message <<- ____EOM
        invalid value '$appliance_command' for appliance_command (first) argument.
        supported values are 'info' and 'verify'.
        use sca appliance -h for help.
____EOM
      error "$message" 1
      ;;
  esac

  log_detailed "appliance: finished (appliance_command=${appliance_command})"
}
appliance_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
################################################################################
# the platform profiles, src/appliance/platforms/<platform>.conf, each under a
# [<platform>] header. the build embeds them here, so build/sca.sh stays a
# single file. a profile is data: it is read with appliance_profile_get, never sourced.
appliance_platform_profiles() {
  cat <<'APPLIANCE_PLATFORM_PROFILES'
@@@APPLIANCE PLATFORM PROFILES@@@
APPLIANCE_PLATFORM_PROFILES
}
# the known platform names, one per line
appliance_platforms() {
  appliance_platform_profiles | sed -n -E 's/^\[([a-z0-9_-]+)\]$/\1/p'
}
################################################################################
# print the value of a key in a platform profile, empty if it is not set
#
# parameters
#   platform - the platform name
#   key   - the profile key
appliance_profile_get() {
  local platform=$1 key=$2
  appliance_platform_profiles | awk -v platform="$platform" -v key="$key" '
    /^\[[a-z0-9_-]+\]$/ { in_platform = ($0 == "[" platform "]"); next }
    !in_platform || /^[[:space:]]*#/ { next }
    {
      i = index($0, "=")
      if (i > 1 && substr($0, 1, i - 1) == key) { print substr($0, i + 1); exit }
    }'
}
################################################################################
# a /proc or /sys path. SCA_APPLIANCE_ROOT is a test hook: the tests point it at
# a fake tree. it is empty in normal use.
appliance_path() {
  printf '%s%s' "${SCA_APPLIANCE_ROOT}" "$1"
}
################################################################################
# resolve the platform to use and set appliance_platform to it
#
# with a platform asked for, it has to be a known one. without, the platform is
# the one whose profile 'compatible' matches an entry of the device tree's
# compatible list. a platform with no device tree (x86) is the one profile
# without a 'compatible' key whose 'arch' is the machine's. exits with the
# known platforms listed if there is none, or more than one.
#
# parameters
#   platform - the platform asked for with --platform, or empty
appliance_resolve_platform() {
  local platform=$1
  local platforms=$(appliance_platforms | paste -sd ' ' -)
  if [ -n "$platform" ]; then
    if ! appliance_platforms | grep -qxF -- "$platform"; then
      error "unknown platform '$platform'. known platforms: ${platforms}." 1
    fi
    appliance_platform=$platform
    return 0
  fi
  local candidate pattern
  local compatible_file=$(appliance_path /proc/device-tree/compatible)
  if [ -r "$compatible_file" ]; then
    local compatible=$(tr '\0' '\n' < "$compatible_file")
    for candidate in $(appliance_platforms); do
      pattern=$(appliance_profile_get "$candidate" compatible)
      [ -z "$pattern" ] && continue
      if printf '%s\n' "$compatible" | grep -qE -- "^(${pattern})\$"; then
        log_detailed "appliance_resolve_platform: detected '$candidate'"
        appliance_platform=$candidate
        return 0
      fi
    done
  fi
  local arch=$(appliance_arch) matches=''
  if [ -n "$arch" ]; then
    for candidate in $(appliance_platforms); do
      [ -n "$(appliance_profile_get "$candidate" compatible)" ] && continue
      [ "$(appliance_profile_get "$candidate" arch)" = "$arch" ] || continue
      matches="${matches:+${matches} }${candidate}"
    done
  fi
  case "$matches" in
    '' ) ;;
    *' '* )
      error "could not detect the platform: profiles ${matches} all match arch ${arch}. name one with --platform PLATFORM." 1
      ;;
    * )
      log_detailed "appliance_resolve_platform: detected '$matches' by arch '$arch'"
      appliance_platform=$matches
      return 0
      ;;
  esac
  error "could not detect the platform: no platform profile matches \
${compatible_file} or arch '${arch:-unknown}'. known platforms: ${platforms}. \
name one with --platform PLATFORM." 1
}
# the machine's architecture as a profile's 'arch' names it (amd64, arm64), or
# empty when it is not one sca knows
appliance_arch() {
  case "$(uname -m)" in
    x86_64 ) echo amd64 ;;
    aarch64 | arm64 ) echo arm64 ;;
  esac
}
################################################################################
# the gather functions read the system. verify and info both use them, so the
# two can never disagree.

# the device the root file system comes from, its disk and the disk's
# transport. sets appliance_root_source, appliance_root_disk and
# appliance_root_tran, or appliance_root_error and returns 1.
#
# a live boot mounts an overlay on /, so the medium it was booted from is used
# instead.
appliance_gather_root() {
  appliance_root_source='' appliance_root_disk='' appliance_root_tran=''
  appliance_root_error=''
  local mount_point source
  for mount_point in / /run/live/medium /cdrom; do
    source=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null | head -n 1)
    # a btrfs subvolume is shown as /dev/sda1[/@]
    source=${source%%\[*}
    if [[ "$source" == /dev/* ]]; then
      appliance_root_source=$source
      break
    fi
  done
  if [ -z "$appliance_root_source" ]; then
    appliance_root_error="root is not on a block device (findmnt / gave '$(findmnt -n -o SOURCE / 2>&1 | head -n 1)')"
    return 1
  fi
  local disk=$(lsblk -no PKNAME "$appliance_root_source" 2>/dev/null | head -n 1 | tr -d '[:space:]')
  [ -z "$disk" ] && disk=${appliance_root_source#/dev/}
  appliance_root_disk=$disk
  if ! appliance_root_tran=$(lsblk -dno TRAN "/dev/$disk" 2>&1); then
    appliance_root_error="lsblk could not read /dev/$disk: ${appliance_root_tran}"
    appliance_root_tran=''
    return 1
  fi
  appliance_root_tran=$(printf '%s' "$appliance_root_tran" | head -n 1 | tr -d '[:space:]')
  return 0
}
# every rtc, one per line: "<rtcN> <name> hctosys=<0|1>"
appliance_gather_rtcs() {
  local rtc name hctosys
  for rtc in "$(appliance_path /sys/class/rtc)"/rtc*; do
    [ -e "$rtc" ] || continue
    name=$(cat "$rtc/name" 2>/dev/null)
    hctosys=$(cat "$rtc/hctosys" 2>/dev/null)
    echo "$(basename "$rtc") ${name:-?} hctosys=${hctosys:-?}"
  done
}
# the ntp state from timedatectl: sets appliance_ntp and appliance_ntp_synced,
# or appliance_ntp_error and returns 1
appliance_gather_ntp() {
  appliance_ntp='' appliance_ntp_synced='' appliance_ntp_error=''
  local output
  if ! command -v timedatectl >/dev/null 2>&1; then
    appliance_ntp_error="timedatectl not found"
    return 1
  fi
  if ! output=$(timedatectl show -p NTP -p NTPSynchronized 2>&1); then
    appliance_ntp_error="timedatectl failed: $(printf '%s' "$output" | head -n 1)"
    return 1
  fi
  appliance_ntp=$(printf '%s\n' "$output" | sed -n 's/^NTP=//p')
  appliance_ntp_synced=$(printf '%s\n' "$output" | sed -n 's/^NTPSynchronized=//p')
  if [ -z "$appliance_ntp_synced" ]; then
    appliance_ntp_error="timedatectl did not report NTPSynchronized"
    return 1
  fi
  return 0
}
# the state of a systemd unit as systemctl is-enabled reports it, or
# 'not-found' when the unit does not exist
appliance_gather_unit_state() {
  local unit=$1 state
  state=$(systemctl is-enabled -- "$unit" 2>&1)
  case "$state" in
    *"No such file or directory"* ) state=not-found ;;
  esac
  printf '%s\n' "$state" | head -n 1
}
# the clock the kernel set from rtc0 in this boot, and when the previous boot
# ended. sets appliance_boot_clock_epoch and appliance_previous_boot_epoch
# (empty when there is no previous boot), or appliance_journal_error and
# returns 1.
#
# parameters
#   rtc_device - the rtc0 name, '<driver> <device>', which is also the prefix
#                of the kernel's 'setting system clock' message
appliance_gather_journal() {
  local rtc_device=$1
  appliance_boot_clock_epoch='' appliance_previous_boot_epoch=''
  appliance_journal_error=''
  if ! command -v journalctl >/dev/null 2>&1; then
    appliance_journal_error="journalctl not found"
    return 1
  fi
  local kernel_log status=0
  kernel_log=$(journalctl -k -b 0 --no-pager 2>&1) || status=$?
  # a user outside systemd-journal sees only their own entries, and so none of
  # the kernel's: journalctl says so in a hint, and that must not read as "the
  # line is missing".
  if [ $status -ne 0 ] || [[ "$kernel_log" == *"not seeing messages"* ]] \
      || [[ "$kernel_log" == *"insufficient permissions"* ]]; then
    appliance_journal_error="cannot read the journal: run with sudo or join group systemd-journal"
    return 1
  fi
  local line=$(printf '%s\n' "$kernel_log" | \
    grep -F -- "${rtc_device}: setting system clock to" | tail -n 1)
  if [ -z "$line" ]; then
    appliance_journal_error="no '${rtc_device}: setting system clock' in this boot's kernel log"
    return 1
  fi
  appliance_boot_clock_epoch=$(printf '%s\n' "$line" | sed -n -E 's/.*\(([0-9]+)\)[[:space:]]*$/\1/p')
  if [ -z "$appliance_boot_clock_epoch" ]; then
    appliance_journal_error="no epoch in '${line}'"
    return 1
  fi
  local previous=$(journalctl -b -1 -n 1 -o short-unix --no-pager -q 2>/dev/null | tail -n 1)
  previous=${previous%%[. ]*}
  [[ "$previous" =~ ^[0-9]+$ ]] && appliance_previous_boot_epoch=$previous
  return 0
}
# the value of the platform's probe: the probe_file with NULs stripped, or the
# output of probe_command. sets appliance_probe_value, or appliance_probe_error
# and returns 1.
#
# parameters
#   platform - the platform name
appliance_gather_probe() {
  local platform=$1
  appliance_probe_value='' appliance_probe_error=''
  local probe_file=$(appliance_profile_get "$platform" probe_file)
  local probe_command=$(appliance_profile_get "$platform" probe_command)
  if [ -n "$probe_file" ]; then
    local path=$(appliance_path "$probe_file")
    if [ ! -r "$path" ]; then
      appliance_probe_error="${probe_file} not found"
      return 1
    fi
    appliance_probe_value=$(tr -d '\0' < "$path")
  elif [ -n "$probe_command" ]; then
    # split into words and run as is: a profile value never goes through eval
    local -a command_words
    read -ra command_words <<< "$probe_command"
    if ! command -v "${command_words[0]}" >/dev/null 2>&1; then
      appliance_probe_error="${command_words[0]} not found"
      return 1
    fi
    if ! appliance_probe_value=$("${command_words[@]}" 2>&1); then
      appliance_probe_error="'${probe_command}' failed: $(printf '%s' "$appliance_probe_value" | head -n 1)"
      appliance_probe_value=''
      return 1
    fi
  else
    appliance_probe_error="profile ${platform} sets neither probe_file nor probe_command"
    return 1
  fi
  return 0
}
