################################################################################
# initialize the usb stick for booting offline secure environment
# by performing the following tasks
#
# - download live usb image
# - download ubuntu repositories for offline installation
# - patch the live usb image to contain the offline installations and sca
# - create usb stick from live usb image
#
# parameters
#   ubuntu_version_id
#
# the following folders are altered in the originally downloaded iso image:
#
# /isolinux/isolinux.cfg       - changed so that we boot directly into live session
# /casper/filesystem.squashfs  - the root file system altered as follows
#     - /etc/apt/              - configuring sources.list to use local apt-mirror
#     - /etc/bash_completion.d/- adding sca completion
#     - /etc/ssl/              - adding sca configuration related files
#     - /etc/                  - in bash.bashrc add ~/bin/ to path, execute sca
#                                on start as needed
#     - /opt/sca               - apt-mirror, packages, sca

init_sca_usb_stick() {
  local skip_cleanup=false
  local test_image=false
  local include_apt_mirror=false
  local yubikey_support=false
  local exclude_pkcs11_support=false
  local no_cache_squashfs=false
  local no_cache_iso=false
  local no_cache=false

  local OPTS=`getopt -o hstiyxqon --long help,skip-cleanup,test-image,include-apt-mirror,yubikey-support,exclude-pkcs11-support,no-cache-squashfs,no-cache-iso,no-cache -n "init sca_usb_stick" -- "$@"`
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
      -q | --no-cache-squashfs )
        no_cache_squashfs=true
        shift
        ;;
      -p | --no-cache-iso )
        no_cache_iso=true
        shift
        ;;
      -n | --no-cache )
        no_cache_squashfs=true
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

  # array of all valid ubuntu version ids declared
  local valid_ubuntu_version_ids=("18.04.1-bionic" "16.04.4-xenial"
    "16.04.3-xenial" "16.04.2-xenial" "16.04.1-xenial" "14.04.5-trusty"
    "14.04.4-trusty" "14.04.3-trusty" "14.04.2-trusty" "14.04.1-trusty")
  # use ubuntu version id specified below for the offline environment on sca usb
  # stick
  local ubuntu_version_id=${1:-"18.04.1-bionic"}
  # check if valid ubuntu version id was supplied
  if [[ ! " ${valid_ubuntu_version_ids[@]} " =~ " ${ubuntu_version_id} " ]]; then
    error "invalid ubuntu version id was provided. please, run sca init sca-usb-stick -h to see more info." 1
  fi

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
  # the folder in which the originally downloaded iso image is mounted
  local iso_image_sca_folder=${sca_home_folder}iso_image_sca/
  # the folder in which we modify the original live filesystem
  local live_filesystem_folder=${sca_home_folder}live_filesystem/
  # name of the file containing the live filesystem image
  local live_filesystem_image_file=filesystem.squashfs

  # the folder within the modifyable copy of original iso image in which the
  # live filesystem is. it is squashfs filesystem - a compressed filesystem in
  # a single file
  local live_filesystem_image_folder=${iso_image_sca_folder}casper/
  # the live filesystem image file fullpath - the squashfs filesystem
  local live_filesystem_image=${live_filesystem_image_folder}${live_filesystem_image_file}
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
  # packages folder fullpath when running offline booted from the live usb
  local offline_packages_folder=${offline_sca_home_folder}${packages_folder_relative}


  local original_iso_image=$(download_ubuntu_image ${ubuntu_version_number} ${downloads_folder})

  [ $test_image = true ] && test_suffix='-test'
  local new_iso_image_file=${original_iso_image:0:${#original_iso_image}-4}.sca${test_suffix}.iso
  log_detailed "init_sca_usb_stick: new_iso_image_file ${new_iso_image_file}"
  if [ -f ${new_iso_image_file} ]; then
    echo "the iso image $new_iso_image_file already exists. please use that one, or remove it to create another one."
    print_sca_disk_image_help $new_iso_image_file
    log_detailed "init_sca_usb_stick: finish (skip_cleanup=${skip_cleanup}, test_image=${test_image}, "\
      "yubikey_support=${yubikey_support}, "\
      "exclude_pkcs11_support=${exclude_pkcs11_support}, "\
      "include_apt_mirror=${include_apt_mirror}, ubuntu_version_id=${ubuntu_version_id})"
    return
  fi

  mount_live_filesystem \
    $original_iso_image \
    $iso_image_mount_folder \
    $iso_image_sca_folder \
    $live_filesystem_folder \
    $live_filesystem_image \
    $no_cache_squashfs \
    $no_cache_iso \
    $downloads_folder
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
    $exclude_pkcs11_support
  create_live_iso \
    $live_filesystem_folder \
    $live_filesystem_image \
    $original_iso_image \
    $iso_image_sca_folder \
    $test_image \
    $no_cache_squashfs
  [ $skip_cleanup != true ] && clean_up_live_usb_intermediary_files \
    $live_filesystem_folder \
    $iso_image_sca_folder \
    $iso_image_mount_folder \
    $original_iso_image
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
# returns the iso file name from an ubuntu version id for particular iso kind
#
# parameters:
# ubuntu_version_number - <major>.<minor>.<fix> ubuntu version, for example 18.04.1
# kind - kind of image file to provide the name for
# three kinds supported:
#     sca - the sca usb stick image,
#     test - the sca test image
#     original - the original iso as downloaded from ubuntu
#
get_iso_filename_from_version_number() {
  local ubuntu_version_number=$1
  local kind=$2

  local version_parts=(${ubuntu_version_number//./ })
  [ ${#version_parts[@]} != 3 ] && return
  local major_minor="${version_parts[0]}.${version_parts[1]}"
  local major_minor_fix="${major_minor}.${version_parts[2]}"
  case $kind in
    sca )
      echo "ubuntu-${major_minor_fix}-desktop-amd64.sca.iso"
      ;;
    test )
      echo "ubuntu-${major_minor_fix}-desktop-amd64.sca-test.iso"
      ;;
    original )
      echo "ubuntu-${major_minor_fix}-desktop-amd64.iso"
      ;;
    * )
      echo "ubuntu-${major_minor_fix}-desktop-amd64.iso"
      ;;
  esac
}
################################################################################
# donwloads ubuntu live ISO image and returns the download image file name
#
# parameters
#     version           - the verison of ubuntu to download iso file for. needs
#                         to be of form <major>.<minor>.<fix> and offcourse to
#                         relate to real ubuntu version
#     downloads_folder  - the folder into which to download the iso file
#
# ubuntu live iso images are available at http://releases.ubuntu.com
# the form of url is as follows:
#
#   http://releases.ubuntu.com/<version_major>/ubuntu-<version_fix>-desktop-amd64.iso
#   http://releases.ubuntu.com/18.04/ubuntu-18.04.1-desktop-amd64.iso
#
#  where
#     version_minor - has major_version.minor_version form
#                     recent version values are:
#                     - 18.04
#                     -
#                     -
#                     -
#                     -
#     version_fix   - has major_version.minor_version.fix_version form
#                     for version 18.04 values are
#                      - 18.04.1
#
# example call:
# download_ubuntu_image '18.04.1' ~/.sca/downloads ~/.sca/log
#install_package_from_repos:
download_ubuntu_image() {
  local version=$1
  local downloads_folder=$2

  log_detailed "download_ubuntu_image: start (version=${version}, downloads_folder=${downloads_folder})"
  local version_parts=(${version//./ })
  [ ${#version_parts[@]} != 3 ] && return
  local major_minor="${version_parts[0]}.${version_parts[1]}"
  local major_minor_fix="${major_minor}.${version_parts[2]}"
  local url="http://releases.ubuntu.com/"
  local file=$(get_iso_filename_from_version_number "$version")
  local downloaded_file=${downloads_folder}$file
  local ubuntu_iso_url="${url}${major_minor}/${file}"
  if [ -f $downloaded_file ]; then
    log_detailed "download_ubuntu_image: skipping download as the local image found."
    echo $downloaded_file
    return
  fi
  mkdir -p $downloads_folder
  wget --append-output ${log_file} -P $downloads_folder $ubuntu_iso_url
  echo $downloaded_file
  log_detailed "download_ubuntu_image: finish (version=${version}, downloads_folder=${downloads_folder})"
}
################################################################################
# mounts live file system so that the changes for adding sca and related tools
# may be performed.
#
# - mounts iso file at $iso_image_file to $iso_image_mount_folder argument
# value as the mount point,
# - copies it's contnent to $iso_image_sca_folder
# - unmounts the iso file
# - then, depending on -no-cache-squashfs flag
# if set:
#  - unpacks the live_filesystem_image to the provided live_filesystem_folder.
# if not set: (default)
# - mounts the $live_filesystem_image under $live_filesystem_readonly_folder
# - makes a squashfs file $live_file_system_squashfs_cache_file for the folders we
# do not modify.
# - copies the etc, opt and usr/local/bin from $live_filesystem_readonly_folder
# into $live_filesystem_folder
# - umounts the squashfs file
#
# in the end of the method run, the $live_filesystem_folder is availible for further
# modifications of content upon which one can create the final sca iso image archive.
# the final sca iso image creation is performed in one of the two following ways
# depending on the no_cache_squashfs flag:
# - attaching the $live_filesystem_folder to the
#   $live_file_system_squashfs_cache_file based $live_filesystem_image_file
#   in case cache was used (no_cache_squashfs = false),
# - or by compressing the content of the $live_filesystem_folder into a
#   $live_filesystem_image (no_cache_squashfs = true)
#
# the default (no_cache_squashfs = false) method is quicker in subsequent runs
# for the same ubuntu_version_id as the operation of mksquashfs for the whole
# iso takes a while, and by cache-ing this fixed squashfs file for multiple use
# we speed up the sca image iso creation.
#
# parameters:
# - iso_image_file          - file name of the iso image
# - iso_image_mount_folder  - the folder under which to mount the original iso
#                             image
# - iso_image_sca_folder    - the folder name under which to construct the
#                             modified iso image that includes sca
# - live_filesystem_folder  - the folder name under which to expose the mounted
#                             ubuntu live runtime file system
# - live_filesystem_image   -
# - no_cache_squashfs       -
# - downloads_folder        -
#
# NOTE: this function requires sudo priviledges in order to mount the filesystems
#
# example call:
#
# sudo mount_live_filesystem ~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.iso \
#     ~/.sca/iso_image/ ~/.sca/iso_image_sca/ ~/.sca/live_filesystem/ \
#     ~/.sca/iso_image_sca/casper/filesystem.squashfs
#
mount_live_filesystem() {
  local iso_image_file=$1
  local iso_image_mount_folder=$2
  local iso_image_sca_folder=$3
  local live_filesystem_folder=$4
  local live_filesystem_image=$5
  local no_cache_squashfs=$6
  local no_cache_iso=$7
  local downloads_folder=$8

  log_detailed "mount_live_filesystem: start (iso_image_file=${iso_image_file}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_image=${live_filesystem_image})"
  # check if live_filesystem_folder exists. if so, use the existing folder
  if [ -d ${live_filesystem_folder} ]; then
    log_detailed "mount_live_filesystem: the live_filesystem folder ${live_filesystem_folder} exists. assuming you want to use that."
    log_detailed "mount_live_filesystem: finish"
    return
  fi
  # check if iso image has already been mounted. if so, use existing mount
  if mount | grep ${iso_image_mount_folder} > /dev/null; then
    log_detailed "mount_live_filesystem: iso image folder ${iso_image_mount_folder} is already mounted to an iso image. using existing mount."
  else
    log_detailed "mount_live_filesystem: mounting iso image at ${iso_image_mount_folder}."
    # prepare the folder in which we will mount the downloaded iso image
    mkdir -p $iso_image_mount_folder
    # mount the iso image at the iso_image_mount_folder location
    sudo mount -r -t iso9660 $iso_image_file $iso_image_mount_folder
  fi
  # check if the iso_image_sca folder exists and contains the iso content
  if [ -d ${iso_image_sca_folder} ] && [ -d ${iso_image_sca_folder}isolinux ]; then
    log_detailed "mount_live_filesystem: iso_image_sca_folder - ${iso_image_sca_folder} already exists. using that one."
  else
    log_detailed "mount_live_filesystem: copying iso image content to a working copy at iso_image_sca_folder - ${iso_image_sca_folder}."
    # copy the original iso image folder to iso_image_sca_folder
    # we perform this as iso9660 images are always mounted read only so in order
    # to create a new iso, we copy it aside, modify it, then recreate an iso file
    mkdir -p ${iso_image_sca_folder}
    sudo rsync -a ${iso_image_mount_folder} ${iso_image_sca_folder}
  fi
  sudo umount $iso_image_mount_folder
  sudo rm -rf $iso_image_mount_folder
  [ $no_cache_iso = true ] && sudo rm $iso_image_file
  # we need to set the write permissions in the iso_image_sca_folder as it got
  # read-only settings from original
  sudo chmod -R +w ${iso_image_sca_folder}
  if [ $no_cache_squashfs = true ]; then
    # TODO: check use of fakeroot in order to reduce amount of sudo commands
    # unpack the squashfs into live_filesystem_folder
    # TODO: redirect output to log file
    sudo unsquashfs -d ${live_filesystem_folder} ${live_filesystem_image}
  else
    # using squashfs cache has been requested
    local live_file_system_squashfs_cache_file="$downloads_folder$(basename ${iso_image_file}).squashfs"
    local read_only_live_filesystem_folder="$(dirname ${live_filesystem_folder})/$(basename ${live_filesystem_folder})-readonly/"
    mkdir -p ${read_only_live_filesystem_folder}
    sudo mount -t squashfs ${live_filesystem_image} ${read_only_live_filesystem_folder} -o loop
    # check if the cache file exists
    if ! [ -f $live_file_system_squashfs_cache_file ]; then
      # cache file doesn't exist, so create it
      log_detailed "mount_live_filesystem: squashfs cache file not found for current iso image. making it."
      # TODO: redirect output to log file
      sudo mksquashfs ${read_only_live_filesystem_folder} $live_file_system_squashfs_cache_file -b 1024k -comp xz -Xbcj x86 -e boot etc opt usr/local/bin
    fi
    log_detailed "mount_live_filesystem: populating live_filesystem_folder."
    mkdir -p ${live_filesystem_folder}
    sudo rsync -a ${read_only_live_filesystem_folder}etc/ ${live_filesystem_folder}etc/
    sudo rsync -a ${read_only_live_filesystem_folder}opt/ ${live_filesystem_folder}opt/
    sudo umount ${read_only_live_filesystem_folder}
    rmdir ${read_only_live_filesystem_folder}
    sudo cp -f $live_file_system_squashfs_cache_file $live_filesystem_image
  fi
  log_detailed "mount_live_filesystem finish (iso_image_file=${iso_image_file}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_image=${live_filesystem_image})"
}
################################################################################
# cleans up the
#   - live_filesystem_folder,
#   - iso_image_sca_folder,
#   - iso_image_mount_folder,
#   - downloaded_iso_image
# also unmounts the iso image and removes the mount point folder
clean_up_live_usb_intermediary_files () {
  local live_filesystem_folder=$1
  local iso_image_sca_folder=$2
  local iso_image_mount_folder=$3
  local downloaded_iso_image=$4
  local no_cache_squashfs=$5
  local no_cache_iso=$6

  log_detailed "clean_up_live_usb_intermediary_files start (downloaded_iso_image=${downloaded_iso_image}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder})"
  sudo rm -rf $live_filesystem_folder
  sudo rm -rf $iso_image_sca_folder
  # we leave only the created iso sca image
  log_detailed "clean_up_live_usb_intermediary_files finish (downloaded_iso_image=${downloaded_iso_image}, "\
    "iso_image_mount_folder=${iso_image_mount_folder}, "\
    "iso_image_sca_folder=${iso_image_sca_folder}, "\
    "live_filesystem_folder=${live_filesystem_folder})"
}
################################################################################
# performs the changes on the originaly downloaded live file system
#   - installs sca
#   - downloads repositories for offline installation
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

  log_detailed "patch_live_filesystem start ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror}, "\
    "yubikey_support=${yubikey_support}, exclude_pkcs11_support=${exclude_pkcs11_support})"
  add_sca $live_filesystem_folder $live_filesystem_sca_home_folder $test_mode $test_folder_relative $yubikey_support
  add_repos $live_filesystem_repos_folder $ubuntu_version_name $include_apt_mirror $yubikey_support
  add_sources_list $live_filesystem_folder $offline_repos_folder $ubuntu_version_name $include_apt_mirror $yubikey_support
  add_packages $live_filesystem_packages_folder $exclude_pkcs11_support $ubuntu_version_name
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
# patches the iso_image_sca so that it will boot directly into the ubuntu
# live session, without prompting the user for trying ubuntu or installing it.
patch_to_boot_into_live() {
  local iso_image_sca_folder=$1

  local isolinux_config=${iso_image_sca_folder}isolinux/isolinux.cfg
  # in file iso_image_sca/isolinux/isolinux.cfg perform two changes
  # first change - change vesamenu.c32 into live
  sudo sed -i 's/vesamenu\.c32/live/g' ${isolinux_config}
  # second change - comment out 'ui gfxboot bootlogo' line (last line)
  sudo sed -i 's/^ui gfxboot bootlogo/#ui gfxboot bootlogo/g' ${isolinux_config}
}
################################################################################
# create sca live usb iso image
#
# this method is called after performing needed changes in the original iso
# image artifacts in order to create the final iso file ready to be placed on
# usb stick.
#
# example call to mksquashfs
#
# sudo mksquashfs  /home/aharon/.sca/live_filesystem/ /home/aharon/.sca/live_filesystem_workdir/filesystem.squashfs -b 1024k -comp xz -Xbcj x86 -e boot
#
# example call to mkisofs
#
# sudo mkisofs -o ~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R  -V "Ubuntu with sca" .
#
create_live_iso() {
  local live_filesystem_folder=$1
  local live_filesystem_image=$2
  local iso_image_file=$3
  local iso_image_sca_folder=$4
  local test_mode=$5
  local no_cache_squashfs=$6

  log_detailed "create_live_iso: start ("\
    "live_filesystem_folder=${live_filesystem_folder}, live_filesystem_image=${live_filesystem_image}, "\
    "iso_image_file=${iso_image_file}, iso_image_sca_folder=${iso_image_sca_folder}, test_mode=${test_mode})"
  # we want the new file to be called the same with the original with sca
  # appended to the original name
  local test_suffix=''
  [ $test_mode == true ] && test_suffix='-test'
  local new_iso_image_file=${iso_image_file:0:${#iso_image_file}-4}.sca${test_suffix}.iso
  [ $no_cache_squashfs = true ] && sudo rm ${live_filesystem_image}
  sudo mksquashfs ${live_filesystem_folder} ${live_filesystem_image} \
    -b 1024k -comp xz -Xbcj x86 -e boot
  patch_to_boot_into_live ${iso_image_sca_folder}
  pushd .
  cd ${iso_image_sca_folder}
  sudo mkisofs \
    -o ${new_iso_image_file} \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table -J -R \
    -V "sca-usb-stick" \
    -input-charset utf-8 \
    .
  popd
  sudo isohybrid ${new_iso_image_file}
  print_sca_disk_image_help ${new_iso_image_file}
  log_detailed "create_live_iso: finish ("\
    "live_filesystem_folder=${live_filesystem_folder}, live_filesystem_image=${live_filesystem_image}, "\
    "iso_image_file=${iso_image_file}, iso_image_sca_folder=${iso_image_sca_folder}, test_mode=${test_mode})"
}
print_sca_disk_image_help() {
  local new_iso_image_file=$1

  echo "insert the usb stick, determine which device it is /dev/sd[a|b|c|d|e|f] ( in below case it is /dev/sdc ) then type:"
  echo "sudo umount /dev/sdb1"
  echo "sudo dd bs=4M if=${new_iso_image_file} of=/dev/sdb conv=fdatasync"
}
################################################################################
#
add_repos() {
  local live_filesystem_repos_folder=$1
  local ubuntu_version_name=$2
  local include_apt_mirror=$3
  local yubikey_support=$4

  log_detailed "add_repos: start ("\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror}"\
    "yubikey_support=${yubikey_support})"
  if [ $yubikey_support != true ] && [ $include_apt_mirror != true ]; then
    log_detailed "add_repos: neither yubikey support nor inclusion of apt-mirror had been requested. skipping addition of repositories to the image alltogether."
    return
  fi
  # TODO: change il.archive.ubuntu.com to a more generic location - probably archive.ubuntu.com would work ?
  local apt_mirror_lines=''
  [ $include_apt_mirror == true ] && apt_mirror_lines='
  deb http://il.archive.ubuntu.com/ubuntu '${ubuntu_version_name}' main restricted
  deb http://il.archive.ubuntu.com/ubuntu '${ubuntu_version_name}'-security main restricted
  deb http://il.archive.ubuntu.com/ubuntu '${ubuntu_version_name}'-updates main restricted
  '
  local yubico_mirror_lines=''
  if [ $yubikey_support = true ]; then
    yubico_mirror_lines='
deb http://ppa.launchpad.net/yubico/stable/ubuntu '${ubuntu_version_name}' main
'
  fi
  if [ -d ${live_filesystem_repos_folder} ]; then
    log_detailed "skipping mirroring of apt repositories as the ${live_filesystem_repos_folder} folder exists."
    return
  fi
  sudo mkdir -p ${live_filesystem_repos_folder}
  sudo chown apt-mirror.apt-mirror ${live_filesystem_repos_folder}
  # selected ubuntu version
  local mirror_list="
  set base_path       ${live_filesystem_repos_folder}
  set run_postmirror  0
  set nthreads        20
  set _tilde          0
  ${apt_mirror_lines}
  ${yubico_mirror_lines}
  clean               http://archive.ubuntu.com/ubuntu
  "
  [ -f /etc/apt/mirror.list.sca.bak ] && sudo rm /etc/apt/mirror.list.sca.bak
  [ -f /etc/apt/mirror.list ] && sudo cp /etc/apt/mirror.list /etc/apt/mirror.list.sca.bak
  local create_mirror_list_command="echo \"${mirror_list}\" > /etc/apt/mirror.list"
  sudo bash -c "${create_mirror_list_command}"
  echo "this may take a while..."
  eval sudo -iu apt-mirror apt-mirror ${redirect_output}
  if [ $? != 0 ] ; then error "apt-mirror failed. check configuration." 1; fi
  [ -f /etc/apt/mirror.list.sca.bak ] && sudo cp /etc/apt/mirror.list.sca.bak /etc/apt/mirror.list

  if [ $yubikey_support = true ]; then
    local yubico_key_id=$(2>/dev/null apt-key list | grep -A 3 yubico | tail -n 1 -c 10 |  tr -d '[:space:]')
    local yubico_public_key=$(2>/dev/null apt-key export ${yubico_key_id})
    log_detailed "add_repos: yubico_key_id='$yubico_key_id'"
    log_detailed "add_repos: yubico_public_key='$yubico_public_key'"
    local yubico_public_key_file="${live_filesystem_repos_folder}yubico.gpg"
    log_detailed "add_repos: yubico_public_key_file='$yubico_public_key_file'"
    sudo bash -c "echo \"${yubico_public_key}\">\"${yubico_public_key_file}\""
    sudo chown apt-mirror.apt-mirror "${yubico_public_key_file}"
    log_detailed "add_repos: file content $(cat ${yubico_public_key_file})"
  fi

  log_detailed "add_repos: finish ("\
    "live_filesystem_repos_folder=${live_filesystem_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, include_apt_mirror=${include_apt_mirror}"\
    "yubikey_support=${yubikey_support})"
}
################################################################################
# adds sca to live_filesystem_folder so it will be available in offline boot
#
# parameters
#   - live_filesystem_folder  - the location of the working version of live
#                               filesystem that is being patched with sca
#   - live_filesystem_sca_home_folder         - the location of sca home within the
#                               live_filesystem_folder
# example call:
#
#   add_sca ~/.sca/live_filesystem/ ~/.sca/live_filesystem/root/.sca/
#
add_sca() {
  local live_filesystem_folder=$1
  local live_filesystem_sca_home_folder=$2
  local test_mode=$3
  local test_folder_relative=$4
  local yubikey_support=$5

  log_detailed "add_sca: start (live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "test_mode=${test_mode}, test_folder_relative=${test_folder_relative})"
  local sca_bin_folder=${live_filesystem_folder}opt/sca/bin/
  local sca_completion_folder=${live_filesystem_folder}etc/bash_completion.d/
  local sca_config_folder=${live_filesystem_folder}etc/ssl/sca/
  sudo mkdir -p ${sca_config_folder}
  sudo mkdir -p ${sca_bin_folder}
  sudo cp ~/bin/sca $sca_bin_folder
  sudo cp ~/bin/sca_completion ${sca_completion_folder}/sca
  sudo cp ~/.sca/config/* $sca_config_folder
  local yubikey_parameter=""
  local yubikey_apt_key_import=""
  if [ $yubikey_support = true ]; then
    yubikey_parameter="--yubikey-support"
    yubikey_apt_key_import="sudo bash -c \\\"cat /opt/sca/apt-mirror/yubico.gpg | apt-key add -\\\""
  fi
  local start_tests_command=""
  # TODO: check if need to alter the copied online config for offline scenario,
  if [ $test_mode = true ]; then
    start_test_commands='
    (
echo o
echo n
echo p
echo 1
echo
echo
echo w
) | sudo fdisk /dev/sdb
    sudo mkfs.ext4 /dev/sdb1
    mkdir -p ~/.sca/'${test_folder_relative}'
    sudo mount /dev/sdb1 ~/.sca/'${test_folder_relative}'
    sudo chown -R ubuntu.ubuntu ~/.sca/'${test_folder_relative}'
    sca -d test --air-gapped 2>&1 >> ~/.sca/log
    cp ~/.sca/log ~/.sca/'${test_folder_relative}'
    sync
    sudo shutdown now
  '
  fi

  local profile_content='
  if ! [ -d \"\$HOME/.sca\" ]; then
    '"$yubikey_apt_key_import"'
    sudo apt-get update
    mkdir -p \"\$HOME/.sca/config\"
    cp /etc/ssl/sca/* ~/.sca/config/
    /opt/sca/bin/sca -d install --air-gapped '$yubikey_parameter'
  fi

  # set PATH so it includes user private bin if it exists
  if [ -d \"\$HOME/bin\" ] ; then
      PATH=\"\$HOME/bin:\$PATH\"
  fi
  '"${start_test_commands}"

  local profile_file=${live_filesystem_folder}etc/profile.d/sca.sh
  local create_profile_command="echo \"${profile_content}\" > ${profile_file}"
  sudo bash -c "${create_profile_command}"
  log_detailed "add_sca: profile_content $profile_content"
  log_detailed "add_sca: create_profile_command $(echo \"$create_profile_command\")"
  log_detailed "add_sca: profile_file $(cat $profile_file)"
  log_detailed "add_sca: finish (live_filesystem_folder=${live_filesystem_folder}, "\
    "live_filesystem_sca_home_folder=${live_filesystem_sca_home_folder}, "\
    "test_mode=${test_mode}, test_folder=${test_folder})"
}
################################################################################
# configures the offline environment to install packages from local apt-mirror
#
# parameters
#   - live_filesystem_folder  - the location of the working version of live
#                               filesystem that is being patched with sca
#   - offline_repos_folder    - the absoute path in offline environment to
#                               apt-mirror
#
# example call:
#
# add_sources_list ~/.sca/live_filesystem/ /root/.sca/apt-mirror/
#
add_sources_list() {
  local live_filesystem_folder=$1
  local offline_repos_folder=$2
  local ubuntu_version_name=$3
  local include_apt_mirror=$4
  local yubikey_support=$5

  log_detailed "add_sources_list: start ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, "\
    "include_apt_mirror=${include_apt_mirror}, yubikey_support=${yubikey_support})"
  if [ $include_apt_mirror != true ] && [ $yubikey_support != true ]; then
    log_detailed "neither apt-mirror nor yubikey support was requested. skipping adding to sources list alltogether."
    return
  fi

  local apt_mirror_lines=''
  if [ $include_apt_mirror == true ]; then
    apt_mirror_lines='
    deb file://'${offline_repos_folder}'mirror/il.archive.ubuntu.com/ubuntu/ '${ubuntu_version_name}' main restricted
    deb file://'${offline_repos_folder}'mirror/il.archive.ubuntu.com/ubuntu/ '${ubuntu_version_name}' main restricted
    deb file://'${offline_repos_folder}'mirror/il.archive.ubuntu.com/ubuntu/ '${ubuntu_version_name}'-security main restricted
    deb file://'${offline_repos_folder}'mirror/il.archive.ubuntu.com/ubuntu/ '${ubuntu_version_name}'-updates main restricted
    '
  fi
  local yubikey_lines=''
  if [ $yubikey_support == true ]; then
    yubikey_lines='
    deb file://'${offline_repos_folder}'mirror/ppa.launchpad.net/yubico/stable/ubuntu/ '${ubuntu_version_name}' main
    '
  fi
  local sources_list=${apt_mirror_lines}${yubikey_lines}
  local sources_list_file=${live_filesystem_folder}etc/apt/sources.list
  local sources_list_folder=$(dirname $sources_list_file)
  if [ -f $sources_list_file ]; then
    sudo mv $sources_list_file $sources_list_file.orig
  fi
  sudo chmod +w $sources_list_folder
  echo "${sources_list}" >~/.sca/temp
  sudo mv ~/.sca/temp ${sources_list_file}
  sudo chmod -w $sources_list_folder



  log_detailed "add_sources_list: finish ("\
    "live_filesystem_folder=${live_filesystem_folder}, "\
    "offline_repos_folder=${offline_repos_folder}, "\
    "ubuntu_version_name=${ubuntu_version_name}, "\
    "include_apt_mirror=${include_apt_mirror}, yubikey_support=${yubikey_support})"
}
################################################################################
# adds cruicial packages to live distribution so they will be available in
# offline use
#
# parameters
#   - live_filesystem_packages_folder   -
#
# example call
#   add_packages ~/.sca/packages/ ~/.sca/live_filesystem/root/.sca/packages/ ~/.sca/log
#
add_packages() {
  local live_filesystem_packages_folder=$1
  local exclude_pkcs11_support=$2
  local ubuntu_version_name=$3

  log_detailed "add_packages: start ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support})"

  # TODO: implement resolving of all packages required to install by usage of below command:
  #
  # apt-get download $(apt-rdepends opensc|grep -v "^ "|grep -v "libc-dev"| grep -v "debconf-2.0")
  #
  # (command number 1)
  #
  # it downloads a package along with all dependency packages including those
  # installed in the system that runs that command and places them into the current folder.
  #
  # ideally, we want to substract from this list all those packages that are
  # pre-installed in the distribution in order not to duplicate the files
  #
  # on the other hand, we do not opt-in for those commands here:
  #
  #  aptitude clean
  #  aptitude --download-only install <your_package_here>
  #   cp /var/cache/apt/archives/*.deb <your_directory_here>
  #
  # (commands number 2)
  # as they would skip downloading of the files already present on host machine
  #
  # so, to know for sure what packages need to be added in order to be able to install
  # particular package, one has to:
  #
  # 1 create a temporary disk image to hold downloaded packages
  # 2. create a temporary boot iso image, based on the original iso image version
  # in such way so it will :
  #   2.1 mount the image
  #   2.2 download all needed dependencies using the above (commands number 2).
  #   2.3 shutdown
  # 3. mount the temporary disk image and copy the downloaded packages to downloads folder
  # 4. unmont the temporary disk image and remove it
  #
  # another approach would be to query the url https://pkgs.org/download/<package name>
  # and extract from there which package shall be downloaded for the given os version

  sudo mkdir -p ${live_filesystem_packages_folder}
  [ $exclude_pkcs11_support != true ] && download_pkcs11_packages $live_filesystem_packages_folder $ubuntu_version_name
  download_datefudge_packages $live_filesystem_packages_folder $ubuntu_version_name
  log_detailed "add_packages: finish ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder}, "\
    "exclude_pkcs11_support=${exclude_pkcs11_support})"
}
download_pkcs11_packages() {
  local live_filesystem_packages_folder=$1
  local ubuntu_version_name=$2

  log_detailed "download_pkcs11_packages: start ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder})"

  download_package_with_dependencies $live_filesystem_packages_folder $ubuntu_version_name "opensc"

  download_package_with_dependencies $live_filesystem_packages_folder $ubuntu_version_name "libccid"

  download_package_with_dependencies $live_filesystem_packages_folder $ubuntu_version_name "pcscd"

  # pkcs11prov.so must be pre-staged in the packages folder (built from source on online machine)

  log_detailed "download_pkcs11_packages: finish ("\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder})"

}
################################################################################
#
download_datefudge_packages() {
  local live_filesystem_packages_folder=$1
  local ubuntu_version_name=$2
  log_detailed "download_datefudge_packages: start (live_filesystem_packages_folder=${live_filesystem_packages_folder})"
  download_package_with_dependencies $live_filesystem_packages_folder $ubuntu_version_name "datefudge"
  log_detailed "download_datefudge_packages: finish (live_filesystem_packages_folder=${live_filesystem_packages_folder})"
}
download_package_with_dependencies() {
  local live_filesystem_packages_folder=$1
  local ubuntu_version_name=$2
  local package_name=$3

  log_detailed "download_package_with_dependencies: started (live_filesystem_packages_folder='$live_filesystem_packages_folder', ubuntu_version_name='$ubuntu_version_name', package_name='$package_name')"
  local depending_packages=$(apt-rdepends ${package_name}|grep -v "^ "|grep -v "libc-dev"| grep -v "debconf-2.0" | tr "\n" " ")
  local depending_packages_array=($depending_packages)
  for depending_package_name in "${depending_packages_array[@]}"
  do
    local download_url=$(get_package_download_url "${depending_package_name}" "${ubuntu_version_name}")
    log_detailed "download_package_with_dependencies: downloading '$depending_package_name'"
    [ ! -z $download_url ] && download_package $download_url ${live_filesystem_packages_folder}
  done
  log_detailed "download_package_with_dependencies: started (live_filesystem_packages_folder='$live_filesystem_packages_folder', ubuntu_version_name='$ubuntu_version_name', package_name='$package_name')"
}
################################################################################
# downloads package from the given url if not already present localy.
#
download_package() {
  local package_url=$1
  local live_filesystem_packages_folder=$2


  log_detailed "download_package: start (package_url=${package_url}, "\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder})"
  local wget_options=""
  # extract the protocol
  local proto="$(echo ${package_url} | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  # remove the protocol
  local url="$(echo ${package_url/$proto/})"
  # extract the user (if any)
  local user="$(echo $url | grep @ | cut -d@ -f1)"
  # extract the host
  local host="$(echo ${url/$user@/} | cut -d/ -f1)"
  # by request - try to extract the port
  local port="$(echo $host | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
  # extract the path (if any)
  local path="$(echo $url | grep / | cut -d/ -f2-)"
  # extract the last part of the path
  local file=$(basename ${path})
  # construct the full path file name of the package file to be downloaded
  local full_downloaded_file_name=${live_filesystem_packages_folder}${file}
  # check if the file already exist
  if [ -f $full_downloaded_file_name ]; then
    log_detailed "the package file already exists locally. skipping the download."
    log_detailed "download_package: finish"
    return
  fi
  [ $verbosity == vv* ] && $wget_options="--append-output ${log_file}"
  sudo wget ${wget_options} -P ${live_filesystem_packages_folder} ${package_url}
  log_detailed "download_package: finish (package_url=${package_url}, "\
    "live_filesystem_packages_folder=${live_filesystem_packages_folder})"
}
################################################################################
# resolves the package name with version given package name (without version)
# and ubuntu version name using https://packages.ubuntu.com/
get_package_download_url() {
  local package_name=$1
  local ubuntu_version_name=$2
  # TODO: add support for additional architectures like arm64
  local architecture="amd64"
  local url="https://packages.ubuntu.com/${ubuntu_version_name}/${architecture}/${package_name}/download"
  curl --silent ${url} | grep -o "http://mirrors.kernel.org/ubuntu/pool/[^\"]*"
}
