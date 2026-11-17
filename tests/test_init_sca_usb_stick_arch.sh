#!/bin/bash
# init sca_usb_stick: the stick is amd64, so it is built on x86_64 hosts only.
# any other host is refused before anything is downloaded, even with every
# tool installed, and the message names the host architecture.
#
# uname is stubbed to report FAKE_ARCH, and the tools are stand-ins on PATH, so
# the test runs on any host and offline.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

uname() {
  if [ "$1" = -m ]; then echo "${FAKE_ARCH:-x86_64}"; else command uname "$@"; fi
}
export -f uname

# PATH is a folder linking every tool of this host except apt-mirror, plus
# executable stand-ins for the build tools
tools_bin="$(mktemp -d "${TMPDIR:-/tmp}/sca-test-bin.XXXXXX")" || exit 2
# shellcheck disable=SC2154 # test_home is set by lib.sh
trap 'rm -rf "${test_home}" "${tools_bin}"' EXIT
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin; do
  for tool in "${dir}"/*; do
    [ "${tool##*/}" = apt-mirror ] && continue
    [ -e "${tools_bin}/${tool##*/}" ] || ln -s "${tool}" "${tools_bin}/${tool##*/}"
  done
done
for tool in wget gpgv base64 sha256sum md5sum xorriso mksquashfs unsquashfs apt-get; do
  rm -f "${tools_bin}/${tool}"
  printf '#!/bin/sh\nexit 0\n' > "${tools_bin}/${tool}"
  chmod 755 "${tools_bin}/${tool}"
done

# run init sca_usb_stick from the built sca with the ubuntu version check
# stubbed out. the download must never be reached.
# shellcheck disable=SC2317 # the stubs are called by sca
init_sca_usb_stick() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    check_build_host_ubuntu_version() { :; }
    check_sca_to_ship() { :; }
    download_ubuntu_image() { echo "download reached" >&2; exit 3; }
    sca init sca_usb_stick "$@"
  )
}

sca config create all >/dev/null 2>&1 || fail "config create all"

# aarch64 with every tool present: refused, naming the architecture
printf '#!/bin/sh\nexit 0\n' > "${tools_bin}/apt-mirror"
chmod 755 "${tools_bin}/apt-mirror"
output="$(FAKE_ARCH=aarch64 PATH="${tools_bin}" init_sca_usb_stick -i 2>&1)"
status=$?
assert_eq 1 "${status}" "aarch64 host exits 1: ${output}"
[[ "${output}" == *"this host is aarch64"*"only be built on an x86_64 host"* ]] \
  || fail "the message names the architecture and x86_64: ${output}"
[[ "${output}" != *"sca install"* ]] || fail "sca install is not suggested: ${output}"
[[ "${output}" != *"download reached"* ]] || fail "nothing is downloaded: ${output}"

# x86_64 with a tool missing: the missing tools message is unchanged
rm -f "${tools_bin}/apt-mirror"
output="$(FAKE_ARCH=x86_64 PATH="${tools_bin}" init_sca_usb_stick -i 2>&1)"
status=$?
assert_eq 1 "${status}" "missing tool exits 1: ${output}"
[[ "${output}" == *"missing tools: "*"apt-mirror. run 'sca install' to install them."* ]] \
  || fail "missing tools are named: ${output}"

test_done
