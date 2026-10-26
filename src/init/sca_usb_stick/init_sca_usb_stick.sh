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
#     - /etc/bash_completion.d/- adding sca completion
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

init_sca_usb_stick() {
  local skip_cleanup=false
  local test_image=false
  local include_apt_mirror=false
  local yubikey_support=false
  local exclude_pkcs11_support=false
  local no_cache_iso=false

  local OPTS=`getopt -o hstiyxon --long help,skip-cleanup,test-image,include-apt-mirror,yubikey-support,exclude-pkcs11-support,no-cache-iso,no-cache -n "init sca_usb_stick" -- "$@"`
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
  check_ubuntu_version_id "$ubuntu_version_id" "init sca_usb_stick"
  check_build_host_ubuntu_version "init sca_usb_stick"
  check_iso_image_tools $include_apt_mirror

  log_detailed "init_sca_usb_stick: start (skip_cleanup=${skip_cleanup}, test_image=${test_image}, "\
    "yubikey_support=${yubikey_support}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
    "include_apt_mirror=${include_apt_mirror}, ubuntu_version_id=${ubuntu_version_id})"
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

  local original_iso_image
  original_iso_image=$(download_ubuntu_image ${ubuntu_version_number} ${downloads_folder}) || exit 1

  local test_suffix=''
  [ $test_image = true ] && test_suffix='-test'
  local new_iso_image_file=${original_iso_image%.iso}.sca${test_suffix}.iso
  log_detailed "init_sca_usb_stick: new_iso_image_file ${new_iso_image_file}"
  # a test image must carry the sca being tested, so never reuse an old one
  if [ $test_image = true ] && [ -f ${new_iso_image_file} ]; then
    log_detailed "init_sca_usb_stick: removing the existing test image ${new_iso_image_file}"
    sudo rm -f ${new_iso_image_file}
  fi
  if [ -f ${new_iso_image_file} ]; then
    echo "the iso image $new_iso_image_file already exists. please use that one, or remove it to create another one."
    print_sca_disk_image_help $new_iso_image_file
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
  create_live_iso \
    $live_filesystem_folder \
    $live_layer_file_name \
    $original_iso_image \
    $iso_image_sca_folder \
    $new_iso_image_file
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
  echo "
@@@HELP@@@
    "
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
check_iso_image_tools() {
  local include_apt_mirror=$1

  local tools=(wget sha256sum md5sum xorriso mksquashfs unsquashfs apt-get)
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
# downloads the SHA256SUMS file of an ubuntu version into the downloads folder
# and echoes the url of the folder it was downloaded from.
#
# the current releases are at https://releases.ubuntu.com/<major>.<minor>/,
# older ones are moved to https://old-releases.ubuntu.com/releases/<major>.<minor>/
# if neither can be reached, a previously downloaded SHA256SUMS file is used.
#
# parameters
#     version           - the ubuntu version, of form <major>.<minor>
#     downloads_folder  - the folder into which to download the file
#
# example call:
# download_ubuntu_sha256sums '26.04' ~/.sca/downloads/
download_ubuntu_sha256sums() {
  local version=$1
  local downloads_folder=$2

  log_detailed "download_ubuntu_sha256sums: start (version=${version}, downloads_folder=${downloads_folder})"
  local sums_file=$(get_ubuntu_sha256sums_file ${version} ${downloads_folder})
  mkdir -p $downloads_folder
  local base_url
  for base_url in "https://releases.ubuntu.com/${version}/" \
      "https://old-releases.ubuntu.com/releases/${version}/"; do
    if wget --quiet -O "${sums_file}.new" "${base_url}SHA256SUMS" && \
        [ -n "$(get_latest_ubuntu_iso_filename ${version} "${sums_file}.new")" ]; then
      mv "${sums_file}.new" "${sums_file}"
      log_detailed "download_ubuntu_sha256sums: finish (base_url=${base_url})"
      echo "$base_url"
      return
    fi
    log_detailed "download_ubuntu_sha256sums: no ubuntu ${version} desktop image listed at ${base_url}"
  done
  rm -f "${sums_file}.new"
  if [ -f "${sums_file}" ]; then
    >&2 echo "could not download the ubuntu ${version} SHA256SUMS file. using the previously downloaded ${sums_file}."
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
# against the published SHA256SUMS and echoes the downloaded image file name
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
    >&2 echo "the local image $downloaded_file does not match the published SHA256SUMS. downloading it again."
    rm -f $downloaded_file
  fi
  >&2 echo "downloading ${base_url}${file}. this may take a while..."
  if ! wget --append-output ${log_file} -O ${downloaded_file}.part ${base_url}${file}; then
    rm -f ${downloaded_file}.part
    error "failed downloading ${base_url}${file}." 1
  fi
  if [ "$(sha256sum ${downloaded_file}.part | cut -d ' ' -f 1)" != "$expected_sum" ]; then
    rm -f ${downloaded_file}.part
    error "the downloaded ${file} does not match the published SHA256SUMS. the image was removed." 1
  fi
  mv ${downloaded_file}.part ${downloaded_file}
  echo $downloaded_file
  log_detailed "download_ubuntu_image: finish (version=${version}, downloads_folder=${downloads_folder})"
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
    sudo mount -r -t iso9660 $iso_image_file $iso_image_mount_folder
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
  add_packages $live_filesystem_packages_folder $exclude_pkcs11_support $yubikey_support $live_dpkg_status_file
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
print_sca_disk_image_help() {
  local new_iso_image_file=$1

  echo "insert the usb stick, determine which device it is /dev/sd[a|b|c|d|e|f] ( in below case it is /dev/sdc ) then type:"
  echo "sudo umount /dev/sdb1"
  echo "sudo dd bs=4M if=${new_iso_image_file} of=/dev/sdb conv=fdatasync"
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
# adds sca to live_filesystem_folder so it will be available in offline boot
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
  sudo mkdir -p ${sca_config_folder} ${sca_bin_folder} ${sca_completion_folder} ${profile_folder}
  sudo cp ~/bin/sca $sca_bin_folder
  sudo cp ~/bin/sca_completion ${sca_completion_folder}sca
  sudo cp ~/.sca/config/* $sca_config_folder
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
    local test_results_disk_label=$(get_test_results_disk_label)
    start_test_commands='
  echo \"sca test image: runs the sca air-gapped tests, writes the results to the disk labelled '${test_results_disk_label}' and shuts down.\"
  test_results_disk=/dev/disk/by-label/'${test_results_disk_label}'
  if ! [ -b \"\$test_results_disk\" ]; then
    echo \"sca test image: no disk labelled '${test_results_disk_label}' found. not running the tests, no disk was touched.\" | tee -a ~/.sca/log
  elif ! { mkdir -p ~/.sca/'${test_folder_relative}' && sudo mount \"\$test_results_disk\" ~/.sca/'${test_folder_relative}'; }; then
    echo \"sca test image: could not mount \$test_results_disk. not running the tests.\" | tee -a ~/.sca/log
  else
    sudo chown -R ubuntu:ubuntu ~/.sca/'${test_folder_relative}'
    sca -d test --air-gapped >> ~/.sca/log 2>&1
    cp ~/.sca/log ~/.sca/'${test_folder_relative}'
    sync
    sudo shutdown now
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
#
# example call
#   add_packages ~/.sca/live_filesystem/opt/sca/packages/ false true ~/.sca/iso_image_sca/dpkg-status
#
add_packages() {
  local live_filesystem_packages_folder=$1
  local exclude_pkcs11_support=$2
  local yubikey_support=$3
  local live_dpkg_status_file=$4

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
  eval sudo apt-get update ${redirect_output}
  eval sudo apt-get install --download-only --yes --no-install-recommends \
    -o Dir::State::status=${live_dpkg_status_file} \
    -o Dir::Cache::archives=${live_filesystem_packages_folder} \
    ${packages[*]} ${redirect_output}
  if [ $? != 0 ]; then
    error "failed downloading ${packages[*]} for the offline environment. check that this host's apt sources include the ubuntu universe component." 1
  fi
  sudo rm -rf ${live_filesystem_packages_folder}partial ${live_filesystem_packages_folder}lock
  log_detailed "add_packages: finish ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support}, yubikey_support=${yubikey_support})"
}
