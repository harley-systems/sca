#!/bin/bash
# appliance verify and info: every check passes on a platform set up as intended,
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
uname() {
  cat "$stub_state/machine"
}
vcgencmd() {
  echo "[all]"
  echo "BOOT_UART=0"
  echo "BOOT_ORDER=$(cat "$stub_state/boot_order")"
}
export -f findmnt lsblk timedatectl systemctl journalctl uname vcgencmd

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
  echo aarch64 > "$stub_state/machine"
}
# an x86 mini PC set up as intended: no device tree, the CMOS clock as rtc0,
# root on a USB stick, fake-hwclock not installed
setup_x86() {
  setup_rock64
  rm -rf "${SCA_APPLIANCE_ROOT}/proc" "${SCA_APPLIANCE_ROOT}/sys/class/rtc/rtc1"
  set_rtc rtc0 'rtc_cmos 00:01' 1
  echo x86_64 > "$stub_state/machine"
  for unit in fake-hwclock-load.service fake-hwclock-save.service fake-hwclock-save.timer; do
    echo "Failed to get unit file state for ${unit}: No such file or directory" \
      > "$stub_state/unit.${unit}"
  done
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

# no ~/.sca/config is needed: verify must work on a platform with no CA
setup_rock64
if ! sca appliance verify > "${HOME}/out" 2>&1; then
  fail "verify failed on a platform set up as intended"
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

# the clock moved forward across the power cut: a genuine pass
setup_rock64
sca appliance verify > "${HOME}/out" 2>&1 || fail "forward clock: verify exited non-zero"
assert_eq ok "$(row "power cut")" "forward clock: power cut row"
grep -qF 'clock kept through power-off' "${HOME}/out" || fail "forward clock: no detail"

# no previous boot in a volatile journal: skipped, not ok, and not a failure
setup_rock64
rm "$stub_state/previous_epoch"
sca appliance verify > "${HOME}/out" 2>&1 || fail "volatile journal: verify exited non-zero"
assert_eq skipped "$(row "power cut")" "volatile journal: power cut row"
for label in boot root rtc clock hwclock; do
  assert_eq ok "$(row "$label")" "volatile journal: $label row"
done
grep -qF 'journal is volatile: no /var/log/journal' "${HOME}/out" \
  || fail "volatile journal: the row does not name the journal"

# no previous boot in a persistent journal yet: skipped too
setup_rock64
rm "$stub_state/previous_epoch"
mkdir -p "${SCA_APPLIANCE_ROOT}/var/log/journal"
sca appliance verify > "${HOME}/out" 2>&1 || fail "persistent journal: verify exited non-zero"
assert_eq skipped "$(row "power cut")" "persistent journal: power cut row"
grep -qF 'no previous boot in the journal' "${HOME}/out" \
  || fail "persistent journal: the row does not name the journal"

# a skipped power cut does not hide a real failure, and is not counted as one
setup_rock64
rm "$stub_state/previous_epoch"
echo yes > "$stub_state/ntp_synced"
sca appliance verify > "${HOME}/out" 2>&1 && fail "skipped: verify exited 0 with NTP synced"
assert_eq skipped "$(row "power cut")" "skipped with a failure: power cut row"
grep -q "appliance verify: 1 check(s) failed" "${HOME}/out" || fail "skipped counted as a failure"

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

# an unknown option or a stray argument is an error, not ignored: on a
# platform set up as intended, ignoring it would exit 0
setup_rock64
assert_fails sca appliance verify --platfrom raspberrypi
assert_fails sca appliance verify --board rock64
assert_fails sca appliance verify raspberrypi
assert_fails sca appliance verify --platform rock64 extra
assert_fails sca appliance info --platfrom rock64
assert_fails sca appliance info rock64
sca appliance verify raspberrypi > "${HOME}/out" 2>&1
grep -qF "unexpected argument 'raspberrypi'" "${HOME}/out" || fail "stray argument not named"
grep -q '^  boot ' "${HOME}/out" && fail "verify ran checks despite a stray argument"

# an unknown platform: exit 1 with the known platforms
setup_rock64
printf 'acme,widget\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
sca appliance verify > "${HOME}/out" 2>&1
assert_eq 1 "$?" "undetected platform exit status"
grep -q "known platforms: raspberrypi rock64 x86" "${HOME}/out" || fail "undetected platform: platforms not listed"
# --platform overrides detection
assert_succeeds sca appliance verify --platform rock64
assert_fails sca appliance verify --platform acme
# no device tree at all, on an arm64 machine no profile matches by arch
rm -rf "${SCA_APPLIANCE_ROOT}/proc"
assert_fails sca appliance verify
# nor on a machine sca knows no arch for
echo riscv64 > "$stub_state/machine"
assert_fails sca appliance verify

# an x86 mini PC: detected by arch with no device tree, the boot row is n/a
# and not a failure, and rtc_cmos passes as rtc0
setup_x86
if ! sca appliance verify > "${HOME}/out" 2>&1; then
  fail "verify failed on an x86 mini PC set up as intended"
  cat "${HOME}/out" >&2
fi
assert_eq "profile x86 is a proposal (unverified)" "$(head -n 1 "${HOME}/out")" "x86 unverified banner"
assert_eq n/a "$(row boot)" "x86: boot row"
grep -qF 'platform boots USB natively' "${HOME}/out" || fail "x86: boot row does not say why it is n/a"
for label in root rtc clock hwclock "power cut"; do
  assert_eq ok "$(row "$label")" "x86: $label row"
done
grep -qF 'rtc_cmos is rtc0, hctosys=1' "${HOME}/out" || fail "x86: rtc_cmos not reported as rtc0"
# n/a does not hide a real failure elsewhere
echo yes > "$stub_state/ntp_synced"
sca appliance verify > "${HOME}/out" 2>&1 && fail "x86: verify exited 0 with NTP synced"
grep -q "appliance verify: 1 check(s) failed" "${HOME}/out" || fail "x86: n/a counted as a failure"
# the device tree still wins over the arch fallback
setup_rock64
echo x86_64 > "$stub_state/machine"
sca appliance verify > "${HOME}/out" 2>&1
assert_eq ok "$(row boot)" "rock64 detected by device tree despite the arch"

# two profiles that both qualify for the arch fallback: an error, not a guess
setup_x86
sed '/^APPLIANCE_PLATFORM_PROFILES$/i [x86b]\narch=amd64' "${SCA}" > "${HOME}/sca-two-x86.sh"
SCA="${HOME}/sca-two-x86.sh" sca appliance verify > "${HOME}/out" 2>&1
assert_eq 1 "$?" "two x86 profiles exit status"
grep -q 'profiles x86 x86b all match arch amd64' "${HOME}/out" \
  || fail "two x86 profiles: no error naming both"
SCA="${HOME}/sca-two-x86.sh" assert_succeeds sca appliance verify --platform x86

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
# the profile keys of the platform model are shown
for expected in 'arch: arm64' 'boot_prep: uboot-spi' 'rtc: i2c-ds3231'; do
  grep -qF -- "$expected" "${HOME}/out" || fail "info lacks '$expected'"
done
# on x86 the boot probe is n/a
setup_x86
sca appliance info > "${HOME}/out" 2>&1 || fail "x86: info exited non-zero"
for expected in 'profile   x86' 'arch: amd64' 'boot_prep: none' 'rtc: builtin' \
    'boot      n/a - platform boots USB natively'; do
  grep -qF -- "$expected" "${HOME}/out" || fail "x86: info lacks '$expected'"
done
# and without a matching profile
setup_rock64
printf 'acme,widget\0' > "${SCA_APPLIANCE_ROOT}/proc/device-tree/compatible"
assert_succeeds sca appliance info
sca appliance info 2>&1 | grep -q 'none matches' || fail "info does not say no profile matched"

test_done
