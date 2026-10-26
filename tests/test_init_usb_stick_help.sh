#!/bin/bash
# sca init sca_usb_stick: the printed USB-write instructions must never name a
# concrete /dev/sd<letter> device - only the /dev/sdX placeholder - and must
# still print when lsblk is missing.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

iso=/tmp/ubuntu.sca.iso

# print_help PATH - prints the USB-write instructions with PATH set to PATH
print_help() {
  local path=$1
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    PATH="${path}"
    print_sca_disk_image_help "${iso}"
  )
}

check_output() {
  local label=$1 output=$2
  printf '%s\n' "${output}" | grep -E '/dev/sd[a-z]' | grep -qvE '/dev/sdX' \
    && fail "${label}: concrete device named: ${output}"
  [[ "${output}" == *"sudo umount /dev/sdX1"* ]] \
    || fail "${label}: no umount /dev/sdX1: ${output}"
  [[ "${output}" == *"sudo dd bs=4M if=${iso} of=/dev/sdX conv=fdatasync"* ]] \
    || fail "${label}: no dd to /dev/sdX: ${output}"
}

# lsblk available: listed devices are fine, commands use the placeholder
output="$(print_help "${PATH}" 2>&1)"
check_output "with lsblk" "${output}"

# lsblk missing: still prints the instructions, with a hint
empty_bin="${HOME}/empty-bin"
mkdir -p "${empty_bin}"
output="$(print_help "${empty_bin}" 2>&1)"
check_output "without lsblk" "${output}"
[[ "${output}" == *"lsblk not found"* ]] \
  || fail "without lsblk: no hint: ${output}"

test_done
