#!/bin/bash
# init sca_usb_stick: a cached sca iso image is reused only when it was built
# with the options asked for. otherwise the run fails, so a stick is never
# written from an image missing what the user requested.
#
# the original ubuntu iso and the cached sca iso are empty stand-ins, so no
# download or build ever runs: each case below either reuses or fails before it.
# the build host, tools and download checks are stubbed, so the test runs on
# any host and offline.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

downloads="$HOME/.sca/downloads"
original_iso="${downloads}/ubuntu-26.04.1-desktop-amd64.iso"
iso="${downloads}/ubuntu-26.04.1-desktop-amd64.sca.iso"

# run init sca_usb_stick from the built sca with the host checks and the
# download stubbed out
# shellcheck disable=SC2317 # the stubs are called by sca
init_sca_usb_stick() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    check_build_host_ubuntu_version() { :; }
    check_iso_image_tools() { :; }
    download_ubuntu_image() { echo "${original_iso}"; }
    sca init sca_usb_stick "$@"
  )
}

sca config create all >/dev/null 2>&1 || fail "config create all"
mkdir -p "${downloads}"
touch "${original_iso}" "${iso}"

# options_file YUBIKEY APT_MIRROR EXCLUDE_PKCS11 - record what the image has
options_file() {
  printf 'yubikey_support=%s\ninclude_apt_mirror=%s\nexclude_pkcs11_support=%s\n' \
    "$1" "$2" "$3" > "${iso}.options"
}

# an image from before the options were recorded is never reused silently
rm -f "${iso}.options"
assert_fails init_sca_usb_stick
output="$(init_sca_usb_stick -y 2>&1)"
[[ "${output}" == *"not built with the requested options"* ]] || \
  fail "unrecorded options: no mismatch message: ${output}"
[[ "${output}" == *"sudo dd"* ]] && fail "unrecorded options: write instructions printed"

# built without yubikey support, asked with it
options_file false false false
assert_fails init_sca_usb_stick --yubikey-support
output="$(init_sca_usb_stick --yubikey-support 2>&1 >/dev/null)"
[[ "${output}" == *"built with: yubikey_support=false"* ]] || \
  fail "mismatch: stderr does not say what the image has: ${output}"
[[ "${output}" == *"requested:  yubikey_support=true"* ]] || \
  fail "mismatch: stderr does not say what was requested: ${output}"
assert_file_exists "${iso}" "mismatch: the cached image must be left alone"

# the reverse: built with yubikey support, asked without
options_file true false false
assert_fails init_sca_usb_stick

# each of the other content options counts too
options_file false false false
assert_fails init_sca_usb_stick -x
assert_fails init_sca_usb_stick -i

# matching options: reused, with the write instructions
options_file true true true
assert_succeeds init_sca_usb_stick -y -i -x
output="$(init_sca_usb_stick -y -i -x 2>&1)"
[[ "${output}" == *"already exists"* ]] || fail "match: not reused: ${output}"
[[ "${output}" == *"sudo dd bs=4M if=${iso}"* ]] || \
  fail "match: no write instructions: ${output}"

test_done
