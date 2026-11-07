#!/bin/bash
# init sca_usb_stick --board: pc, the default, builds the ubuntu iso as before;
# rock64 builds the sca image from the armbian image of the board; any other
# board, and the options a rock64 image does not support, fail before anything
# is downloaded.
#
# for rock64, the build runs end to end on a stand-in armbian root file system.
# the download, xz, losetup and mount are stubbed: "mounting" the image copies
# the stand-in root file system kept for it into the mount folder, unmounting
# copies it back. sudo runs every other command as the user, and apt-get
# records its options and leaves a stand-in .deb. so nothing needs root and the
# test runs offline, while every file sca puts into the image is checked.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

downloads="$HOME/.sca/downloads/"
image_name="Armbian_community_26.11.0-trunk.108_Rock64_resolute_current_6.18.57_minimal"
armbian_image_file="${downloads}${image_name}.img.xz"
sca_image="${downloads}${image_name}.sca.img"
rootfs="$HOME/rootfs/"
calls="$HOME/calls.log"

# run init sca_usb_stick from the built sca with the host checks, the downloads
# and the image tools stubbed out. every stubbed call is logged
# shellcheck disable=SC2317 # the stubs are called by sca
init_sca_usb_stick() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    check_build_host_ubuntu_version() { :; }
    check_iso_image_tools() { echo "check_iso_image_tools $*" >> "${calls}"; }
    check_sca_to_ship() { :; }
    download_ubuntu_image() { echo "download_ubuntu_image $*" >> "${calls}"; return 1; }
    download_armbian_image() {
      echo "download_armbian_image $*" >> "${calls}"
      echo "${armbian_image_file}"
    }
    xz() { cat "$2"; }
    sleep() { :; }
    lsblk() { echo "NAME TRAN RM SIZE MODEL"; }
    sudo() {
      case "$1" in
        losetup )
          echo "sudo $*" >> "${calls}"
          [ "$2" = -d ] || echo /dev/loop7
          ;;
        mount )
          echo "sudo $*" >> "${calls}"
          cp -R "${rootfs}." "${!#}"
          ;;
        umount )
          echo "sudo $*" >> "${calls}"
          rm -rf "${rootfs}" && cp -R "$2" "${rootfs}" && rm -rf "${2:?}"/*
          ;;
        apt-get )
          echo "sudo $*" >> "${calls}"
          local option
          for option in "$@"; do
            [[ "${option}" == Dir::Cache::archives=* ]] && \
              touch "${option#Dir::Cache::archives=}pcscd_2.4.1-1_arm64.deb"
          done
          return 0
          ;;
        * ) "$@" ;;
      esac
    }
    sca init sca_usb_stick "$@"
  )
}

# reset - a stand-in armbian image and root file system, and no sca image
reset() {
  rm -rf "${downloads}" "${rootfs}" "${calls}" "$HOME/.sca/armbian_image"
  mkdir -p "${downloads}" "${rootfs}etc/default" "${rootfs}var/lib/dpkg"
  echo "not really an armbian image" > "${armbian_image_file}"
  echo "BOARD=rock64" > "${rootfs}etc/armbian-release"
  printf 'ENABLED=true\nSIZE=50M\n' > "${rootfs}etc/default/armbian-ramlog"
  printf 'Package: openssl\nStatus: install ok installed\n' > "${rootfs}var/lib/dpkg/status"
}

# expect_error MESSAGE ARGS... - init sca_usb_stick ARGS fails and says MESSAGE,
# downloading nothing
expect_error() {
  local message=$1; shift
  local output
  rm -f "${calls}"
  output="$(init_sca_usb_stick "$@" 2>&1)" && fail "expected failure: $*"
  [[ "${output}" == *"${message}"* ]] || fail "expected '${message}' from $*, got: ${output}"
  grep -q "^download" "${calls}" 2>/dev/null && fail "$*: downloaded before failing"
}

sca config create all >/dev/null 2>&1 || fail "config create all"
mkdir -p "$HOME/bin" && cp "${SCA}" "$HOME/bin/sca"

# the help covers --board
output="$(sca init sca_usb_stick --help 2>&1)"
[[ "${output}" == *"--board <board>"* ]] || fail "help: no --board"
[[ "${output}" == *"rock64"* ]] || fail "help: no rock64"

# bash completion offers the boards after --board, and the version id after it
# complete WORDS... - prints the completion of the last word
complete_words() {
  (
    # shellcheck source=/dev/null
    . <(sca completion bash)
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMPREPLY=()
    _sca_complete
    echo "${COMPREPLY[*]}"
  )
}
assert_eq "pc rock64" "$(complete_words sca init sca_usb_stick --board '')" "completion: boards"
assert_eq "26.04-resolute" "$(complete_words sca init sca_usb_stick -y --board rock64 '')" \
  "completion: version id after the board"

# unknown boards fail, listing the supported ones
expect_error "unknown board 'rockpro64'. the supported boards are: pc rock64." --board rockpro64
expect_error "unknown board 'PC'" -b PC

# the options a rock64 image does not support fail, saying why
expect_error "--test-image is not supported with --board rock64. sca test boots the test image in qemu-system-x86_64" \
  --board rock64 --test-image
expect_error "--include-apt-mirror is not supported with --board rock64" --board rock64 -i
# the release check still applies
expect_error "unsupported ubuntu version id '24.04-noble'" --board rock64 24.04-noble

# no --board, and --board pc, build the ubuntu iso
for args in "" "--board pc" "-b pc" "--board=pc"; do
  rm -f "${calls}"
  # shellcheck disable=SC2086 # split the options
  init_sca_usb_stick ${args} >/dev/null 2>&1
  grep -q "^download_ubuntu_image " "${calls}" || fail "'${args}': no ubuntu download"
  grep -q "^download_armbian_image " "${calls}" && fail "'${args}': armbian download"
  grep -qx "check_iso_image_tools false pc" "${calls}" || fail "'${args}': pc tools not checked"
done

# --board rock64: built from the armbian image
reset
output="$(init_sca_usb_stick -y --board rock64 2>&1)" || fail "rock64 build failed: ${output}"
grep -qx "download_armbian_image rock64 resolute ${downloads}" "${calls}" || \
  fail "rock64: armbian image not downloaded: $(cat "${calls}")"
grep -q "^download_ubuntu_image " "${calls}" && fail "rock64: ubuntu download"
grep -qx "check_iso_image_tools false rock64" "${calls}" || fail "rock64: tools not checked"
assert_file_exists "${sca_image}" "rock64: no sca image"
[ -e "${sca_image}.part" ] && fail "rock64: partial image left"
assert_eq "$(printf 'yubikey_support=true\ninclude_apt_mirror=false\nexclude_pkcs11_support=false')" \
  "$(cat "${sca_image}.options" 2>/dev/null)" "rock64: options file"
assert_eq "not really an armbian image" "$(cat "${sca_image}" 2>/dev/null)" \
  "rock64: the sca image is not the decompressed armbian image"
# nothing left attached or mounted
assert_eq "$(grep -c '^sudo losetup --find' "${calls}")" "$(grep -c '^sudo losetup -d' "${calls}")" \
  "rock64: loop devices attached and detached"
assert_eq "$(grep -c '^sudo mount' "${calls}")" "$(grep -c '^sudo umount' "${calls}")" \
  "rock64: mounts and unmounts"
grep -q "^sudo mount -t ext4 /dev/loop7p1 " "${calls}" || fail "rock64: root partition 1 not mounted"
# the packages are resolved for arm64 from ports.ubuntu.com, against the
# image's dpkg status
grep "^sudo apt-get .* install " "${calls}" | grep -q "APT::Architecture=arm64" || \
  fail "rock64: packages not downloaded for arm64: $(grep apt-get "${calls}")"
grep "^sudo apt-get .* install " "${calls}" | grep -q "Dir::Etc::SourceList=/dev/null" || \
  fail "rock64: host apt sources used"
apt_options="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  get_armbian_apt_options rock64 resolute "$HOME/apt/"
)"
[[ "${apt_options}" == *"-o APT::Architectures=arm64"* ]] || fail "rock64: apt options: ${apt_options}"
[[ "${apt_options}" == *"-o Dir::Etc::SourceParts=$HOME/apt/sources.list.d"* ]] || \
  fail "rock64: apt sources not kept apart: ${apt_options}"
assert_eq "Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: resolute resolute-security resolute-updates
Components: main restricted universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" \
  "$(cat "$HOME/apt/sources.list.d/ubuntu-ports.sources")" "rock64: ports sources"
# what sca put into the image
assert_file_exists "${rootfs}opt/sca/bin/sca" "rock64: sca"
assert_file_exists "${rootfs}etc/profile.d/sca.sh" "rock64: first login installer"
grep -q "/opt/sca/bin/sca -d install --air-gapped --yubikey-support" "${rootfs}etc/profile.d/sca.sh" || \
  fail "rock64: the first login installer does not install sca"
grep -q "sca test" "${rootfs}etc/profile.d/sca.sh" && fail "rock64: test commands in a regular image"
assert_file_exists "${rootfs}opt/sca/packages/pcscd_2.4.1-1_arm64.deb" "rock64: arm64 packages"
assert_file_exists "${rootfs}etc/ssl/sca/sca.config" "rock64: sca configuration"
assert_file_exists "${rootfs}etc/bash_completion.d/sca" "rock64: sca completion"
assert_file_exists "${rootfs}etc/armbian-release" "rock64: the image's own files"
for unit in fake-hwclock-load.service fake-hwclock-save.service fake-hwclock-save.timer; do
  assert_eq "/dev/null" "$(readlink "${rootfs}etc/systemd/system/${unit}")" "rock64: ${unit} masked"
done
assert_eq "$(printf '[Journal]\nStorage=persistent\nSystemMaxUse=64M\nSystemMaxFileSize=8M')" \
  "$(cat "${rootfs}etc/systemd/journald.conf.d/zz-sca-appliance.conf" 2>/dev/null)" \
  "rock64: persistent journal"
assert_eq "$(printf 'ENABLED=false\nSIZE=50M')" "$(cat "${rootfs}etc/default/armbian-ramlog")" \
  "rock64: armbian-ramlog disabled"
# the write instructions: the medium the board boots, the usb prerequisite,
# and never a concrete device
[[ "${output}" == *"written: ${sca_image}"* ]] || fail "rock64: image not named: ${output}"
[[ "${output}" == *"rock64 boots this image from a microSD card as written"* ]] || \
  fail "rock64: boot medium not named: ${output}"
[[ "${output}" == *"docs/usb-boot-on-arm.md"* ]] || fail "rock64: usb boot doc not named: ${output}"
[[ "${output}" == *"sudo dd bs=4M if=${sca_image} of=/dev/sdX conv=fdatasync"* ]] || \
  fail "rock64: no dd to /dev/sdX: ${output}"
printf '%s\n' "${output}" | grep -E '/dev/(sd[a-z]|mmcblk[0-9])' | grep -qvE '/dev/sdX' && \
  fail "rock64: concrete device named: ${output}"
[ -d "$HOME/.sca/live_filesystem" ] && fail "rock64: intermediary files left"

# a second run reuses the image built with the same options, and refuses one
# built with others
rm -f "${calls}"
output="$(init_sca_usb_stick -y --board rock64 2>&1)" || fail "rock64 reuse failed: ${output}"
[[ "${output}" == *"the image ${sca_image} already exists"* ]] || fail "rock64: not reused: ${output}"
grep -q "^sudo losetup" "${calls}" && fail "rock64 reuse: image attached"
expect_rebuild="$(init_sca_usb_stick --board rock64 2>&1)" && fail "rock64: reused with other options"
[[ "${expect_rebuild}" == *"was not built with the requested options"* ]] || \
  fail "rock64: no options mismatch: ${expect_rebuild}"

# an image without an armbian root file system on partition 1 is refused, and
# left neither attached nor mounted
reset
rm "${rootfs}etc/armbian-release"
output="$(init_sca_usb_stick --board rock64 2>&1)" && fail "rock64: a non-armbian image was used"
[[ "${output}" == *"does not have the expected layout"* ]] || fail "rock64 layout: ${output}"
assert_eq "$(grep -c '^sudo mount' "${calls}")" "$(grep -c '^sudo umount' "${calls}")" \
  "rock64 layout: mounts and unmounts"
grep -q "^sudo losetup -d /dev/loop7" "${calls}" || fail "rock64 layout: loop device not detached"
[ -e "${sca_image}" ] || [ -e "${sca_image}.part" ] && fail "rock64 layout: image left"

test_done
