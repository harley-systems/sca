#!/bin/bash
# init sca_usb_stick --board rock64: the armbian image is used only when it
# matches the sha256 armbian publishes for it (.sha) and carries a good
# detached signature (.asc), over the .img.xz itself, of the pinned armbian
# image signing key. a missing or bad signature, a signature by another key, an
# image that does not match its sha256 and a .sha that does not name an armbian
# image of the release each stop the build with their own error.
#
# wget is stubbed to copy from a local folder, so the test runs offline. the
# test key, and the stand-in image it signs, are the ones of
# test_ubuntu_iso_signature.sh: tests/fixtures/iso_signature/SHA256SUMS plays
# the .img.xz and SHA256SUMS.gpg, a detached signature over it, the .asc.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

fixtures="${tests_dir}/fixtures/iso_signature"
test_fingerprint="007263F12EE2F942B8EE8132264F92C22FFCA59E"
armbian_fingerprint="DF00FAF1C577104B50BF1D0093D6889F9F0E78D5"
downloads="$HOME/.sca/downloads/"
server="$HOME/server"
image_url="https://dl.armbian.com/rock64/Resolute_current_minimal"
image_name="Armbian_community_26.11.0-trunk.108_Rock64_resolute_current_6.18.57_minimal.img.xz"
image="${downloads}${image_name}"
sha="${downloads}armbian-rock64-resolute.sha"

# run an sca function from the built sca, with wget serving ${server}/latest*
# for ${image_url}* and, unless pin_real_key=true, the test key in place of the
# armbian key
# shellcheck disable=SC2317 # the stubs are called by sca
run_sca() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    # shellcheck disable=SC2034 # read by sca
    log_file="$HOME/.sca/log"
    wget() {
      local out url
      while [ $# -gt 0 ]; do
        case "$1" in
          -O ) out=$2; shift 2 ;;
          --append-output ) shift 2 ;;
          -* ) shift ;;
          * ) url=$1; shift ;;
        esac
      done
      echo "${url}" >> "$HOME/wget.log"
      cp "${server}/latest${url#"${image_url}"}" "${out}" 2>/dev/null
    }
    get_armbian_image_keyring() { cat "${fixtures}/test-keyring.asc"; }
    if [ "${pin_real_key:-false}" != true ]; then
      get_armbian_image_signing_key_fingerprint() { echo "${test_fingerprint}"; }
    fi
    "$@"
  )
}

# publish_sha FILE_NAME - publishes the sha256 of the served image, naming it
publish_sha() {
  echo "$(sha256sum < "${server}/latest" | cut -d ' ' -f 1) $1" > "${server}/latest.sha"
}

# reset - an empty downloads folder and a server publishing the stand-in image
reset() {
  rm -rf "${downloads}" "${server}" "$HOME/wget.log"
  mkdir -p "${downloads}" "${server}"
  cp "${fixtures}/SHA256SUMS" "${server}/latest"
  cp "${fixtures}/SHA256SUMS.gpg" "${server}/latest.asc"
  publish_sha "${image_name}"
}

# expect_error MESSAGE COMMAND... - the command fails and says MESSAGE
expect_error() {
  local message=$1; shift
  local output
  output="$(run_sca "$@" 2>&1)" && fail "expected failure: $*"
  [[ "${output}" == *"${message}"* ]] || fail "expected '${message}' from $*, got: ${output}"
}

assert_no_image() {
  [ -e "${image}" ] && fail "$1: the image was kept"
  [ -e "${image}.part" ] && fail "$1: the partial image was kept"
  [ -e "${image}.asc" ] && fail "$1: the signature was kept"
}

download() {
  run_sca download_armbian_image rock64 resolute "${downloads}"
}

sca config create all >/dev/null 2>&1 || fail "config create all"

# the board table points at the armbian image of the release
assert_eq "${image_url}" "$(run_sca get_sca_usb_stick_board_field rock64 image_url resolute)" \
  "rock64 image url"

# a good image: downloaded, checked and cached with its .sha and .asc
reset
assert_eq "${image}" "$(download 2>/dev/null)" "good image: downloaded image"
assert_file_exists "${image}" "good image"
assert_file_exists "${image}.asc" "good image: signature cached"
assert_file_exists "${sha}" "good image: .sha cached"
grep -qx "${image_url}" "$HOME/wget.log" || fail "good image: not downloaded from ${image_url}"

# offline, the cached image is checked again against the cached .sha and .asc
rm -rf "${server}"; mkdir -p "${server}"
assert_eq "${image}" "$(download 2>/dev/null)" "offline: cached image"

# offline, a cached image that changed is not used, and left alone
echo "tampered" >> "${image}"
expect_error "the local image ${image} does not match the sha256" download
assert_file_exists "${image}" "offline tampered: the user's image was removed"

# a downloaded image that does not match the published sha256
reset
echo "tampered" >> "${server}/latest"
expect_error "does not match the sha256 of ${image_name}" download
assert_no_image "sha256 mismatch"

# an image that matches the .sha (which is not signed) but not the signature
reset
echo "tampered" >> "${server}/latest"
publish_sha "${image_name}"
expect_error "does not match its signature ${image}.asc: it was modified" download
assert_no_image "bad signature"

# no signature published: an unsigned image is never used, nor downloaded
reset
rm "${server}/latest.asc"
expect_error "an unsigned image is never used" download
assert_no_image "missing signature"
grep -qx "${image_url}" "$HOME/wget.log" && fail "missing signature: the image was downloaded"

# a signature that can not be checked: by a key not in the keyring
reset
cp "${fixtures}/ubuntu-24.04-SHA256SUMS.gpg" "${server}/latest.asc"
expect_error "could not be checked with the armbian image signing key" download
assert_no_image "unknown key"

# a good signature, but not by the pinned key: the fingerprint check
reset
pin_real_key=true expect_error \
  "is signed by ${test_fingerprint}, not by the armbian image signing key ${armbian_fingerprint}" \
  download
assert_no_image "other key"

# a .sha that is not one: a mirror's html page in its place
reset
printf '<html>\n<head><title>Welcome</title></head>\n</html>\n' > "${server}/latest.sha"
expect_error "does not name an armbian resolute image" download
[ -e "${sha}" ] && fail "html .sha: kept"

# a .sha naming a file outside the downloads folder
reset
publish_sha "../${image_name}"
expect_error "does not name an armbian resolute image" download
[ -e "$HOME/.sca/${image_name}" ] && fail "path in .sha: written outside the downloads folder"

# a .sha naming an image of another release
reset
publish_sha "${image_name/resolute/noble}"
expect_error "does not name an armbian resolute image" download

# the bundled keyring is the armbian one, not the test key: a test signature
# can not be checked with it
reset
(
  # shellcheck source=/dev/null
  . "${SCA}"
  get_armbian_image_keyring | grep -q 'BEGIN PGP PUBLIC KEY BLOCK'
) || fail "no armbian keyring bundled"
output="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  get_gpgv_status get_armbian_image_keyring "${fixtures}/SHA256SUMS.gpg" "${fixtures}/SHA256SUMS"
)"
[[ "${output}" == *VALIDSIG* ]] && fail "the bundled armbian keyring accepts the test key"

test_done
