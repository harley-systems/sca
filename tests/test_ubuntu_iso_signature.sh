#!/bin/bash
# init sca_usb_stick: the ubuntu iso is used only when its SHA256SUMS carries a
# good signature of the pinned ubuntu cd image signing key and the iso matches
# its line there. a modified SHA256SUMS, a missing or bad signature, a signature
# by another key and an iso that does not match each stop the build with their
# own error, before anything is mounted.
#
# wget is stubbed to copy from a local folder, so the test runs offline. the
# fixtures in tests/fixtures/iso_signature/ are:
#
# - test-keyring.asc, SHA256SUMS, SHA256SUMS.gpg: a throwaway test key, used
#   only here, and a SHA256SUMS listing a stand-in iso it signs. to regenerate:
#     export GNUPGHOME=$(mktemp -d)
#     gpg --batch --passphrase '' --quick-gen-key \
#       'sca test iso signing key (throwaway, tests only)' rsa2048 sign never
#     gpg --armor --export > test-keyring.asc
#     printf 'not really an ubuntu iso\n' | sha256sum   # the 26.04.1 line
#     gpg --armor --detach-sign -o SHA256SUMS.gpg SHA256SUMS
# - ubuntu-24.04-SHA256SUMS{,.gpg}: the files published at
#   https://releases.ubuntu.com/24.04/, signed by the real ubuntu key, to check
#   the keyring bundled in sca.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

fixtures="${tests_dir}/fixtures/iso_signature"
test_fingerprint="007263F12EE2F942B8EE8132264F92C22FFCA59E"
ubuntu_fingerprint="843938DF228D22F7B3742BC0D94AA3F0EFE21092"
downloads="$HOME/.sca/downloads/"
server="$HOME/server"
iso_name="ubuntu-26.04.1-desktop-amd64.iso"
iso="${downloads}${iso_name}"
sums="${downloads}ubuntu-26.04-SHA256SUMS"
extract_marker="$HOME/extracted"

# run an sca function from the built sca, with wget copying from ${server} and,
# unless pin_real_key=true, the test key in place of the ubuntu key
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
      cp "${server}/${url##*/}" "${out}" 2>/dev/null
    }
    get_ubuntu_cdimage_keyring() { cat "${fixtures}/test-keyring.asc"; }
    if [ "${pin_real_key:-false}" != true ]; then
      get_ubuntu_cdimage_signing_key_fingerprint() { echo "${test_fingerprint}"; }
    fi
    check_build_host_ubuntu_version() { :; }
    check_iso_image_tools() { :; }
    extract_iso_image_files() { touch "${extract_marker}"; exit 1; }
    "$@"
  )
}

# reset - an empty downloads folder and a server publishing the fixtures
reset() {
  rm -rf "${downloads}" "${server}" "${extract_marker}"
  mkdir -p "${downloads}" "${server}"
  cp "${fixtures}/SHA256SUMS" "${fixtures}/SHA256SUMS.gpg" "${server}/"
  printf 'not really an ubuntu iso\n' > "${server}/${iso_name}"
}

# expect_error MESSAGE COMMAND... - the command fails and says MESSAGE
expect_error() {
  local message=$1; shift
  local output
  output="$(run_sca "$@" 2>&1)" && fail "expected failure: $*"
  [[ "${output}" == *"${message}"* ]] || fail "expected '${message}' from $*, got: ${output}"
}

assert_no_downloads() {
  local left
  left=$(ls -A "${downloads}")
  [ -z "${left}" ] || fail "$1: files left in the downloads folder: ${left}"
}

sca config create all >/dev/null 2>&1 || fail "config create all"

# a good iso: downloaded, checked and cached with its signed SHA256SUMS
reset
assert_eq "${iso}" "$(run_sca download_ubuntu_image 26.04 "${downloads}" 2>/dev/null)" \
  "good iso: downloaded image"
assert_file_exists "${iso}" "good iso"
assert_file_exists "${sums}" "good iso: SHA256SUMS cached"
assert_file_exists "${sums}.gpg" "good iso: SHA256SUMS.gpg cached"

# offline, the cached pair is checked again and the cached iso reused
rm -rf "${server}"; mkdir -p "${server}"
assert_eq "${iso}" "$(run_sca download_ubuntu_image 26.04 "${downloads}" 2>/dev/null)" \
  "offline: cached image"

# offline with a modified cached SHA256SUMS
echo "0000 *ubuntu-26.04.2-desktop-amd64.iso" >> "${sums}"
expect_error "does not match its signature: it was modified" \
  download_ubuntu_image 26.04 "${downloads}"
[ -f "${sums}" ] || [ -f "${sums}.gpg" ] && fail "offline modified: signed pair not removed"

# offline with a cached SHA256SUMS from before signatures were checked
reset
cp "${fixtures}/SHA256SUMS" "${sums}"
rm -rf "${server}"; mkdir -p "${server}"
expect_error "has no signature file" download_ubuntu_image 26.04 "${downloads}"
assert_no_downloads "offline unsigned"

# a modified SHA256SUMS
reset
echo "0000 *ubuntu-26.04.2-desktop-amd64.iso" >> "${server}/SHA256SUMS"
expect_error "does not match its signature: it was modified" \
  download_ubuntu_image 26.04 "${downloads}"
assert_no_downloads "modified"

# a missing signature
reset
rm "${server}/SHA256SUMS.gpg"
expect_error "could not download https://releases.ubuntu.com/26.04/SHA256SUMS.gpg" \
  download_ubuntu_image 26.04 "${downloads}"
assert_no_downloads "missing signature"

# a signature that can not be checked: by a key not in the keyring
reset
cp "${fixtures}/ubuntu-24.04-SHA256SUMS.gpg" "${server}/SHA256SUMS.gpg"
expect_error "could not be checked with the ubuntu cd image signing key" \
  download_ubuntu_image 26.04 "${downloads}"
assert_no_downloads "bad signature"

# a good signature, but not by the pinned key: the fingerprint check
reset
pin_real_key=true expect_error \
  "is signed by ${test_fingerprint}, not by the ubuntu cd image signing key ${ubuntu_fingerprint}" \
  download_ubuntu_image 26.04 "${downloads}"
assert_no_downloads "other key"

# a downloaded iso that does not match its line in SHA256SUMS
reset
echo "tampered" >> "${server}/${iso_name}"
expect_error "the downloaded ${iso_name} does not match the signed SHA256SUMS" \
  download_ubuntu_image 26.04 "${downloads}"
[ -f "${iso}" ] || [ -f "${iso}.part" ] && fail "iso mismatch: image not removed"

# an iso already in the downloads folder that does not match is not used,
# downloaded over or removed
reset
echo "supplied by the user" > "${iso}"
expect_error "the local image ${iso} does not match the signed SHA256SUMS" \
  download_ubuntu_image 26.04 "${downloads}"
assert_eq "supplied by the user" "$(cat "${iso}")" "local mismatch: image left alone"

# the whole command stops before anything is mounted
reset
echo "0000 *ubuntu-26.04.2-desktop-amd64.iso" >> "${server}/SHA256SUMS"
expect_error "it was modified" sca init sca_usb_stick
[ -f "${extract_marker}" ] && fail "init: the iso image was mounted"
reset
expect_error "" sca init sca_usb_stick
[ -f "${extract_marker}" ] || fail "init: a good iso is not passed on to be mounted"

# the keyring bundled in sca holds the pinned ubuntu key: the real SHA256SUMS
# passes, and fails once modified
cp "${fixtures}/ubuntu-24.04-SHA256SUMS" "$HOME/SHA256SUMS"
cp "${fixtures}/ubuntu-24.04-SHA256SUMS.gpg" "$HOME/SHA256SUMS.gpg"
bundled() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    "$@"
  )
}
assert_succeeds bundled check_ubuntu_sha256sums_signature "$HOME/SHA256SUMS" "$HOME/SHA256SUMS.gpg"
echo "0000 *ubuntu-24.04.9-desktop-amd64.iso" >> "$HOME/SHA256SUMS"
output="$(bundled check_ubuntu_sha256sums_signature "$HOME/SHA256SUMS" "$HOME/SHA256SUMS.gpg" 2>&1)" && \
  fail "bundled key: modified SHA256SUMS accepted"
[[ "${output}" == *"it was modified"* ]] || fail "bundled key: modified: ${output}"

test_done
