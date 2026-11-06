#!/bin/bash
# appliance verify and info: every check passes on a board set up as intended,
# each silent misconfiguration from the ROCK64 bring-up fails its own row while
# the other rows still print, and verify exits non-zero on any failure.
#
# /proc and /sys are a fake tree under $HOME/root (SCA_APPLIANCE_ROOT), and the
# system tools are stubbed as exported shell functions that read their answers
# from $HOME/state, as in test_security_key_init.sh.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

export SCA_APPLIANCE_ROOT="${HOME}/root"
stub_state="${HOME}/state"
export stub_state

findmnt() {
  case "${*: -1}" in
    / ) cat "$stub_state/root_source" ;;
    * ) return 1 ;;
  esac
}
lsblk() {
  case "$*" in
    "-no PKNAME /dev/sda1" ) echo sda ;;
    "-no PKNAME /dev/mmcblk1p1" ) echo mmcblk1 ;;
    "-dno TRAN /dev/sda" ) echo usb ;;
    "-dno TRAN /dev/mmcblk1" ) echo ;;
    * ) return 1 ;;
  esac
}
timedatectl() {
  printf 'NTP=%s\nNTPSynchronized=%s\n' "$(cat "$stub_state/ntp")" "$(cat "$stub_state/ntp_synced")"
}
systemctl() {
  local unit=${*: -1}
  if [ -f "$stub_state/unit.$unit" ]; then
    cat "$stub_state/unit.$unit"
  else
    echo masked
  fi
}
journalctl() {
  case "$*" in
    "-k -b 0 --no-pager" )
      if [ -f "$stub_state/journal_denied" ]; then
        echo "Hint: You are currently not seeing messages from other users and the system." >&2
        echo "-- No entries --"
        return 0
      fi
      # the kernel sets the time from rtc0, whichever clock that is
      local rtc0
      rtc0=$(cat "${SCA_APPLIANCE_ROOT}/sys/class/rtc/rtc0/name")
      echo "Nov 06 14:23:29 rock64 kernel: ${rtc0}: registered as rtc0"
      echo "Nov 06 14:23:29 rock64 kernel: ${rtc0}: setting system clock to 2026-11-06T12:23:29 UTC ($(cat "$stub_state/boot_epoch"))"
      ;;
    "-b -1 -n 1 -o short-unix --no-pager -q" )
      [ -f "$stub_state/previous_epoch" ] || { echo "Data from the specified boot (-1) is not available" >&2; return 1; }
      echo "$(cat "$stub_state/previous_epoch").123456 rock64 systemd-shutdown[1]: Powering off."
      ;;
    * ) return 1 ;;
  esac
}
vcgencmd() {
  echo "[all]"
  echo "BOOT_UART=0"
  echo "BOOT_ORDER=$(cat "$stub_state/boot_order")"
}
export -f findmnt lsblk timedatectl systemctl journalctl vcgencmd

# a ROCK64 set up as intended: U-Boot from SPI, root on a USB stick, the
# DS3231 as rtc0, no NTP, fake-hwclock masked, the clock kept through a
# power cut
setup_rock64() {
  rm -rf "${SCA_APPLIANCE_ROOT}" "$stub_state"
  mkdir -p "$stub_state" "${SCA_APPLIANCE_ROOT}/proc/device-tree/chosen" \
    "${SCA_APPLIANCE_ROOT}/sys/class/rtc/rtc0" "${SCA_APPLIANCE_ROOT}/sys/class/rtc/rtc1"
  printf 'pine64,rock64\0rockchip,rk3328\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
  printf 'Pine64 Rock64\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/model"
  printf '2026.04\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/chosen/u-boot,version"
  set_rtc rtc0 'rtc-ds1307 0-0068' 1
  set_rtc rtc1 'rk808-rtc' 0
  echo /dev/sda1 > "$stub_state/root_source"
  echo no > "$stub_state/ntp"
  echo no > "$stub_state/ntp_synced"
  echo 1793017409 > "$stub_state/boot_epoch"
  echo 1793010000 > "$stub_state/previous_epoch"
}
set_rtc() {
  echo "$2" > "${SCA_APPLIANCE_ROOT}/sys/class/rtc/$1/name"
  echo "$3" > "${SCA_APPLIANCE_ROOT}/sys/class/rtc/$1/hctosys"
}

# row LABEL - the status of a row of the last verify output
row() {
  awk -v label="$1" 'index($0, "  " label " ") == 1 { print $NF }' "${HOME}/out"
}
# expect_fail LABEL - verify exits non-zero, LABEL is FAIL and the other rows
# still print
expect_fail() {
  local label=$1 other
  if sca appliance verify > "${HOME}/out" 2>&1; then
    fail "$label: verify exited 0"
  fi
  assert_eq FAIL "$(row "$label")" "$label row"
  for other in boot root rtc clock hwclock "power cut"; do
    [ "$other" = "$label" ] && continue
    assert_eq ok "$(row "$other")" "$label: $other row"
  done
  grep -q "appliance verify: 1 check(s) failed" "${HOME}/out" \
    || fail "$label: no failure summary"
}

# no ~/.sca/config is needed: verify must work on a board with no CA
setup_rock64
if ! sca appliance verify > "${HOME}/out" 2>&1; then
  fail "verify failed on a board set up as intended"
  cat "${HOME}/out" >&2
fi
for label in boot root rtc clock hwclock "power cut"; do
  assert_eq ok "$(row "$label")" "all ok: $label row"
done
[ -e "${HOME}/.sca" ] && fail "verify wrote to ~/.sca"

# U-Boot from the microSD, not SPI: the boot ROM skipped SPI
setup_rock64
printf '2026.04_armbian-2026.04-S88dc\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/chosen/u-boot,version"
expect_fail boot

# root still on the microSD card
setup_rock64
echo /dev/mmcblk1p1 > "$stub_state/root_source"
expect_fail root

# the PMIC holds rtc0, the DS3231 is ignored
setup_rock64
set_rtc rtc0 'rk808-rtc' 1
set_rtc rtc1 'rtc-ds1307 0-0068' 0
expect_fail rtc
grep -q 'rtc1 rtc-ds1307 0-0068 hctosys=0' "${HOME}/out" \
  || fail "the rtc row does not list every rtc"

# the DS3231 is rtc0 but the time is not set from it
setup_rock64
set_rtc rtc0 'rtc-ds1307 0-0068' 0
expect_fail rtc

# NTP quietly corrects the time
setup_rock64
echo yes > "$stub_state/ntp"
echo yes > "$stub_state/ntp_synced"
expect_fail clock

# NTP enabled but not synchronised is fine
setup_rock64
echo yes > "$stub_state/ntp"
assert_succeeds sca appliance verify

# fake-hwclock left enabled
setup_rock64
echo enabled > "$stub_state/unit.fake-hwclock-load.service"
expect_fail hwclock
grep -q 'fake-hwclock-load.service is enabled' "${HOME}/out" \
  || fail "the hwclock row does not name the unit"

# fake-hwclock not installed at all is fine
setup_rock64
for unit in fake-hwclock-load.service fake-hwclock-save.service fake-hwclock-save.timer; do
  echo "Failed to get unit file state for ${unit}: No such file or directory" \
    > "$stub_state/unit.${unit}"
done
assert_succeeds sca appliance verify

# the clock went backwards across the power cut
setup_rock64
echo 1793020000 > "$stub_state/previous_epoch"
expect_fail "power cut"

# no previous boot in the journal is fine
setup_rock64
rm "$stub_state/previous_epoch"
assert_succeeds sca appliance verify

# a journal the user cannot read fails, never passes silently
setup_rock64
touch "$stub_state/journal_denied"
expect_fail "power cut"
grep -q 'systemd-journal' "${HOME}/out" || fail "no hint on how to read the journal"

# several failures are all reported, and counted
setup_rock64
echo /dev/mmcblk1p1 > "$stub_state/root_source"
echo yes > "$stub_state/ntp_synced"
sca appliance verify > "${HOME}/out" 2>&1 && fail "verify exited 0 with two failures"
grep -q "appliance verify: 2 check(s) failed" "${HOME}/out" || fail "two failures not counted"

# an unknown board: exit 1 with the known boards
setup_rock64
printf 'acme,widget\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
sca appliance verify > "${HOME}/out" 2>&1
assert_eq 1 "$?" "undetected board exit status"
grep -q "known boards: raspberrypi rock64" "${HOME}/out" || fail "undetected board: boards not listed"
# --board overrides detection
assert_succeeds sca appliance verify --board rock64
assert_fails sca appliance verify --board acme
# no device tree at all, as on a workstation
rm -rf "${SCA_APPLIANCE_ROOT}/proc"
assert_fails sca appliance verify

# the raspberrypi profile is detected, says it is unverified first, and runs
# its probe command
setup_rock64
printf 'raspberrypi,4-model-b\0brcm,bcm2711\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
echo 0xf14 > "$stub_state/boot_order"
sca appliance verify > "${HOME}/out" 2>&1 || { fail "raspberrypi verify failed"; cat "${HOME}/out" >&2; }
assert_eq "profile raspberrypi is a proposal (unverified)" "$(head -n 1 "${HOME}/out")" "unverified banner"
echo 0xf41 > "$stub_state/boot_order"
expect_fail boot

# info shows what it finds and exits 0, even where verify fails
setup_rock64
echo /dev/mmcblk1p1 > "$stub_state/root_source"
set_rtc rtc0 'rk808-rtc' 1
set_rtc rtc1 'rtc-ds1307 0-0068' 0
echo enabled > "$stub_state/unit.fake-hwclock-load.service"
if ! sca appliance info > "${HOME}/out" 2>&1; then
  fail "info exited non-zero"
fi
for expected in 'model     Pine64 Rock64' 'profile   rock64' 'irreversible: no' \
    'rtc1 rtc-ds1307 0-0068 hctosys=0' 'root      /dev/mmcblk1p1 on mmcblk1, transport: none' \
    'NTP=no NTPSynchronized=no' 'fake-hwclock-load.service enabled' 'boot      2026.04'; do
  grep -qF -- "$expected" "${HOME}/out" || fail "info lacks '$expected'"
done
# and without a matching profile
printf 'acme,widget\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
assert_succeeds sca appliance info
sca appliance info 2>&1 | grep -q 'none matches' || fail "info does not say no profile matched"

test_done
