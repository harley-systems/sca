################################################################################
# performs tests
test() {
  local mode=online
  local skip_offline=false

  local OPTS=`getopt -o has --long help,air-gapped,skip-air-gapped-tests -n 'sca test' -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca test -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        test_help
        return
        ;;
      -a | --air-gapped )
        mode=offline
        shift
        ;;
      -s | --skip-air-gapped-tests )
        skip_offline=true
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

  log_detailed "test: start (mode=${mode})"

  # array of all valid ubuntu version ids declared
  local valid_ubuntu_version_ids=("18.04.1-bionic" "16.04.4-xenial"
    "16.04.3-xenial" "16.04.2-xenial" "16.04.1-xenial" "14.04.5-trusty"
    "14.04.4-trusty" "14.04.3-trusty" "14.04.2-trusty" "14.04.1-trusty")
  # use ubuntu version id specified below for the offline environment on sca usb
  # stick
  local ubuntu_version_id=${1:-"18.04.1-bionic"}
  # check if valid ubuntu version id was supplied
  if [[ ! " ${valid_ubuntu_version_ids[@]} " =~ " ${ubuntu_version_id} " ]]; then
    error "test: invalid ubuntu version id was provided. please, run sca test -h to see more info." 1
  fi
  # extract the version number as all text preceeding the first - character
  local ubuntu_version_number=${ubuntu_version_id%%-*}

  #
  local test_folder=~/.sca/test/

  mkdir -p $test_folder

  if [ $mode = offline ]; then
    tests_offline $test_folder
  else
    tests_online $test_folder
    if [ $skip_offline = false ]; then
      #
      local test_data_disk_image=${test_folder}sca-test-disk.img
      #
      local test_iso_file=$(get_iso_filename_from_version_number $ubuntu_version_number test)
      #
      local downloads_folder=~/.sca/downloads/
      #
      local test_iso_fullname=${downloads_folder}${test_iso_file}
      air_gapped_test $test_folder $test_iso_fullname $test_data_disk_image
    fi
  fi

  log_detailed "test: finish"
}
test_help() {
  echo '
@@@HELP@@@
'
}
################################################################################
# tests ran in both online and offline environments
tests_common() {
  local test_folder=$1
  # dummy test run
  init demo

}
################################################################################
#
tests_online() {
  local test_folder=$1

  log_detailed "tests_online: start (test_folder=${test_folder})"
  tests_common $test_folder
  # TODO: implement method

  log_detailed "tests_online: finish (test_folder=${test_folder})"
}
################################################################################
#
tests_offline() {
  local test_folder=$1

  log_detailed "tests_offline: start (test_folder=${test_folder})"
  tests_common $test_folder
  # TODO: implement method

  log_detailed "tests_offline: finish (test_folder=${test_folder})"
}
air_gapped_test() {
  local test_folder=$1
  local test_iso_image=$2
  local test_disk_image=$3

  log_detailed "air_gapped_test: start (test_folder=${test_folder}, test_iso_image=${test_iso_image}, test_disk_image=${test_disk_image})"
  create_offline_disks_images $test_disk_image
  run_offline_tests $test_folder $test_iso_image $test_disk_image
  print_offline_test_results
  remove_test_images
  log_detailed "air_gapped_test: start (test_folder=${test_folder})"
}
################################################################################
# creates the two offline disks images - one is a variant of sca usb stick image
# and the second one is
create_offline_disks_images() {
  local test_disk_image_file=$1

  log_detailed "create_offline_disks_images: start ("\
    "test_disk_image_file=${test_disk_image_file})"
  [ -f $test_disk_image_file ] && rm $test_disk_image_file
  qemu-img create $test_disk_image_file 10M
  init_sca_usb_stick --yubikey-support --test-image
  log_detailed "create_offline_disks_images: finish ("\
    "test_disk_image_file=${test_disk_image_file})"
}
################################################################################
# run offline tests by spinning up a simulation
# the simulation consists of booting a virtual machine disconnected from network
# from sca live stick iso and attaching a test disk for storing the test results
# data.
#
# example call to quemy-system-x86_64 :
#
# sudo qemu-system-x86_64 -boot d -enable-kvm -machine q35,accel=kvm -device intel-iommu -m 2048 -cpu host -net none -hdb format=raw,file=/home/aharon/.sca/downloads/sca-disk.img /home/aharon/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.another.iso
# sudo qemu-system-x86_64 -boot d -enable-kvm -machine q35,accel=kvm -device intel-iommu -m 2048 -cpu host -net none -drive format=raw,file=/home/aharon/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso,index=0 -drive format=raw,file=/home/aharon/.sca/downloads/sca-test-disk.img,index=1
# sudo qemu-system-x86_64 -boot d -enable-kvm -machine q35,accel=kvm -device intel-iommu -m 2048 -cpu host -net none -drive format=raw,file=/home/aharon/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso,index=0
run_offline_tests() {
  local test_folder=$1
  local test_iso_image=$2
  local test_disk_image=$3

  log_detailed "run_offline_tests: start (test_folder=${test_folder}, test_iso_image=${test_iso_image} test_disk_image=${test_disk_image})"
  # TODO: replace the name of the sample test iso image below with the variable
  sudo qemu-system-x86_64 \
    -boot d \
    -enable-kvm \
    -machine q35,accel=kvm \
    -device intel-iommu \
    -m 2048 \
    -cpu host \
    -net none \
    -drive format=raw,file=${test_iso_image},index=0 \
    -drive format=raw,file=${test_disk_image},index=1

  local fdisk_test_disk_image=$(fdisk -lu ${test_disk_image})
  local bytes_in_sector=$(echo "${fdisk_test_disk_image}" | grep Units: | sed -E 's/.* ([[:digit:]]+) bytes/\1/g')
  local partition_offset_sectors=$(echo "${fdisk_test_disk_image}" | grep img1 | awk '{print $2}')
  mkdir ${test_folder}/temp/
  sudo mount -t auto -o loop,offset=$((${bytes_in_sector}*${partition_offset_sectors})) ${test_disk_image} ${test_folder}/temp/
  cat ${test_folder}/temp/log >> ${log_file}
  sudo umount ${test_folder}/temp/
  rmdir ${test_folder}/temp/
  log_detailed "run_offline_tests: finish (test_folder=${test_folder})"
}
print_offline_test_results() {
  log_detailed "print_offline_test_results: start"
  # TODO: read the results from the image and remove the image file
  log_detailed "print_offline_test_results: finish"
}
################################################################################
# removes the two temporary test images
remove_test_images() {
  log_detailed "remove_test_images: start"
  # TODO: implement the method
  log_detailed "remove_test_images: finish"
}
