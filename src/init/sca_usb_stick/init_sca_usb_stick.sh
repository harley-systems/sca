################################################################################
# initialize the usb stick for booting offline secure environment
# by performing the following tasks
#
# - download live usb image
# - download ubuntu packages for offline installation
# - add a filesystem layer with the offline installations and sca to the live
#   usb image
# - create usb stick from live usb image
#
# parameters
#   ubuntu_version_id
#
# the ubuntu desktop iso boots with grub (bios and uefi) and its live root file
# system is a chain of squashfs layers, for example
#
#   minimal.squashfs <- minimal.standard.squashfs <- minimal.standard.live.squashfs
#
# the original iso image is not repacked. instead, the following files are added
# or replaced in a copy of it:
#
# /casper/<live layer>.sca.squashfs - a new layer on top of the live layer:
#     - /etc/apt/              - configuring apt to use local apt-mirror (only
#                                with --include-apt-mirror)
#     - /etc/bash_completion.d/- adding sca completion, generated from ~/bin/sca
#     - /etc/ssl/              - adding sca configuration related files
#     - /etc/profile.d/sca.sh  - installs sca on login, adds ~/bin/ to path,
#                                runs sca test on start as needed
#     - /opt/sca               - apt-mirror, packages, sca
# /boot/grub/grub.cfg          - boots directly into the live session with the
# /boot/grub/loopback.cfg        sca layer
# /md5sum.txt                  - checksums of the changed files
#
# the boot setup (el torito, mbr, efi partition) of the original image is
# replayed by xorriso unchanged.
#
# that is the image for --board pc, the default. for an arm board, such as
# --board rock64, the image is the armbian disk image of the board instead, see
# build_armbian_image. it gets the same /opt/sca, /etc/profile.d/sca.sh and
# packages, built for the board's architecture, copied into its root file
# system.

init_sca_usb_stick() {
  local skip_cleanup=false
  local test_image=false
  local include_apt_mirror=false
  local yubikey_support=false
  local exclude_pkcs11_support=false
  local no_cache_iso=false
  local board=pc

  local OPTS=`getopt -o hstiyxonb: --long help,skip-cleanup,test-image,include-apt-mirror,yubikey-support,exclude-pkcs11-support,no-cache-iso,no-cache,board: -n "init sca_usb_stick" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca init sca_usb_stick -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        sca_usb_stick_help
        return
        ;;
      -s | --skip-cleanup )
        skip_cleanup=true
        shift
        ;;
      -t | --test-image )
        test_image=true
        shift
        ;;
      -i | --include-apt-mirror )
        include_apt_mirror=true
        shift
        ;;
      -y | --yubikey-support )
        yubikey_support=true
        shift
        ;;
      -x | --exclude-pkcs11-support )
        exclude_pkcs11_support=true
        shift
        ;;
      -o | --no-cache-iso | -n | --no-cache )
        no_cache_iso=true
        shift
        ;;
      -b | --board )
        board=$2
        shift 2
        ;;
      -- )
        shift
        break
        ;;
      * )
        break
        ;;
    esac
  done

  # use ubuntu version id specified below for the offline environment on sca usb
  # stick
  local ubuntu_version_id=${1:-$sca_ubuntu_version_id}
  check_sca_usb_stick_board "$board" $test_image $include_apt_mirror
  check_ubuntu_version_id "$ubuntu_version_id" "init sca_usb_stick"
  check_build_host_ubuntu_version "init sca_usb_stick"
  check_iso_image_tools $include_apt_mirror $board
  check_sca_to_ship

  log_detailed "init_sca_usb_stick: start (skip_cleanup=${skip_cleanup}, test_image=${test_image}, "\
    "yubikey_support=${yubikey_support}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
    "include_apt_mirror=${include_apt_mirror}, ubuntu_version_id=${ubuntu_version_id}, board=${board})"
  # extract the version number as all text preceeding the first - character
  local ubuntu_version_number=${ubuntu_version_id%%-*}
  # extract the version name as all text following the first - character
  local ubuntu_version_name=${ubuntu_version_id#*-}
  # NOTE: this method shall be called only in online environment.
  # the sca home folder for this (online) sca. it is not necessarily the same in
  # the offline environment.
  local sca_home_folder=~/.sca/
  #
  local test_folder_relative=test/
  # for test image, we hereby define where to mount the test results drive and
  # output the test results
  local test_folder=${sca_home_folder}${test_folder_relative}
  # the sca home folder relative to live_filesystem_folder
  local sca_home_relative=opt/sca/
  # the relative folder name in which to keep downloaded packages for installation
  # in offline environment
  local packages_folder_relative=packages/
  # repos folder relative to live_filesystem_sca_home_folder
  local repos_relative=apt-mirror/
  # the folder to use for iso image download
  local downloads_folder=${sca_home_folder}downloads/
  # the folder in which the originally downloaded iso image is mounted
  local iso_image_mount_folder=${sca_home_folder}iso_image/
  # the folder in which we keep the files to add to or replace in the original
  # iso image
  local iso_image_sca_folder=${sca_home_folder}iso_image_sca/
  # the folder holding the content of the sca filesystem layer
  local live_filesystem_folder=${sca_home_folder}live_filesystem/
  # the dpkg status file of the original live filesystem, used to resolve which
  # packages the offline environment is missing
  local live_dpkg_status_file=${iso_image_sca_folder}dpkg-status
  # the sca home folder in live filesystem while preparing for offline
  local live_filesystem_sca_home_folder=${live_filesystem_folder}${sca_home_relative}
  # packages folder - the location in which to keep downloaded packages for installation
  # in either online or offline environment
  local live_filesystem_packages_folder=${live_filesystem_sca_home_folder}${packages_folder_relative}
  # the folder within the live_filesystem_folder in which to keep the offline repositories
  local live_filesystem_repos_folder=${live_filesystem_sca_home_folder}${repos_relative}
  # the sca home folder fullpath when running offline booted from the live usb
  local offline_sca_home_folder=/${sca_home_relative}
  # repos folder fullpath when running offline booted from the live usb
  local offline_repos_folder=${offline_sca_home_folder}${repos_relative}

  if [ $board != pc ]; then
    build_armbian_image \
      $board \
      $ubuntu_version_name \
      $downloads_folder \
      ${sca_home_folder}armbian_image/ \
      $iso_image_sca_folder \
      $live_filesystem_folder \
      $live_filesystem_repos_folder \
      $live_filesystem_sca_home_folder \
      $offline_repos_folder \
      $live_filesystem_packages_folder \
      $test_folder_relative \
      $yubikey_support \
      $exclude_pkcs11_support \
      $skip_cleanup \
      $no_cache_iso
    log_detailed "init_sca_usb_stick: finish (skip_cleanup=${skip_cleanup}, "\
      "yubikey_support=${yubikey_support}, "\
      "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
      "ubuntu_version_id=${ubuntu_version_id}, board=${board})"
    return
  fi

  local original_iso_image
  original_iso_image=$(download_ubuntu_image ${ubuntu_version_number} ${downloads_folder}) || exit 1

  local test_suffix=''
  [ $test_image = true ] && test_suffix='-test'
  local new_iso_image_file=${original_iso_image%.iso}.sca${test_suffix}.iso
  local new_iso_options_file=$(get_sca_iso_options_file ${new_iso_image_file})
  local requested_options=$(get_sca_iso_options ${yubikey_support} ${include_apt_mirror} ${exclude_pkcs11_support})
  log_detailed "init_sca_usb_stick: new_iso_image_file ${new_iso_image_file}"
  # a test image must carry the sca being tested, so never reuse an old one
  if [ $test_image = true ] && [ -f ${new_iso_image_file} ]; then
    log_detailed "init_sca_usb_stick: removing the existing test image ${new_iso_image_file}"
    sudo rm -f ${new_iso_image_file} ${new_iso_options_file}
  fi
  if reuse_sca_image ${new_iso_image_file} "${requested_options}" "iso image" pc; then
    log_detailed "init_sca_usb_stick: finish (skip_cleanup=${skip_cleanup}, test_image=${test_image}, "\
      "yubikey_support=${yubikey_support}, "\
      "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
      "include_apt_mirror=${include_apt_mirror}, ubuntu_version_id=${ubuntu_version_id})"
    return
  fi

  local live_layer_file_name
  live_layer_file_name=$(extract_iso_image_files \
    $original_iso_image \
    $iso_image_mount_folder \
    $iso_image_sca_folder \
    $live_dpkg_status_file) || exit 1
  patch_live_filesystem \
    $live_filesystem_folder \
    $live_filesystem_repos_folder \
    $live_filesystem_sca_home_folder \
    $offline_repos_folder \
    $live_filesystem_packages_folder \
    $test_image \
    $test_folder_relative \
    $ubuntu_version_name \
    $include_apt_mirror \
    $yubikey_support \
    $exclude_pkcs11_support \
    $live_dpkg_status_file
  # an options file left from an earlier image must not vouch for this one
  rm -f ${new_iso_options_file}
  create_live_iso \
    $live_filesystem_folder \
    $live_layer_file_name \
    $original_iso_image \
    $iso_image_sca_folder \
    $new_iso_image_file
  [ -f ${new_iso_image_file} ] && echo "${requested_options}" > ${new_iso_options_file}
  [ $skip_cleanup != true ] && clean_up_live_usb_intermediary_files \
    $live_filesystem_folder \
    $iso_image_sca_folder \
    $original_iso_image \
    $no_cache_iso
  log_detailed "init_sca_usb_stick: finish (skip_cleanup=${skip_cleanup}, test_image=${test_image}, "\
    "yubikey_support=${yubikey_support}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
    "include_apt_mirror=${include_apt_mirror}, ubuntu_version_id=${ubuntu_version_id})"
}
sca_usb_stick_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
################################################################################
# returns the file next to the sca iso image recording the options it was built
# with, so a cached image is reused only for a run asking for the same options
get_sca_iso_options_file() {
  local sca_iso_image_file=$1

  echo ${sca_iso_image_file}.options
}
################################################################################
# prints the build options that change the content of the sca iso image, one
# per line, in the form kept in the options file
get_sca_iso_options() {
  local yubikey_support=$1
  local include_apt_mirror=$2
  local exclude_pkcs11_support=$3

  echo "yubikey_support=${yubikey_support}"
  echo "include_apt_mirror=${include_apt_mirror}"
  echo "exclude_pkcs11_support=${exclude_pkcs11_support}"
}
################################################################################
# reuses a sca image built by an earlier run. succeeds, printing the write
# instructions, when the image exists and its options file records the
# requested options. fails when there is no image to reuse. stops with an error
# when the image exists but is not known to be built with the requested options.
#
# parameters
#   sca_image_file    - the sca image
#   requested_options - the options asked for, as printed by get_sca_iso_options
#   image_kind        - what to call the image in the messages, e.g. iso image
#   board             - the board the image is for
reuse_sca_image() {
  local sca_image_file=$1
  local requested_options=$2
  local image_kind=$3
  local board=$4

  [ -f ${sca_image_file} ] || return 1
  local options_file=$(get_sca_iso_options_file ${sca_image_file})
  # reuse the image only if it is known to be built with the requested options
  if ! [ -f ${options_file} ] || \
    [ "$(cat ${options_file})" != "${requested_options}" ]; then
    local cached_options="unknown - no ${options_file}"
    [ -f ${options_file} ] && cached_options=$(paste -sd " " ${options_file})
    >&2 echo "the ${image_kind} ${sca_image_file} was not built with the requested options."
    >&2 echo "  built with: ${cached_options}"
    >&2 echo "  requested:  ${requested_options//$'\n'/ }"
    error "remove it to build a new one: rm -f ${sca_image_file} ${options_file}" 1
  fi
  echo "the ${image_kind} $sca_image_file already exists. please use that one, or remove it to create another one."
  print_sca_disk_image_help $sca_image_file $board
}
################################################################################
# the boards the sca usb stick image is built for. pc is the ubuntu desktop iso
# image for an x86 pc. each other board is an armbian disk image for that
# board, described by its row in get_sca_usb_stick_board_field.
get_sca_usb_stick_boards() {
  echo "pc rock64"
}
################################################################################
# prints a field of an arm board's row in the board table. adding a board means
# adding its row here and its name to get_sca_usb_stick_boards.
#
#   image_url      - the latest armbian image of the board for an ubuntu
#                    release (a .img.xz). armbian publishes <image_url>.sha,
#                    its sha256, and <image_url>.asc, a detached signature over
#                    the .img.xz (not over the .sha) by the armbian image
#                    signing key, see get_armbian_image_signing_key_fingerprint
#   arch           - the debian architecture of the packages the board needs
#   root_partition - the number of the partition holding the root file system
#   boot_medium    - the medium the board boots the image from as written
#
# parameters
#   board               - the board, for example rock64
#   field               - the field to print
#   ubuntu_version_name - the ubuntu release name, for example resolute
get_sca_usb_stick_board_field() {
  local board=$1
  local field=$2
  local ubuntu_version_name=$3

  case "${board}:${field}" in
    # armbian community builds, signed like armbian's stable ones (#108)
    rock64:image_url ) echo "https://dl.armbian.com/rock64/${ubuntu_version_name^}_current_minimal" ;;
    rock64:arch ) echo "arm64" ;;
    rock64:root_partition ) echo "1" ;;
    # the rk3328 boot rom reads spi, emmc and microsd, never usb (docs/usb-boot-on-arm.md)
    rock64:boot_medium ) echo "microSD card" ;;
  esac
}
################################################################################
# fails unless the board is supported, and supported with the requested options
#
# parameters
#   board               - the --board value
#   test_image          - whether --test-image is set
#   include_apt_mirror  - whether --include-apt-mirror is set
check_sca_usb_stick_board() {
  local board=$1
  local test_image=$2
  local include_apt_mirror=$3

  if [[ " $(get_sca_usb_stick_boards) " != *" ${board} "* ]]; then
    error "init sca_usb_stick: unknown board '${board}'. the supported boards are: $(get_sca_usb_stick_boards)." 1
  fi
  [ "$board" = pc ] && return
  if [ "$test_image" = true ]; then
    error "init sca_usb_stick: --test-image is not supported with --board ${board}. sca test boots the test image in qemu-system-x86_64, which cannot boot a ${board} image. build the ${board} image without --test-image." 1
  fi
  if [ "$include_apt_mirror" = true ]; then
    error "init sca_usb_stick: --include-apt-mirror is not supported with --board ${board}: the ubuntu $(get_sca_usb_stick_board_field ${board} arch) archive does not fit in the root file system of the ${board} image. build it without --include-apt-mirror; the packages sca needs are bundled regardless." 1
  fi
}
################################################################################
# the filesystem label of the test results disk. sca test creates the disk with
# this label and the test image only ever mounts a disk carrying it, so it never
# picks a disk by kernel name (at most 16 characters - the ext4 limit)
get_test_results_disk_label() {
  echo "sca-test-results"
}
################################################################################
# fails unless the tools used for building the sca usb stick image are present
#
# parameters
#   include_apt_mirror - whether apt-mirror is needed as well
#   board              - the board the image is for, pc by default
check_iso_image_tools() {
  local include_apt_mirror=$1
  local board=${2:-pc}

  local tools=(wget gpgv base64 sha256sum md5sum xorriso mksquashfs unsquashfs apt-get)
  # an armbian image is decompressed and its root file system loop mounted
  [ "$board" != pc ] && tools=(wget gpgv base64 sha256sum xz losetup apt-get)
  [ "$include_apt_mirror" = true ] && tools+=(apt-mirror)
  local missing_tools=()
  for tool in "${tools[@]}"; do
    command -v $tool > /dev/null || missing_tools+=($tool)
  done
  if [ ${#missing_tools[@]} != 0 ]; then
    error "init sca_usb_stick: missing tools: ${missing_tools[*]}. run 'sca install' to install them." 1
  fi
}
################################################################################
# fails unless ~/bin/sca, the sca shipped on the sca usb stick, is present. the
# stick's sca completion is generated from it as well.
check_sca_to_ship() {
  if [ ! -f ~/bin/sca ] || [ ! -r ~/bin/sca ]; then
    error "init sca_usb_stick: ~/bin/sca not found: the stick ships the sca installed in ~/bin. run 'make deploy' (default INSTALL_DIR) or 'sca install' first." 1
  fi
}
################################################################################
# downloads the SHA256SUMS file of an ubuntu version and its signature,
# SHA256SUMS.gpg, into the downloads folder, checks the signature and echoes the
# url of the folder they were downloaded from.
#
# the current releases are at https://releases.ubuntu.com/<major>.<minor>/,
# older ones are moved to https://old-releases.ubuntu.com/releases/<major>.<minor>/
# if neither can be reached, the previously downloaded files are used, after
# checking their signature again.
#
# a SHA256SUMS file without a good signature of the ubuntu cd image signing key
# always stops the build, and is removed together with its signature.
#
# parameters
#     version           - the ubuntu version, of form <major>.<minor>
#     downloads_folder  - the folder into which to download the files
#
# example call:
# download_ubuntu_sha256sums '26.04' ~/.sca/downloads/
download_ubuntu_sha256sums() {
  local version=$1
  local downloads_folder=$2

  log_detailed "download_ubuntu_sha256sums: start (version=${version}, downloads_folder=${downloads_folder})"
  local sums_file=$(get_ubuntu_sha256sums_file ${version} ${downloads_folder})
  local signature_file=$(get_ubuntu_sha256sums_signature_file ${version} ${downloads_folder})
  mkdir -p $downloads_folder
  local base_url
  for base_url in "https://releases.ubuntu.com/${version}/" \
      "https://old-releases.ubuntu.com/releases/${version}/"; do
    if wget --quiet -O "${sums_file}.new" "${base_url}SHA256SUMS"; then
      if ! wget --quiet -O "${signature_file}.new" "${base_url}SHA256SUMS.gpg"; then
        rm -f "${sums_file}.new" "${signature_file}.new"
        error "could not download ${base_url}SHA256SUMS.gpg, the signature of SHA256SUMS. an unsigned SHA256SUMS is never used." 1
      fi
      check_ubuntu_sha256sums_signature "${sums_file}.new" "${signature_file}.new" || exit 1
      if [ -n "$(get_latest_ubuntu_iso_filename ${version} "${sums_file}.new")" ]; then
        mv "${sums_file}.new" "${sums_file}"
        mv "${signature_file}.new" "${signature_file}"
        log_detailed "download_ubuntu_sha256sums: finish (base_url=${base_url})"
        echo "$base_url"
        return
      fi
    fi
    log_detailed "download_ubuntu_sha256sums: no ubuntu ${version} desktop image listed at ${base_url}"
  done
  rm -f "${sums_file}.new" "${signature_file}.new"
  if [ -f "${sums_file}" ]; then
    >&2 echo "could not download the ubuntu ${version} SHA256SUMS file. using the previously downloaded ${sums_file}."
    if [ ! -f "${signature_file}" ]; then
      rm -f "${sums_file}"
      error "the previously downloaded ${sums_file} has no signature file ${signature_file}. it was removed. connect to the internet to download it again." 1
    fi
    check_ubuntu_sha256sums_signature "${sums_file}" "${signature_file}" || exit 1
    echo "https://releases.ubuntu.com/${version}/"
    return
  fi
  error "could not download the ubuntu ${version} SHA256SUMS file from releases.ubuntu.com or old-releases.ubuntu.com." 1
}
get_ubuntu_sha256sums_file() {
  local version=$1
  local downloads_folder=$2

  echo "${downloads_folder}ubuntu-${version}-SHA256SUMS"
}
get_ubuntu_sha256sums_signature_file() {
  local version=$1
  local downloads_folder=$2

  echo "$(get_ubuntu_sha256sums_file ${version} ${downloads_folder}).gpg"
}
################################################################################
# the fingerprint of the Ubuntu CD Image Automatic Signing Key, which signs the
# SHA256SUMS files of the ubuntu releases. a SHA256SUMS file is trusted only
# when signed by this key.
get_ubuntu_cdimage_signing_key_fingerprint() {
  echo "843938DF228D22F7B3742BC0D94AA3F0EFE21092"
}
################################################################################
# prints the bundled, ascii armored, public key of the ubuntu cd image signing
# key. the build embeds src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc here,
# so the key is never fetched from a keyserver. docs/air-gapped-operations.md
# tells how to update it.
get_ubuntu_cdimage_keyring() {
  cat <<'UBUNTU_CDIMAGE_KEYRING'
@@@UBUNTU CDIMAGE KEYRING@@@
UBUNTU_CDIMAGE_KEYRING
}
################################################################################
# checks a detached signature with gpgv against a bundled keyring only, never
# the user's, and prints the gpgv status lines. the caller decides from them:
# a VALIDSIG line ends with the fingerprint of the signing primary key.
#
# parameters
#   keyring_function  - the function printing the ascii armored keyring
#   signature_file    - the detached signature
#   signed_file       - the file it signs
get_gpgv_status() {
  local keyring_function=$1
  local signature_file=$2
  local signed_file=$3

  local keyring_file
  keyring_file=$(mktemp "${TMPDIR:-/tmp}/sca-keyring.XXXXXX") || \
    error "could not create a temporary file for the keyring of ${keyring_function}." 1
  # strip the armor: the header up to the empty line, the checksum and the footer
  ${keyring_function} | \
    sed -e '1,/^$/d' -e '/^=/d' -e '/^-----END/d' | base64 -d > "${keyring_file}"
  gpgv --status-fd 1 --keyring "${keyring_file}" "${signature_file}" "${signed_file}" 2> /dev/null
  rm -f "${keyring_file}"
}
################################################################################
# checks with gpgv that a SHA256SUMS file carries a good signature of the ubuntu
# cd image signing key, pinned by its fingerprint. otherwise removes the
# SHA256SUMS file and its signature and stops with an error telling why:
#
# - the SHA256SUMS file does not match the signature (it was modified)
# - the signature is made by a key other than the pinned one
# - the signature could not be checked (corrupt, or by an unknown key)
#
# parameters
#     sums_file       - the SHA256SUMS file
#     signature_file  - its detached signature, SHA256SUMS.gpg
check_ubuntu_sha256sums_signature() {
  local sums_file=$1
  local signature_file=$2

  log_detailed "check_ubuntu_sha256sums_signature: start (sums_file=${sums_file}, signature_file=${signature_file})"
  local fingerprint=$(get_ubuntu_cdimage_signing_key_fingerprint)
  local status
  status=$(get_gpgv_status get_ubuntu_cdimage_keyring "${signature_file}" "${sums_file}") || exit 1
  log_detailed "check_ubuntu_sha256sums_signature: gpgv status: ${status}"
  # VALIDSIG <key fingerprint> ... <primary key fingerprint>
  local signers=$(echo "${status}" | awk '$2 == "VALIDSIG" { print $NF }')
  if echo "${status}" | grep -q '^\[GNUPG:\] BADSIG '; then
    rm -f "${sums_file}" "${signature_file}"
    error "${sums_file} does not match its signature: it was modified. it was removed with its signature." 1
  elif echo "${signers}" | grep -qx "${fingerprint}"; then
    log_detailed "check_ubuntu_sha256sums_signature: finish (signed by ${fingerprint})"
    return
  elif [ -n "${signers}" ]; then
    rm -f "${sums_file}" "${signature_file}"
    error "${sums_file} is signed by ${signers//$'\n'/ }, not by the ubuntu cd image signing key ${fingerprint}. it was removed with its signature." 1
  fi
  rm -f "${sums_file}" "${signature_file}"
  error "the signature ${signature_file} could not be checked with the ubuntu cd image signing key ${fingerprint}. ${sums_file} was removed with its signature." 1
}
################################################################################
# echoes the file name of the latest point release desktop iso image listed in
# a SHA256SUMS file, for example ubuntu-26.04.1-desktop-amd64.iso
#
# parameters
#     version   - the ubuntu version, of form <major>.<minor>
#     sums_file - the SHA256SUMS file
get_latest_ubuntu_iso_filename() {
  local version=$1
  local sums_file=$2

  local iso_regex="^ubuntu-${version//./\\.}(\\.([0-9]+))?-desktop-amd64\\.iso$"
  local latest_file=""
  local latest_fix=-1
  local file fix
  while read -r _ file; do
    file=${file#\*}
    if [[ $file =~ $iso_regex ]]; then
      fix=${BASH_REMATCH[2]:-0}
      if [ $fix -gt $latest_fix ]; then
        latest_fix=$fix
        latest_file=$file
      fi
    fi
  done < "$sums_file"
  echo "$latest_file"
}
################################################################################
# downloads the latest point release of the ubuntu desktop iso image, checks it
# against the signed SHA256SUMS and echoes the downloaded image file name.
#
# an image already in the downloads folder, downloaded by an earlier run or put
# there by the user, is used only when it matches too. otherwise the build stops
# and the image is left for the user to remove: sca moves a download into place
# only after checking it, so a mismatch means the file changed afterwards.
#
# parameters
#     version           - the version of ubuntu to download iso file for. needs
#                         to be of form <major>.<minor>, for example 26.04
#     downloads_folder  - the folder into which to download the iso file
#
# example call:
# download_ubuntu_image '26.04' ~/.sca/downloads/
download_ubuntu_image() {
  local version=$1
  local downloads_folder=$2

  log_detailed "download_ubuntu_image: start (version=${version}, downloads_folder=${downloads_folder})"
  local base_url
  base_url=$(download_ubuntu_sha256sums ${version} ${downloads_folder}) || exit 1
  local sums_file=$(get_ubuntu_sha256sums_file ${version} ${downloads_folder})
  local file=$(get_latest_ubuntu_iso_filename ${version} ${sums_file})
  local downloaded_file=${downloads_folder}$file
  local expected_sum=$(grep -E " \*?${file//./\\.}$" ${sums_file} | cut -d ' ' -f 1)
  if [ -f $downloaded_file ]; then
    log_detailed "download_ubuntu_image: local image found. checking it."
    if [ "$(sha256sum $downloaded_file | cut -d ' ' -f 1)" = "$expected_sum" ]; then
      echo $downloaded_file
      log_detailed "download_ubuntu_image: finish (version=${version}, downloads_folder=${downloads_folder})"
      return
    fi
    error "the local image $downloaded_file does not match the signed SHA256SUMS. it is not used. remove it to download it again: rm -f $downloaded_file" 1
  fi
  >&2 echo "downloading ${base_url}${file}. this may take a while..."
  if ! wget --append-output ${log_file} -O ${downloaded_file}.part ${base_url}${file}; then
    rm -f ${downloaded_file}.part
    error "failed downloading ${base_url}${file}." 1
  fi
  if [ "$(sha256sum ${downloaded_file}.part | cut -d ' ' -f 1)" != "$expected_sum" ]; then
    rm -f ${downloaded_file}.part
    error "the downloaded ${file} does not match the signed SHA256SUMS. the image was removed." 1
  fi
  mv ${downloaded_file}.part ${downloaded_file}
  echo $downloaded_file
  log_detailed "download_ubuntu_image: finish (version=${version}, downloads_folder=${downloads_folder})"
}
################################################################################
# the fingerprint of the armbian image signing key, "Igor Pecovnik
# <igor@armbian.com>", which signs the armbian images. an armbian image is
# trusted only when signed by this key.
get_armbian_image_signing_key_fingerprint() {
  echo "DF00FAF1C577104B50BF1D0093D6889F9F0E78D5"
}
################################################################################
# prints the bundled, ascii armored, public key of the armbian image signing
# key. the build embeds src/init/sca_usb_stick/armbian-keyring.asc here, so the
# key is never fetched from a keyserver.
get_armbian_image_keyring() {
  cat <<'ARMBIAN_IMAGE_KEYRING'
@@@ARMBIAN IMAGE KEYRING@@@
ARMBIAN_IMAGE_KEYRING
}
################################################################################
# checks with gpgv that an armbian image carries a good signature of the armbian
# image signing key, pinned by its fingerprint. the signature is over the
# .img.xz itself. otherwise removes the signature, and the image if asked to,
# and stops with an error telling why.
#
# parameters
#     image_file      - the .img.xz image
#     signature_file  - its detached signature, <image>.asc
#     remove_image    - true to remove the image as well when the check fails
check_armbian_image_signature() {
  local image_file=$1
  local signature_file=$2
  local remove_image=$3

  log_detailed "check_armbian_image_signature: start (image_file=${image_file}, signature_file=${signature_file})"
  local fingerprint=$(get_armbian_image_signing_key_fingerprint)
  local status
  status=$(get_gpgv_status get_armbian_image_keyring "${signature_file}" "${image_file}") || exit 1
  log_detailed "check_armbian_image_signature: gpgv status: ${status}"
  # VALIDSIG <key fingerprint> ... <primary key fingerprint>
  local signers=$(echo "${status}" | awk '$2 == "VALIDSIG" { print $NF }')
  if echo "${signers}" | grep -qx "${fingerprint}" && \
      ! echo "${status}" | grep -q '^\[GNUPG:\] BADSIG '; then
    log_detailed "check_armbian_image_signature: finish (signed by ${fingerprint})"
    return
  fi
  local removed="its signature was removed"
  rm -f "${signature_file}"
  if [ "${remove_image}" = true ]; then
    rm -f "${image_file}"
    removed="it was removed with its signature"
  fi
  if echo "${status}" | grep -q '^\[GNUPG:\] BADSIG '; then
    error "${image_file} does not match its signature ${signature_file}: it was modified. ${removed}." 1
  elif [ -n "${signers}" ]; then
    error "${image_file} is signed by ${signers//$'\n'/ }, not by the armbian image signing key ${fingerprint}. ${removed}." 1
  fi
  error "the signature ${signature_file} could not be checked with the armbian image signing key ${fingerprint}. ${removed}." 1
}
################################################################################
# succeeds when a .sha file published by armbian is one line of the form
# "<sha256> <image file name>", naming an armbian .img.xz image of the ubuntu
# release. the file name comes from the network, so it may hold no path.
#
# parameters
#     sha_file            - the .sha file
#     ubuntu_version_name - the ubuntu release name, for example resolute
is_armbian_image_sha_file() {
  local sha_file=$1
  local ubuntu_version_name=$2

  [ "$(grep -c '' "${sha_file}")" = 1 ] && \
    grep -qE "^[0-9a-f]{64} \*?Armbian[A-Za-z0-9._-]*_${ubuntu_version_name}_[A-Za-z0-9._-]*\.img\.xz$" "${sha_file}"
}
################################################################################
# downloads the latest armbian image of a board, checks it against both its
# published sha256 (.sha) and its detached signature (.asc) and echoes the
# downloaded image file name, for example
# ~/.sca/downloads/Armbian_community_26.11.0-trunk.108_Rock64_resolute_current_6.18.57_minimal.img.xz
#
# the .sha names the image, so it is kept as
# armbian-<board>-<ubuntu release>.sha. if it cannot be downloaded, the one
# kept by an earlier run is used, with the image and signature it names.
#
# a missing or bad signature, or a sha256 that does not match, always stops
# the build. a downloaded image that fails a check is removed. an image already
# in the downloads folder that fails one is left for the user to remove, as
# download_ubuntu_image does.
#
# parameters
#     board               - the board, for example rock64
#     ubuntu_version_name - the ubuntu release name, for example resolute
#     downloads_folder    - the folder into which to download the image
#
# example call:
# download_armbian_image rock64 resolute ~/.sca/downloads/
download_armbian_image() {
  local board=$1
  local ubuntu_version_name=$2
  local downloads_folder=$3

  log_detailed "download_armbian_image: start (board=${board}, ubuntu_version_name=${ubuntu_version_name}, downloads_folder=${downloads_folder})"
  local image_url=$(get_sca_usb_stick_board_field ${board} image_url ${ubuntu_version_name})
  local sha_file=${downloads_folder}armbian-${board}-${ubuntu_version_name}.sha
  mkdir -p ${downloads_folder}
  if wget --quiet -O "${sha_file}.new" "${image_url}.sha" && \
      is_armbian_image_sha_file "${sha_file}.new" ${ubuntu_version_name}; then
    mv "${sha_file}.new" "${sha_file}"
  else
    rm -f "${sha_file}.new"
    if ! [ -f "${sha_file}" ]; then
      error "could not download ${image_url}.sha, the sha256 of the latest ${board} image, or it does not name an armbian ${ubuntu_version_name} image." 1
    fi
    >&2 echo "could not download ${image_url}.sha. using the previously downloaded ${sha_file}."
    if ! is_armbian_image_sha_file "${sha_file}" ${ubuntu_version_name}; then
      rm -f "${sha_file}"
      error "the previously downloaded ${sha_file} does not name an armbian ${ubuntu_version_name} image. it was removed." 1
    fi
  fi
  local expected_sum file
  read -r expected_sum file < "${sha_file}"
  file=${file#\*}
  log_detailed "download_armbian_image: latest image ${file}"
  local downloaded_file=${downloads_folder}${file}
  local signature_file=${downloaded_file}.asc
  if ! [ -f "${signature_file}" ]; then
    if ! wget --quiet -O "${signature_file}.new" "${image_url}.asc"; then
      rm -f "${signature_file}.new"
      error "could not download ${image_url}.asc, the signature of ${file}. an unsigned image is never used." 1
    fi
    mv "${signature_file}.new" "${signature_file}"
  fi
  if [ -f "${downloaded_file}" ]; then
    log_detailed "download_armbian_image: local image found. checking it."
    if [ "$(sha256sum "${downloaded_file}" | cut -d ' ' -f 1)" != "$expected_sum" ]; then
      error "the local image ${downloaded_file} does not match the sha256 in ${sha_file}. it is not used. remove it to download it again: rm -f ${downloaded_file}" 1
    fi
    check_armbian_image_signature "${downloaded_file}" "${signature_file}" false || exit 1
    echo "${downloaded_file}"
    log_detailed "download_armbian_image: finish (board=${board}, ubuntu_version_name=${ubuntu_version_name}, downloads_folder=${downloads_folder})"
    return
  fi
  >&2 echo "downloading ${image_url} (${file}). this may take a while..."
  if ! wget --append-output ${log_file} -O "${downloaded_file}.part" "${image_url}"; then
    rm -f "${downloaded_file}.part"
    error "failed downloading ${image_url}." 1
  fi
  # a mismatch here is also what a newer image published between the
  # downloads of the .sha and of the image looks like: running again helps then
  if [ "$(sha256sum "${downloaded_file}.part" | cut -d ' ' -f 1)" != "$expected_sum" ]; then
    rm -f "${downloaded_file}.part" "${signature_file}"
    error "the downloaded ${image_url} does not match the sha256 of ${file} in ${image_url}.sha. it was removed with its signature." 1
  fi
  check_armbian_image_signature "${downloaded_file}.part" "${signature_file}" true || exit 1
  mv "${downloaded_file}.part" "${downloaded_file}"
  echo "${downloaded_file}"
  log_detailed "download_armbian_image: finish (board=${board}, ubuntu_version_name=${ubuntu_version_name}, downloads_folder=${downloads_folder})"
}
################################################################################
# builds the sca image for an arm board from the board's armbian image:
#
# - downloads and checks the armbian image, see download_armbian_image
# - decompresses it to <image>.sca.img
# - reads the dpkg status of its root file system
# - stages /opt/sca, /etc/profile.d/sca.sh and the packages for the board's
#   architecture with patch_live_filesystem, as for the pc image, plus the
#   appliance settings, see add_armbian_appliance_settings
# - copies the staged files into the root file system of the image
#
# nothing runs inside the image: sca is installed on the board at first login,
# as on the pc image, so no chroot or qemu-user is needed. the root file system
# is mounted only while reading the dpkg status and while copying, so a failed
# step in between leaves nothing mounted.
#
# parameters
#   board, ubuntu_version_name, downloads_folder, image_mount_folder (where to
#   mount the root file system), image_sca_folder (intermediary files), then
#   the folders and options patch_live_filesystem takes, then skip_cleanup and
#   no_cache_iso
#
# NOTE: this function requires sudo priviledges to attach and mount the image
build_armbian_image() {
  local board=$1
  local ubuntu_version_name=$2
  local downloads_folder=$3
  local image_mount_folder=$4
  local image_sca_folder=$5
  local live_filesystem_folder=$6
  local live_filesystem_repos_folder=$7
  local live_filesystem_sca_home_folder=$8
  local offline_repos_folder=$9
  local live_filesystem_packages_folder=${10}
  local test_folder_relative=${11}
  local yubikey_support=${12}
  local exclude_pkcs11_support=${13}
  local skip_cleanup=${14}
  local no_cache_iso=${15}

  log_detailed "build_armbian_image: start (board=${board}, ubuntu_version_name=${ubuntu_version_name})"
  local original_image
  original_image=$(download_armbian_image ${board} ${ubuntu_version_name} ${downloads_folder}) || exit 1
  local new_image_file=${original_image%.img.xz}.sca.img
  local new_options_file=$(get_sca_iso_options_file ${new_image_file})
  local requested_options=$(get_sca_iso_options ${yubikey_support} false ${exclude_pkcs11_support})
  log_detailed "build_armbian_image: new_image_file ${new_image_file}"
  reuse_sca_image ${new_image_file} "${requested_options}" image ${board} && return
  local root_partition=$(get_sca_usb_stick_board_field ${board} root_partition)
  local live_dpkg_status_file=${image_sca_folder}dpkg-status
  # an options file left from an earlier image must not vouch for this one
  rm -f ${new_options_file}
  >&2 echo "decompressing ${original_image}..."
  if ! xz -dc ${original_image} > ${new_image_file}.part; then
    rm -f ${new_image_file}.part
    error "could not decompress ${original_image}." 1
  fi
  local loop_device
  loop_device=$(attach_armbian_image ${new_image_file}.part ${root_partition} ${image_mount_folder}) || \
    { rm -f ${new_image_file}.part; exit 1; }
  mkdir -p ${image_sca_folder}
  cp ${image_mount_folder}var/lib/dpkg/status ${live_dpkg_status_file}
  local copied=$?
  detach_armbian_image ${image_mount_folder} ${loop_device}
  if [ $copied != 0 ]; then
    rm -f ${new_image_file}.part
    error "could not read the dpkg status of ${original_image}." 1
  fi
  local apt_options=$(get_armbian_apt_options ${board} ${ubuntu_version_name} ${image_sca_folder}apt/)
  # files staged by an earlier run (kept by -s, or left by a failed run) may be
  # for another architecture or the test mode, and must not reach the image
  sudo rm -rf $live_filesystem_folder
  patch_live_filesystem \
    $live_filesystem_folder \
    $live_filesystem_repos_folder \
    $live_filesystem_sca_home_folder \
    $offline_repos_folder \
    $live_filesystem_packages_folder \
    false \
    $test_folder_relative \
    $ubuntu_version_name \
    false \
    $yubikey_support \
    $exclude_pkcs11_support \
    $live_dpkg_status_file \
    "${apt_options}"
  add_armbian_appliance_settings $live_filesystem_folder
  loop_device=$(attach_armbian_image ${new_image_file}.part ${root_partition} ${image_mount_folder}) || \
    { rm -f ${new_image_file}.part; exit 1; }
  copy_into_armbian_image $live_filesystem_folder $image_mount_folder
  copied=$?
  detach_armbian_image ${image_mount_folder} ${loop_device}
  if [ $copied != 0 ]; then
    rm -f ${new_image_file}.part
    error "could not add sca to ${new_image_file}. the image was removed." 1
  fi
  mv ${new_image_file}.part ${new_image_file}
  echo "${requested_options}" > ${new_options_file}
  echo "written: ${new_image_file}"
  print_sca_disk_image_help ${new_image_file} ${board}
  [ $skip_cleanup != true ] && clean_up_live_usb_intermediary_files \
    $live_filesystem_folder \
    $image_sca_folder \
    $original_image \
    $no_cache_iso
  log_detailed "build_armbian_image: finish (board=${board}, ubuntu_version_name=${ubuntu_version_name})"
}
################################################################################
# attaches a disk image to a loop device, mounts the root file system on its
# partition and echoes the loop device. fails, leaving nothing attached or
# mounted, unless the partition holds an armbian root file system.
#
# parameters
#   image_file          - the disk image
#   root_partition      - the number of the root file system partition
#   image_mount_folder  - where to mount it
attach_armbian_image() {
  local image_file=$1
  local root_partition=$2
  local image_mount_folder=$3

  log_detailed "attach_armbian_image: start (image_file=${image_file}, root_partition=${root_partition}, image_mount_folder=${image_mount_folder})"
  local loop_device
  loop_device=$(sudo losetup --find --show --partscan ${image_file})
  if [ $? != 0 ] || [ -z "${loop_device}" ]; then
    error "could not attach ${image_file} to a loop device (sudo losetup failed, see above)." 1
  fi
  local root_device=${loop_device}p${root_partition}
  # the partition device node can show up a moment after losetup returns
  local tries=0
  while ! [ -b ${root_device} ] && [ $tries -lt 20 ]; do
    sleep 0.5
    tries=$((tries+1))
  done
  mkdir -p ${image_mount_folder}
  if ! sudo mount -t ext4 ${root_device} ${image_mount_folder}; then
    sudo losetup -d ${loop_device}
    rmdir ${image_mount_folder} 2> /dev/null
    error "could not mount ${root_device}, partition ${root_partition} of ${image_file}, at ${image_mount_folder} (sudo mount -t ext4 failed, see above)." 1
  fi
  if ! [ -f ${image_mount_folder}etc/armbian-release ] || \
      ! [ -f ${image_mount_folder}var/lib/dpkg/status ]; then
    detach_armbian_image ${image_mount_folder} ${loop_device}
    error "$(basename ${image_file}) does not have the expected layout: an armbian root file system, with etc/armbian-release and var/lib/dpkg/status, on partition ${root_partition}." 1
  fi
  echo ${loop_device}
  log_detailed "attach_armbian_image: finish (loop_device=${loop_device})"
}
################################################################################
# unmounts the root file system of a disk image and detaches its loop device
detach_armbian_image() {
  local image_mount_folder=$1
  local loop_device=$2

  log_detailed "detach_armbian_image: start (image_mount_folder=${image_mount_folder}, loop_device=${loop_device})"
  sudo umount ${image_mount_folder}
  sudo losetup -d ${loop_device}
  rmdir ${image_mount_folder}
  log_detailed "detach_armbian_image: finish"
}
################################################################################
# prints the apt-get options that resolve and download the packages for an arm
# board instead of this host: the board's architecture, from ports.ubuntu.com,
# where ubuntu publishes the arm archives. the sources are kept in apt_folder,
# so this host's apt configuration is never changed. the archive is checked
# with this host's ubuntu archive key, which signs ports.ubuntu.com too.
#
# parameters
#   board               - the board
#   ubuntu_version_name - the ubuntu release name, for example resolute
#   apt_folder          - the folder to keep the sources and lists in
get_armbian_apt_options() {
  local board=$1
  local ubuntu_version_name=$2
  local apt_folder=$3

  local arch=$(get_sca_usb_stick_board_field ${board} arch)
  mkdir -p ${apt_folder}sources.list.d ${apt_folder}lists/partial ${apt_folder}cache
  echo "Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: ${ubuntu_version_name} ${ubuntu_version_name}-security ${ubuntu_version_name}-updates
Components: main restricted universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" > ${apt_folder}sources.list.d/ubuntu-ports.sources
  echo "-o APT::Architecture=${arch} -o APT::Architectures=${arch}" \
    "-o Dir::Etc::SourceList=/dev/null -o Dir::Etc::SourceParts=${apt_folder}sources.list.d" \
    "-o Dir::State::Lists=${apt_folder}lists -o Dir::Cache=${apt_folder}cache"
}
################################################################################
# adds the settings an armbian board needs as an air-gapped ca appliance to the
# staged files, as described in docs/air-gapped-appliance.md:
#
# - masks the fake-hwclock units (4.1): fake-hwclock-load sets the clock back
#   to a stale saved time at every boot (debian #1093227), which puts wrong
#   notBefore dates on the certificates the ca issues
# - keeps the journal on disk, bounded in size (4.6): armbian keeps it in RAM,
#   so it is gone at every power cut
#
# armbian-ramlog is disabled by copy_into_armbian_image, as it edits a file of
# the image.
add_armbian_appliance_settings() {
  local live_filesystem_folder=$1

  log_detailed "add_armbian_appliance_settings: start (live_filesystem_folder=${live_filesystem_folder})"
  local systemd_system_folder=${live_filesystem_folder}etc/systemd/system/
  local journald_folder=${live_filesystem_folder}etc/systemd/journald.conf.d/
  sudo mkdir -p ${systemd_system_folder} ${journald_folder}
  local unit
  for unit in fake-hwclock-load.service fake-hwclock-save.service fake-hwclock-save.timer; do
    sudo ln -sfn /dev/null ${systemd_system_folder}${unit}
  done
  printf '[Journal]\nStorage=persistent\nSystemMaxUse=64M\nSystemMaxFileSize=8M\n' | \
    sudo tee ${journald_folder}zz-sca-appliance.conf > /dev/null
  log_detailed "add_armbian_appliance_settings: finish (live_filesystem_folder=${live_filesystem_folder})"
}
################################################################################
# copies the staged files into the mounted root file system of an armbian
# image, owned by root, and disables armbian-ramlog, which keeps /var/log in RAM
# and so would lose the journal at a power cut (docs/air-gapped-appliance.md
# 4.6). fails, saying why, if the files do not fit.
#
# parameters
#   live_filesystem_folder  - the staged files
#   image_mount_folder      - where the root file system is mounted
copy_into_armbian_image() {
  local live_filesystem_folder=$1
  local image_mount_folder=$2

  log_detailed "copy_into_armbian_image: start (live_filesystem_folder=${live_filesystem_folder}, image_mount_folder=${image_mount_folder})"
  local needed=$(sudo du -sB1 ${live_filesystem_folder} | cut -f 1)
  local available=$(df --output=avail -B1 ${image_mount_folder} | tail -n 1 | tr -d ' ')
  if ! [ "${needed}" -lt "${available}" ] 2> /dev/null; then
    >&2 echo "the sca files (${needed} bytes) do not fit in the root file system of the image (${available} bytes free)."
    return 1
  fi
  # -d keeps the symbolic links, such as the unit masks. without -p, existing
  # folders of the image keep their owner and mode
  if ! sudo cp -dR ${live_filesystem_folder}. ${image_mount_folder}; then
    >&2 echo "could not copy ${live_filesystem_folder} into the image."
    return 1
  fi
  local ramlog_file=${image_mount_folder}etc/default/armbian-ramlog
  if [ -f ${ramlog_file} ]; then
    sudo sed -i 's/^ENABLED=.*/ENABLED=false/' ${ramlog_file} || return 1
  fi
  log_detailed "copy_into_armbian_image: finish"
}
################################################################################
# mounts the original iso image and extracts the files needed for building the
# sca iso image:
#
# - boot/grub/grub.cfg, boot/grub/loopback.cfg and md5sum.txt into
#   $iso_image_sca_folder, for patching,
# - the dpkg status of the live filesystem into $live_dpkg_status_file
#
# then unmounts the iso image and echoes the file name of the live layer, the
# squashfs layer the live session boots, for example
# minimal.standard.live.squashfs
#
# parameters:
# - iso_image_file          - file name of the iso image
# - iso_image_mount_folder  - the folder under which to mount the original iso
#                             image
# - iso_image_sca_folder    - the folder into which to extract the files
# - live_dpkg_status_file   - the file into which to extract the dpkg status
#
# NOTE: this function requires sudo priviledges in order to mount the iso image
#
extract_iso_image_files() {
  local iso_image_file=$1
  local iso_image_mount_folder=$2
  local iso_image_sca_folder=$3
  local live_dpkg_status_file=$4

  log_detailed "extract_iso_image_files: start (iso_image_file=${iso_image_file}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_dpkg_status_file=${live_dpkg_status_file})"
  # check if iso image has already been mounted. if so, use existing mount
  if mount | grep ${iso_image_mount_folder%/} > /dev/null; then
    log_detailed "extract_iso_image_files: iso image folder ${iso_image_mount_folder} is already mounted to an iso image. using existing mount."
  else
    log_detailed "extract_iso_image_files: mounting iso image at ${iso_image_mount_folder}."
    mkdir -p $iso_image_mount_folder
    # a failed mount leaves the folder empty, which the layout check below
    # would misreport as a malformed iso image
    if ! sudo mount -r -t iso9660 $iso_image_file $iso_image_mount_folder; then
      rmdir $iso_image_mount_folder 2> /dev/null
      error "could not mount $iso_image_file at $iso_image_mount_folder (sudo mount -r -t iso9660 failed, see above)." 1
    fi
  fi
  local casper_folder=${iso_image_mount_folder}casper/
  local live_layers=(${casper_folder}*.live.squashfs)
  if [ ${#live_layers[@]} != 1 ] || ! [ -f "${live_layers[0]}" ] || \
      ! [ -f ${iso_image_mount_folder}boot/grub/grub.cfg ]; then
    sudo umount $iso_image_mount_folder
    error "$(basename $iso_image_file) does not have the expected layout: one casper/*.live.squashfs layer and boot/grub/grub.cfg." 1
  fi
  local live_layer_file_name=$(basename ${live_layers[0]})
  log_detailed "extract_iso_image_files: live layer ${live_layer_file_name}"
  mkdir -p ${iso_image_sca_folder}
  local file
  for file in boot/grub/grub.cfg boot/grub/loopback.cfg md5sum.txt; do
    if [ -f ${iso_image_mount_folder}${file} ]; then
      cp ${iso_image_mount_folder}${file} ${iso_image_sca_folder}
      chmod u+w ${iso_image_sca_folder}$(basename $file)
    fi
  done
  # the dpkg status is read from the top-most layer that has it. a layer named
  # a.b.c is stacked on a.b, which is stacked on a
  local layer_name=${live_layer_file_name%.squashfs}
  while ! unsquashfs -cat ${casper_folder}${layer_name}.squashfs var/lib/dpkg/status \
      > ${live_dpkg_status_file} 2> /dev/null || ! [ -s ${live_dpkg_status_file} ]; do
    if [ "${layer_name%.*}" = "${layer_name}" ]; then
      sudo umount $iso_image_mount_folder
      error "no layer of $(basename $iso_image_file) has var/lib/dpkg/status." 1
    fi
    layer_name=${layer_name%.*}
  done
  log_detailed "extract_iso_image_files: dpkg status read from ${layer_name}.squashfs"
  sudo umount $iso_image_mount_folder
  rmdir $iso_image_mount_folder
  echo $live_layer_file_name
  log_detailed "extract_iso_image_files: finish (iso_image_file=${iso_image_file}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_dpkg_status_file=${live_dpkg_status_file})"
}
################################################################################
# cleans up the
#   - live_filesystem_folder,
#   - iso_image_sca_folder,
#   - downloaded_iso_image, if no_cache_iso is set
clean_up_live_usb_intermediary_files () {
  local live_filesystem_folder=$1
  local iso_image_sca_folder=$2
  local downloaded_iso_image=$3
  local no_cache_iso=$4

  log_detailed "clean_up_live_usb_intermediary_files start (downloaded_iso_image=${downloaded_iso_image}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder}, no_cache_iso=${no_cache_iso})"
  sudo rm -rf $live_filesystem_folder
  sudo rm -rf $iso_image_sca_folder
  [ $no_cache_iso = true ] && rm -f $downloaded_iso_image
  # we leave only the created iso sca image
  log_detailed "clean_up_live_usb_intermediary_files finish (downloaded_iso_image=${downloaded_iso_image}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder}, no_cache_iso=${no_cache_iso})"
}
################################################################################
# populates the sca filesystem layer
#   - installs sca
#   - downloads repositories and packages for offline installation
#   - configures the offline machine to use the local repositories
#
# IMPORTANT NOTE: any changes in the live_filesystem_folder shall not leave
# current uids (user ids) in the file system. As there is only root account
# in the live session, all files shall be created with root uid (0)
patch_live_filesystem() {
  local live_filesystem_folder=$1
  local live_filesystem_repos_folder=$2
  local live_filesystem_sca_home_folder=$3
  local offline_repos_folder=$4
  local live_filesystem_packages_folder=$5
  local test_mode=$6
  local test_folder_relative=$7
  local ubuntu_version_name=$8
  local include_apt_mirror=$9
  local yubikey_support=${10}
  local exclude_pkcs11_support=${11}
  local live_dpkg_status_file=${12}
  local apt_options=${13}

  log_detailed "patch_live_filesystem start ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror}, "\
    "yubikey_support=${yubikey_support}, exclude_pkcs11_support=${exclude_pkcs11_support})"
  add_sca $live_filesystem_folder $live_filesystem_sca_home_folder $test_mode $test_folder_relative $yubikey_support $include_apt_mirror
  add_repos $live_filesystem_repos_folder $ubuntu_version_name $include_apt_mirror
  add_sources_list $live_filesystem_folder $offline_repos_folder $ubuntu_version_name $include_apt_mirror
  add_packages $live_filesystem_packages_folder $exclude_pkcs11_support $yubikey_support $live_dpkg_status_file "${apt_options}"
  log_detailed "patch_live_filesystem finish ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror}, "\
    "yubikey_support=${yubikey_support}, exclude_pkcs11_support=${exclude_pkcs11_support})"
}
################################################################################
# patches a grub config of the iso image so that it boots directly into the
# ubuntu live session, with the sca layer on top of the live filesystem.
#
# casper mounts the layer named by layerfs-path together with all the layers
# it is stacked on, so <live layer>.sca.squashfs brings in the live layer too.
patch_to_boot_into_live() {
  local grub_config=$1
  local sca_layer_file_name=$2

  sed -i \
    -e 's/^set timeout=.*/set timeout=0/' \
    -e "s|^\([[:space:]]*linux[[:space:]]\+/casper/vmlinuz\)|\1 layerfs-path=${sca_layer_file_name}|" \
    ${grub_config}
}
################################################################################
# replaces the md5sum.txt entry of a file in the iso image, or adds it
#
# parameters
#   md5sum_list - the md5sum.txt file
#   file        - the local file
#   iso_path    - the path of the file in the iso image, starting with /
update_md5sum_list() {
  local md5sum_list=$1
  local file=$2
  local iso_path=$3

  local md5=$(md5sum < ${file} | cut -d ' ' -f 1)
  grep -v "  \.${iso_path}$" ${md5sum_list} > ${md5sum_list}.new
  echo "${md5}  .${iso_path}" >> ${md5sum_list}.new
  mv ${md5sum_list}.new ${md5sum_list}
}
################################################################################
# create sca live usb iso image
#
# this method is called after populating the sca filesystem layer in order to
# create the final iso file ready to be placed on usb stick.
#
# the sca layer is compressed into a squashfs file and added to the original
# image next to the live layer, along with the patched grub configs. xorriso
# replays the boot setup of the original image, which it also reports with
# 'xorriso -indev <iso> -report_el_torito as_mkisofs', so the image stays a
# hybrid bios and uefi image.
#
# example call to xorriso
#
# xorriso -indev ~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.iso \
#   -outdev ~/.sca/downloads/ubuntu-26.04.1-desktop-amd64.sca.iso \
#   -map ~/.sca/iso_image_sca/minimal.standard.live.sca.squashfs /casper/minimal.standard.live.sca.squashfs \
#   -map ~/.sca/iso_image_sca/grub.cfg /boot/grub/grub.cfg \
#   -boot_image any replay
#
create_live_iso() {
  local live_filesystem_folder=$1
  local live_layer_file_name=$2
  local iso_image_file=$3
  local iso_image_sca_folder=$4
  local new_iso_image_file=$5

  log_detailed "create_live_iso: start ("\
    "live_filesystem_folder=${live_filesystem_folder}, live_layer_file_name=${live_layer_file_name}, "\
    "iso_image_file=${iso_image_file}, iso_image_sca_folder=${iso_image_sca_folder}, "\
    "new_iso_image_file=${new_iso_image_file})"
  local sca_layer_file_name=${live_layer_file_name%.squashfs}.sca.squashfs
  local sca_layer_file=${iso_image_sca_folder}${sca_layer_file_name}
  # mksquashfs appends to an existing file, so start from scratch
  sudo rm -f ${sca_layer_file}
  local redirect_output='> /dev/null'
  [[ $verbosity == vv* ]] && redirect_output=">> ${log_file}"
  eval sudo mksquashfs ${live_filesystem_folder} ${sca_layer_file} \
    -all-root -comp xz -Xbcj x86 -b 1024k ${redirect_output}
  if [ $? != 0 ]; then error "mksquashfs failed creating ${sca_layer_file}." 1; fi
  local xorriso_map_options=(-map ${sca_layer_file} /casper/${sca_layer_file_name})
  local md5sum_list=${iso_image_sca_folder}md5sum.txt
  [ -f ${md5sum_list} ] && update_md5sum_list ${md5sum_list} ${sca_layer_file} /casper/${sca_layer_file_name}
  local grub_config
  for grub_config in grub.cfg loopback.cfg; do
    [ -f ${iso_image_sca_folder}${grub_config} ] || continue
    patch_to_boot_into_live ${iso_image_sca_folder}${grub_config} ${sca_layer_file_name}
    xorriso_map_options+=(-map ${iso_image_sca_folder}${grub_config} /boot/grub/${grub_config})
    [ -f ${md5sum_list} ] && update_md5sum_list ${md5sum_list} ${iso_image_sca_folder}${grub_config} /boot/grub/${grub_config}
  done
  [ -f ${md5sum_list} ] && xorriso_map_options+=(-map ${md5sum_list} /md5sum.txt)
  log_detailed "create_live_iso: boot setup of the original image: $(xorriso -indev ${iso_image_file} -report_el_torito as_mkisofs 2> /dev/null)"
  rm -f ${new_iso_image_file}
  xorriso -indev ${iso_image_file} -outdev ${new_iso_image_file} \
    "${xorriso_map_options[@]}" \
    -boot_image any replay 2>> ${log_file}
  if [ $? != 0 ]; then
    rm -f ${new_iso_image_file}
    error "xorriso failed creating ${new_iso_image_file}. see ${log_file} for details." 1
  fi
  print_sca_disk_image_help ${new_iso_image_file}
  log_detailed "create_live_iso: finish ("\
    "live_filesystem_folder=${live_filesystem_folder}, live_layer_file_name=${live_layer_file_name}, "\
    "iso_image_file=${iso_image_file}, iso_image_sca_folder=${iso_image_sca_folder}, "\
    "new_iso_image_file=${new_iso_image_file})"
}
################################################################################
# prints how to write the sca image to the medium the board boots
#
# parameters
#   new_iso_image_file  - the sca image
#   board               - the board the image is for, pc by default
print_sca_disk_image_help() {
  local new_iso_image_file=$1
  local board=${2:-pc}

  # never print a concrete device: a pasted command would overwrite whatever
  # disk happens to have that name on the user's machine
  if [ "$board" = pc ]; then
    echo "to write the image to a usb stick, insert the stick and identify its device"
    echo "(BE CAREFUL - wrong device = data loss). a usb stick usually shows TRAN=usb, RM=1:"
    print_block_devices stick
    echo "then, replacing sdX with your stick's device, type:"
  else
    local boot_medium=$(get_sca_usb_stick_board_field ${board} boot_medium)
    echo "${board} boots this image from a ${boot_medium} as written. to boot it from a usb"
    echo "stick instead, the board needs u-boot in its spi flash first - a one-time step"
    echo "per board, see docs/usb-boot-on-arm.md"
    echo
    echo "to write the image to a ${boot_medium}, insert the card and identify its device"
    echo "(BE CAREFUL - wrong device = data loss). a card in a usb reader usually shows"
    echo "TRAN=usb, RM=1; a built-in reader names it mmcblkN, its first partition mmcblkNp1:"
    print_block_devices card
    echo "then, replacing sdX with your card's device, type:"
  fi
  echo "sudo umount /dev/sdX1"
  echo "sudo dd bs=4M if=${new_iso_image_file} of=/dev/sdX conv=fdatasync"
}
################################################################################
# lists the disks the image can be written to, never loop devices
#
# parameters
#   medium  - what to call the medium if the disks cannot be listed
print_block_devices() {
  local medium=$1

  # -e 7 hides loop devices (snaps etc.), which would bury the real disks
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -do NAME,TRAN,RM,SIZE,MODEL -e 7 2>/dev/null \
      || echo "  (could not list devices; run: lsblk -do NAME,TRAN,RM,SIZE,MODEL -e 7)"
  else
    echo "  (lsblk not found; identify the ${medium} with your system's disk tools)"
  fi
}
################################################################################
# mirrors the ubuntu main and restricted repositories into the sca layer, when
# --include-apt-mirror is set
add_repos() {
  local live_filesystem_repos_folder=$1
  local ubuntu_version_name=$2
  local include_apt_mirror=$3

  log_detailed "add_repos: start ("\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror})"
  if [ $include_apt_mirror != true ]; then
    log_detailed "add_repos: inclusion of apt-mirror had not been requested. skipping addition of repositories to the image alltogether."
    return
  fi
  local apt_mirror_lines='
  deb http://archive.ubuntu.com/ubuntu '${ubuntu_version_name}' main restricted
  deb http://archive.ubuntu.com/ubuntu '${ubuntu_version_name}'-security main restricted
  deb http://archive.ubuntu.com/ubuntu '${ubuntu_version_name}'-updates main restricted
  '
  if [ -d ${live_filesystem_repos_folder} ]; then
    log_detailed "skipping mirroring of apt repositories as the ${live_filesystem_repos_folder} folder exists."
    return
  fi
  sudo mkdir -p ${live_filesystem_repos_folder}
  sudo chown apt-mirror:apt-mirror ${live_filesystem_repos_folder}
  # selected ubuntu version
  local mirror_list="
  set base_path       ${live_filesystem_repos_folder}
  set run_postmirror  0
  set nthreads        20
  set _tilde          0
  ${apt_mirror_lines}
  clean               http://archive.ubuntu.com/ubuntu
  "
  [ -f /etc/apt/mirror.list.sca.bak ] && sudo rm /etc/apt/mirror.list.sca.bak
  [ -f /etc/apt/mirror.list ] && sudo cp /etc/apt/mirror.list /etc/apt/mirror.list.sca.bak
  local create_mirror_list_command="echo \"${mirror_list}\" > /etc/apt/mirror.list"
  sudo bash -c "${create_mirror_list_command}"
  echo "this may take a while..."
  local redirect_output='> /dev/null'
  [[ $verbosity == vv* ]] && redirect_output=">> ${log_file}"
  eval sudo -iu apt-mirror apt-mirror ${redirect_output}
  if [ $? != 0 ] ; then error "apt-mirror failed. check configuration." 1; fi
  [ -f /etc/apt/mirror.list.sca.bak ] && sudo cp /etc/apt/mirror.list.sca.bak /etc/apt/mirror.list

  log_detailed "add_repos: finish ("\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror})"
}
################################################################################
# adds sca to live_filesystem_folder so it will be available in offline boot:
# copies ~/bin/sca and the sca configuration, and generates the sca completion
# from ~/bin/sca. fails the build if any of them cannot be added.
#
# parameters
#   - live_filesystem_folder  - the location of the sca filesystem layer
#   - live_filesystem_sca_home_folder         - the location of sca home within the
#                               live_filesystem_folder
# example call:
#
#   add_sca ~/.sca/live_filesystem/ ~/.sca/live_filesystem/opt/sca/ false test/ true false
#
add_sca() {
  local live_filesystem_folder=$1
  local live_filesystem_sca_home_folder=$2
  local test_mode=$3
  local test_folder_relative=$4
  local yubikey_support=$5
  local include_apt_mirror=$6

  log_detailed "add_sca: start (live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative})"
  local sca_bin_folder=${live_filesystem_folder}opt/sca/bin/
  local sca_completion_folder=${live_filesystem_folder}etc/bash_completion.d/
  local sca_config_folder=${live_filesystem_folder}etc/ssl/sca/
  local profile_folder=${live_filesystem_folder}etc/profile.d/
  local systemd_user_folder=${live_filesystem_folder}etc/systemd/user/
  sudo mkdir -p ${sca_config_folder} ${sca_bin_folder} ${sca_completion_folder} ${profile_folder} ${systemd_user_folder}
  if [ $? != 0 ]; then error "add_sca: could not create the sca folders in ${live_filesystem_folder}." 1; fi
  sudo cp ~/bin/sca $sca_bin_folder
  if [ $? != 0 ]; then error "add_sca: could not copy ~/bin/sca to ${sca_bin_folder}." 1; fi
  # the completion is generated from the sca shipped on the stick, so it matches
  # it whatever way sca was installed on this host (make deploy or sca install).
  # it is generated as the user, only the write runs as root.
  (
    set -o pipefail
    bash ~/bin/sca completion bash | sudo tee ${sca_completion_folder}sca > /dev/null
  )
  if [ $? != 0 ]; then
    error "add_sca: could not generate the sca completion from ~/bin/sca into ${sca_completion_folder}sca." 1
  fi
  # copy only the configuration files, not the backups 'config create' leaves
  # next to them (*.bak, *.bak-<timestamp>)
  sudo cp ~/.sca/config/*.config ~/.sca/config/*.conventions ~/.sca/config/*.ini $sca_config_folder
  if [ $? != 0 ]; then error "add_sca: could not copy the sca configuration from ~/.sca/config/ to ${sca_config_folder}." 1; fi
  # the live session starts the desktop installer wizard from a systemd user
  # unit in a lower layer. mask it from the sca layer (/etc/systemd/user takes
  # precedence over /usr/lib/systemd/user), so the base layers stay untouched
  # and the machine boots straight into the live session. this only stops the
  # wizard: the installer backend (subiquity-server from the
  # ubuntu-desktop-bootstrap snap) is still started by another route.
  sudo ln -sfn /dev/null ${systemd_user_folder}ubuntu-desktop-installer.service
  local yubikey_parameter=""
  [ $yubikey_support = true ] && yubikey_parameter="--yubikey-support"
  local apt_update_command=""
  [ $include_apt_mirror = true ] && apt_update_command="sudo apt-get update"
  local start_test_commands=""
  # TODO: check if need to alter the copied online config for offline scenario,
  if [ $test_mode = true ]; then
    # the results disk is found by its filesystem label, never by kernel name,
    # and is never partitioned or formatted here: sca test prepares it on the
    # host. without it, nothing is touched and the machine stays up.
    # profile.d is sourced by more than one shell per session, so an atomic
    # mkdir lets only the first one run the tests. the marker lives in
    # ~/.sca, which sca owns and the install block above has just created:
    # something in the live session removes directories under /run between
    # logins, so a second shell got the lock there. the live home is in RAM,
    # so the marker is still gone after a reboot.
    local test_results_disk_label=$(get_test_results_disk_label)
    start_test_commands='
  echo \"sca test image: runs the sca air-gapped tests, writes the results to the disk labelled '${test_results_disk_label}' and shuts down.\"
  test_results_disk=/dev/disk/by-label/'${test_results_disk_label}'
  if ! mkdir ~/.sca/.test-image-lock 2>/dev/null; then
    echo \"sca test image: [\$\$ \$PPID \$(date +%T.%N) \$0] lock already held by another shell in this session. skipping.\" >> ~/.sca/log
  else
    echo \"sca test image: [\$\$ \$PPID \$(date +%T.%N) \$0] lock acquired.\" >> ~/.sca/log
    if ! [ -b \"\$test_results_disk\" ]; then
      echo \"sca test image: [\$\$ \$PPID \$(date +%T.%N) \$0] no disk labelled '${test_results_disk_label}' found. not running the tests, no disk was touched.\" >> ~/.sca/log
    elif ! { mkdir -p ~/.sca/'${test_folder_relative}' && sudo mount \"\$test_results_disk\" ~/.sca/'${test_folder_relative}'; }; then
      echo \"sca test image: [\$\$ \$PPID \$(date +%T.%N) \$0] could not mount \$test_results_disk. not running the tests.\" >> ~/.sca/log
    else
      sudo chown -R ubuntu:ubuntu ~/.sca/'${test_folder_relative}'
      sca -d test --air-gapped >> ~/.sca/log 2>&1
      cp ~/.sca/log ~/.sca/'${test_folder_relative}'
      sync
      sudo shutdown now
    fi
  fi
  '
  fi

  local profile_content='
  if ! [ -d \"\$HOME/.sca\" ]; then
    '"$apt_update_command"'
    mkdir -p \"\$HOME/.sca/config\"
    cp /etc/ssl/sca/* ~/.sca/config/
    /opt/sca/bin/sca -d install --air-gapped '$yubikey_parameter'
  fi

  # set PATH so it includes user private bin if it exists
  if [ -d \"\$HOME/bin\" ] ; then
      PATH=\"\$HOME/bin:\$PATH\"
  fi
  '"${start_test_commands}"

  local profile_file=${profile_folder}sca.sh
  local create_profile_command="echo \"${profile_content}\" > ${profile_file}"
  sudo bash -c "${create_profile_command}"
  log_detailed "add_sca: profile_content $profile_content"
  log_detailed "add_sca: create_profile_command $(echo \"$create_profile_command\")"
  log_detailed "add_sca: profile_file $(cat $profile_file)"
  log_detailed "add_sca: finish (live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative})"
}
################################################################################
# configures the offline environment to install packages from local apt-mirror
#
# the sca layer replaces the ubuntu.sources of the live filesystem, which points
# to the online archive, with one pointing to the apt-mirror. the mirrored
# Release files are signed by the ubuntu archive key, which the live filesystem
# already has.
#
# parameters
#   - live_filesystem_folder  - the location of the sca filesystem layer
#   - offline_repos_folder    - the absoute path in offline environment to
#                               apt-mirror
#
# example call:
#
# add_sources_list ~/.sca/live_filesystem/ /opt/sca/apt-mirror/ resolute true
#
add_sources_list() {
  local live_filesystem_folder=$1
  local offline_repos_folder=$2
  local ubuntu_version_name=$3
  local include_apt_mirror=$4

  log_detailed "add_sources_list: start ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, "\
    "include_apt_mirror=${include_apt_mirror})"
  if [ $include_apt_mirror != true ]; then
    log_detailed "apt-mirror was not requested. skipping adding to sources list alltogether."
    return
  fi

  local sources="Types: deb
URIs: file://${offline_repos_folder}mirror/archive.ubuntu.com/ubuntu/
Suites: ${ubuntu_version_name} ${ubuntu_version_name}-security ${ubuntu_version_name}-updates
Components: main restricted
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
  local sources_folder=${live_filesystem_folder}etc/apt/sources.list.d/
  sudo mkdir -p ${sources_folder}
  echo "${sources}" | sudo tee ${sources_folder}ubuntu.sources > /dev/null

  log_detailed "add_sources_list: finish ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, "\
    "include_apt_mirror=${include_apt_mirror})"
}
################################################################################
# adds cruicial packages to live distribution so they will be available in
# offline use
#
# apt on this host resolves the packages against the dpkg status of the live
# filesystem, so exactly the packages, and the dependencies, the live session
# is missing are downloaded. this works because the host runs the same ubuntu
# release as the image.
#
# parameters
#   - live_filesystem_packages_folder - the folder to download the packages to
#   - exclude_pkcs11_support          - skip the pkcs11 packages
#   - yubikey_support                 - add the yubikey packages
#   - live_dpkg_status_file           - the dpkg status of the live filesystem
#   - apt_options                     - optional apt-get options, to download
#                                       the packages for an arm board, see
#                                       get_armbian_apt_options
#
# example call
#   add_packages ~/.sca/live_filesystem/opt/sca/packages/ false true ~/.sca/iso_image_sca/dpkg-status
#
add_packages() {
  local live_filesystem_packages_folder=$1
  local exclude_pkcs11_support=$2
  local yubikey_support=$3
  local live_dpkg_status_file=$4
  local apt_options=$5

  log_detailed "add_packages: start ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, yubikey_support=${yubikey_support})"
  # datefudge fakes the creation date of ca certificates
  local packages=(openssl datefudge)
  [ $exclude_pkcs11_support != true ] && packages+=(pcscd libccid opensc
    opensc-pkcs11 libengine-pkcs11-openssl pkcs11-provider)
  [ $yubikey_support = true ] && packages+=(ykcs11 yubico-piv-tool
    yubikey-manager gnupg scdaemon)
  sudo mkdir -p ${live_filesystem_packages_folder}partial
  local redirect_output='> /dev/null'
  [[ $verbosity == vv* ]] && redirect_output=">> ${log_file}"
  eval sudo apt-get ${apt_options} update ${redirect_output}
  eval sudo apt-get ${apt_options} install --download-only --yes --no-install-recommends \
    -o Dir::State::status=${live_dpkg_status_file} \
    -o Dir::Cache::archives=${live_filesystem_packages_folder} \
    ${packages[*]} ${redirect_output}
  if [ $? != 0 ]; then
    [ -n "${apt_options}" ] && \
      error "failed downloading ${packages[*]} for the offline environment from ports.ubuntu.com." 1
    error "failed downloading ${packages[*]} for the offline environment. check that this host's apt sources include the ubuntu universe component." 1
  fi
  sudo rm -rf ${live_filesystem_packages_folder}partial ${live_filesystem_packages_folder}lock
  log_detailed "add_packages: finish ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, yubikey_support=${yubikey_support})"
}
