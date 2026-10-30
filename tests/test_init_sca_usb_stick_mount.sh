#!/bin/bash
# init sca_usb_stick: when the original ubuntu iso cannot be mounted, the run
# stops with an error naming the mount and the file. it must not go on to
# check the layout of the empty mount folder, which would blame the iso, nor
# unmount a folder that was never mounted.
#
# the original ubuntu iso is an empty stand-in and sudo always fails, so
# nothing is ever mounted. the build host, tools and download checks are
# stubbed, so the test runs on any host and offline.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

downloads="$HOME/.sca/downloads"
original_iso="${downloads}/ubuntu-26.04.1-desktop-amd64.iso"
sudo_log="$HOME/sudo.log"

# run init sca_usb_stick from the built sca with the host checks, the download
# and sudo stubbed out. every sudo call is logged and fails, as when sudo
# cannot authenticate
# shellcheck disable=SC2317 # the stubs are called by sca
init_sca_usb_stick() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    check_build_host_ubuntu_version() { :; }
    check_iso_image_tools() { :; }
    download_ubuntu_image() { echo "${original_iso}"; }
    mount() { :; }
    sudo() {
      echo "$*" >> "${sudo_log}"
      >&2 echo "sudo: A terminal is required to authenticate"
      return 1
    }
    sca init sca_usb_stick
  )
}

sca config create all >/dev/null 2>&1 || fail "config create all"
mkdir -p "${downloads}"
touch "${original_iso}"

rm -f "${sudo_log}"
output="$(init_sca_usb_stick 2>&1)" && fail "a failed mount did not fail the run"
[[ "${output}" == *"could not mount ${original_iso}"* ]] || \
  fail "the error does not name the mount and the file: ${output}"
[[ "${output}" == *"expected layout"* ]] && \
  fail "a failed mount is reported as a bad iso layout: ${output}"
grep -q "^mount " "${sudo_log}" || fail "the iso image was never mounted"
grep -q "umount" "${sudo_log}" && \
  fail "a folder that was never mounted is unmounted: $(cat "${sudo_log}")"

test_done
