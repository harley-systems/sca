#!/bin/bash
################################################################################
# integration test: builds the sca usb stick image from a real ubuntu iso.
#
# 'make check' stubs sudo, wget and the iso tools, so it only shows that the
# right commands are attempted. this runs the whole 'sca init sca_usb_stick'
# pipeline for real: download, signature check, mount, layer extraction,
# squashfs, xorriso. the scenarios, each reported as a PASS or FAIL line:
#
#   A. online build: the image is built, keeps the boot setup of the original
#      iso and carries the sca layer with sca and the offline packages.
#   B. offline rebuild from the cache: with the ubuntu release servers
#      unreachable, the cached iso and SHA256SUMS pair are used. the apt archive
#      is still needed for the offline packages, so this is not a no-network
#      build.
#   C. tampered local iso: a file under the iso name that does not match the
#      signed SHA256SUMS stops the build before anything is mounted.
#   D. the manual gpgv / sha256sum check of docs/air-gapped-operations.md
#      passes on the cached files.
#
# runs inside a privileged ubuntu container started by tests/integration/run.sh
# ('make integration'), as root. it installs packages, creates the user sca and
# edits /etc/hosts, so it refuses to run outside a container.
#
# needs: --privileged (loop mounts), network (releases.ubuntu.com and the ubuntu
# apt archive), ~15 GB of disk, the sca source tree at /src (read-only), the
# downloads cache volume at /home/sca/.sca/downloads and UBUNTU_VERSION_ID.

if [ ! -f /.dockerenv ] || [ "$(id -u)" != 0 ]; then
  echo "error: run this through tests/integration/run.sh ('make integration'), not directly" >&2
  exit 2
fi

src=/src
user=sca
home="/home/${user}"
sca_home="${home}/.sca/"
downloads="${sca_home}downloads/"
version_id="${UBUNTU_VERSION_ID:?UBUNTU_VERSION_ID is not set}"
version="${version_id%%-*}"
sums="${downloads}ubuntu-${version}-SHA256SUMS"
release_hosts="releases.ubuntu.com old-releases.ubuntu.com"
failures=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# check DESCRIPTION COMMAND... - PASS if the command succeeds, FAIL otherwise
check() {
  local description=$1; shift
  if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# contains TEXT PATTERN - the text contains the glob pattern
contains() { [[ "$1" == *$2* ]]; }
lacks() { ! contains "$@"; }
step() { echo; echo "=== $*"; }

# run a command as the user sca, with its HOME (env rather than sudo -H, which
# not every sudo implementation has)
as_sca() { sudo -u "${user}" -- env HOME="${home}" "$@"; }

# the image a build makes from the cached iso, and its options file
sca_images() { find "${downloads}" -maxdepth 1 -name '*.sca*.iso*' "$@"; }

# leave no mount or loop device behind: in a privileged container they belong
# to the host, so a failed run would leak them on the runner
cleanup() {
  local mount_point loop
  awk -v h="${home}/" 'index($2, h) == 1 { print $2 }' /proc/mounts | sort -r | \
    while read -r mount_point; do
      [ "${mount_point%/}" = "${downloads%/}" ] && continue
      umount "${mount_point}" 2> /dev/null || umount -l "${mount_point}"
    done
  for loop in $(losetup -nO NAME,BACK-FILE 2> /dev/null | awk -v h="${home}/" 'index($2, h) == 1 { print $1 }'); do
    losetup -d "${loop}"
  done
}
trap cleanup EXIT

# block_release_servers / unblock_release_servers - make the ubuntu release
# servers unreachable, or reachable again. /etc/hosts is bind mounted by docker,
# so it is edited in place.
block_release_servers() {
  printf '127.0.0.1 %s # sca-integration\n::1 %s # sca-integration\n' \
    "${release_hosts}" "${release_hosts}" >> /etc/hosts
}
unblock_release_servers() {
  local hosts
  hosts="$(grep -v '# sca-integration$' /etc/hosts)"
  echo "${hosts}" > /etc/hosts
}

# no_iso_mounted MESSAGE - nothing is mounted as iso9660
no_iso_mounted() {
  if awk '$3 == "iso9660"' /proc/mounts | grep -q .; then
    fail "$1: an iso9660 file system is mounted: $(awk '$3 == "iso9660"' /proc/mounts)"
  else
    pass "$1: nothing is mounted"
  fi
}

# boot_entries ISO - the el torito boot images of an iso, without their LBA,
# which xorriso may move
boot_entries() {
  xorriso -indev "$1" -report_el_torito plain 2> /dev/null | \
    awk '/^El Torito boot img/ { $NF = ""; print } /^El Torito img path/'
}

################################################################################
step "preparing the container as a user would"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || exit 1
apt-get install -y -qq --no-install-recommends sudo make ca-certificates wget gpg gpgv > /dev/null || exit 1
if ! grep -qs '^Components:.*universe' /etc/apt/sources.list.d/ubuntu.sources; then
  echo "error: the apt sources of this image do not include universe, which the offline packages need" >&2
  exit 1
fi
id "${user}" > /dev/null 2>&1 || useradd -m -s /bin/bash "${user}" 2> /dev/null
echo "${user} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${user}"
chmod 440 "/etc/sudoers.d/${user}"
mkdir -p "${downloads}"
chown -R "${user}:${user}" "${home}"
as_sca cp -r "${src}" "${home}/src"
as_sca make -s -C "${home}/src" sca > /dev/null || exit 1
# sca install copies sca to ~/bin, writes ~/bin/sca_completion and the config,
# and installs the iso image tools
as_sca "${home}/src/build/sca.sh" install > /dev/null || exit 1
sca="${home}/bin/sca"

################################################################################
step "downloads cache"
iso_name=""
[ -f "${sums}" ] && iso_name="$(as_sca bash -c ". '${sca}'; get_latest_ubuntu_iso_filename '${version}' '${sums}'")"
if [ -n "${iso_name}" ] && [ -f "${downloads}${iso_name}" ]; then
  echo "${iso_name} is cached: this run downloads only SHA256SUMS and the apt packages (tens of MB),"
  echo "or the iso again (~6 GB) if a newer ubuntu ${version} point release was published."
else
  echo "the ubuntu ${version} iso is not cached: this run downloads it, ~6 GB, plus the apt packages."
fi
ls -l "${downloads}"

################################################################################
step "A. online build"
# a cached image would be reused and reported as 'already exists', without
# building anything
sca_images -delete
if as_sca "${sca}" init sca_usb_stick; then
  pass "A: sca init sca_usb_stick exited 0"
else
  fail "A: sca init sca_usb_stick failed"
fi
iso_name="$(as_sca bash -c ". '${sca}'; get_latest_ubuntu_iso_filename '${version}' '${sums}'")"
original="${downloads}${iso_name}"
image="${original%.iso}.sca.iso"
if [ -z "${iso_name}" ] || [ ! -f "${image}" ] || [ ! -f "${image}.options" ]; then
  fail "A: no image ${image} with its options file. stopping."
  exit 1
fi
pass "A: ${image} and its options file exist"

original_boot="$(boot_entries "${original}")"
if [ -n "${original_boot}" ] && [ "${original_boot}" = "$(boot_entries "${image}")" ]; then
  pass "A: same el torito boot images as the original iso"
else
  fail "A: el torito boot images differ. original: ${original_boot} image: $(boot_entries "${image}")"
fi

layer="$(xorriso -indev "${image}" -find /casper -name '*.sca.squashfs' 2> /dev/null | tr -d "'")"
if [ -n "${layer}" ]; then
  pass "A: sca layer ${layer} in the image"
  extracted="$(mktemp -d)"
  xorriso -osirrox on -indev "${image}" -extract "${layer}" "${extracted}/layer.squashfs" \
    -extract /boot/grub/grub.cfg "${extracted}/grub.cfg" > /dev/null 2>&1
  listing="$(unsquashfs -l "${extracted}/layer.squashfs" 2> /dev/null)"
  check "A: the sca layer has opt/sca/bin/sca" grep -q '/opt/sca/bin/sca$' <<< "${listing}"
  debs="$(grep -c '/opt/sca/packages/.*\.deb$' <<< "${listing}")"
  check "A: the sca layer has offline packages in opt/sca/packages/ (${debs})" [ "${debs}" -gt 0 ]
  check "A: grub.cfg boots the sca layer" grep -q "layerfs-path=${layer##*/}" "${extracted}/grub.cfg"
  rm -rf "${extracted}"
else
  fail "A: no /casper/*.sca.squashfs in the image"
fi
no_iso_mounted "A"

################################################################################
step "B. offline rebuild from the cache (release servers unreachable, apt archive still used)"
sca_images -delete
block_release_servers
output="$(as_sca "${sca}" init sca_usb_stick 2>&1)"
status=$?
unblock_release_servers
echo "${output}" | tail -n 5
[ ${status} = 0 ] || echo "${output}"
check "B: sca init sca_usb_stick exited 0" [ ${status} = 0 ]
check "B: the cached SHA256SUMS was used ('using the previously downloaded')" \
  contains "${output}" "using the previously downloaded"
check "B: the iso was not downloaded again" lacks "${output}" "downloading https://"
check "B: ${image} was built" [ -f "${image}" ]
no_iso_mounted "B"

################################################################################
step "C. tampered local iso (a separate downloads folder, release servers unreachable)"
tamper_home="${home}/tampered"
original_stat="$(stat -c '%s %Y' "${original}")"
as_sca mkdir -p "${tamper_home}/.sca/downloads"
as_sca env HOME="${tamper_home}" "${sca}" config create all > /dev/null 2>&1
as_sca cp "${sums}" "${sums}.gpg" "${tamper_home}/.sca/downloads/"
as_sca bash -c "echo 'not the ubuntu iso' > '${tamper_home}/.sca/downloads/${iso_name}'"
block_release_servers
output="$(as_sca env HOME="${tamper_home}" "${sca}" init sca_usb_stick 2>&1)"
status=$?
unblock_release_servers
echo "${output}" | tail -n 3
check "C: sca init sca_usb_stick failed" [ ${status} != 0 ]
check "C: it says the local image does not match the signed SHA256SUMS" \
  contains "${output}" "the local image*does not match the signed SHA256SUMS"
check "C: no ~/.sca/iso_image mount folder was made" [ ! -e "${tamper_home}/.sca/iso_image" ]
no_iso_mounted "C"
check "C: the cached iso is untouched" [ "${original_stat}" = "$(stat -c '%s %Y' "${original}")" ]
rm -rf "${tamper_home}"

################################################################################
step "D. the manual check of docs/air-gapped-operations.md"
manual="$(mktemp -d)"
ln -s "${sums}" "${sums}.gpg" "${original}" "${manual}/"
cp "${src}/src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc" "${manual}/"
output="$(cd "${manual}" && \
  gpg --dearmor < ubuntu-cdimage-keyring.asc > ubuntu-cdimage-keyring.gpg && \
  gpgv --keyring ./ubuntu-cdimage-keyring.gpg "ubuntu-${version}-SHA256SUMS.gpg" "ubuntu-${version}-SHA256SUMS" 2>&1)"
echo "${output}"
check "D: gpgv: Good signature" contains "${output}" "Good signature"
check "D: gpgv: by the pinned key" contains "${output}" "843938DF228D22F7B3742BC0D94AA3F0EFE21092"
output="$(cd "${manual}" && sha256sum -c --ignore-missing "ubuntu-${version}-SHA256SUMS" 2>&1)"
echo "${output}"
check "D: sha256sum: ${iso_name}: OK" contains "${output}" "${iso_name}: OK"
rm -rf "${manual}"

################################################################################
step "result"
sca_images -delete
du -sh "${downloads}"
if [ ${failures} -gt 0 ]; then
  echo "${failures} check(s) failed"
  exit 1
fi
echo "all checks passed"
