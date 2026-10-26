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
  # per-check PASS/FAIL lines of this host's run and of the air-gapped guest
  local results_file=${test_folder}results.txt
  local air_gapped_results_file=${test_folder}air-gapped-results.txt

  mkdir -p "$test_folder"

  if [ "$mode" = offline ]; then
    tests_offline "$test_folder" "$results_file"
  else
    tests_online "$test_folder" "$results_file"
    if [ "$skip_offline" = false ]; then
      #
      local test_data_disk_image=${test_folder}sca-test-disk.img
      #
      local test_iso_file=$(get_iso_filename_from_version_number $ubuntu_version_number test)
      #
      local downloads_folder=~/.sca/downloads/
      #
      local test_iso_fullname=${downloads_folder}${test_iso_file}
      air_gapped_test "$test_folder" "$test_iso_fullname" "$test_data_disk_image" \
        "$ubuntu_version_id" "$air_gapped_results_file"
    fi
  fi

  local failed_checks=$(grep -c '^FAIL ' "$results_file")
  if [ "$mode" = online ] && [ "$skip_offline" = false ]; then
    if [ -f "$air_gapped_results_file" ]; then
      failed_checks=$((failed_checks + $(grep -c '^FAIL ' "$air_gapped_results_file")))
    else
      # the guest never wrote its results (e.g. the vm never booted)
      failed_checks=$((failed_checks + 1))
    fi
  fi

  log_detailed "test: finish (failed_checks=${failed_checks})"
  if [ "$failed_checks" != 0 ]; then
    error "test: ${failed_checks} check(s) failed. see ${log_file} for details." 1
  fi
}
test_help() {
  echo '
@@@HELP@@@
'
}
################################################################################
# runs a single named check and records its outcome in the results file
#
# the check runs in a subshell, so a failing sca command (error exits) fails
# only that check, and whatever the check sets up does not leak into the next
# one. its output goes to the log.
#
# parameters
#   results_file
#     file to append the "PASS <name>" or "FAIL <name>" line to
#   check_name
#     human readable name of the check
#   command...
#     the command (and its arguments) performing the check
run_check() {
  local results_file=$1
  local check_name=$2
  shift 2

  log_detailed "run_check: start (check_name=${check_name})"
  local result=FAIL
  ( "$@" ) < /dev/null >> "${log_file}" 2>&1 && result=PASS
  echo "${result} ${check_name}" | tee -a "$results_file"
  log_detailed "run_check: finish (check_name=${check_name}, result=${result})"
}
################################################################################
# the demo must never touch the user's configuration or hardware security keys
test_isolate_demo() {
  local test_folder=$1
  export ca_use_security_key=false
  export subca_use_security_key=false
  export user_use_security_key=false
  export host_use_security_key=false
  export service_use_security_key=false
  # init demo persists "config set" into the config file, so give it a copy
  if [ -f "${config_file}" ]; then
    cp "${config_file}" "${test_folder}sca.config"
    config_file=${test_folder}sca.config
  fi
}
check_init_demo() {
  local test_folder=$1
  local demo_folder=${test_folder}demo/
  test_isolate_demo "$test_folder"
  rm -rf "$demo_folder"
  # init demo reports most failures on stderr only, so confirm the end result
  init demo "$demo_folder" &&
    ls "${demo_folder}"user-key/*/*/services/*/*-crt.pem > /dev/null
}
# issues a service certificate as the demo subca and verifies it against the
# demo ca chain
check_service_crt() {
  local test_folder=$1
  local demo_folder=${test_folder}demo/
  test_isolate_demo "$test_folder"
  init_demo_switch_to subca "$demo_folder"
  export service=sca-test
  config resolve
  rm -f "${service_key_file}" "${service_csr_file}" "${service_crt_file}"
  create key service &&
    create csr service &&
    create crt service &&
    openssl verify -CAfile "${ca_crt_file}" -untrusted "${subca_crt_file}" "${service_crt_file}"
}
check_openssl_version() {
  local version=$(openssl version | awk '{print $2}')
  echo "openssl version ${version}"
  [ "${version%%.*}" -ge 3 ] 2> /dev/null
}
# checks all given files exist
check_files_exist() {
  local file
  for file in "$@"; do
    echo "checking ${file}"
    [ -f "$file" ] || return 1
  done
}
check_pcscd_installed() {
  command -v pcscd || [ -x /usr/sbin/pcscd ]
}
################################################################################
# tests ran in both online and offline environments
tests_common() {
  local test_folder=$1
  local results_file=$2

  : > "$results_file"
  run_check "$results_file" "init demo completes" \
    check_init_demo "$test_folder"
  run_check "$results_file" "service key/csr/crt verifies against the demo chain" \
    check_service_crt "$test_folder"
  run_check "$results_file" "openssl version is 3 or newer" \
    check_openssl_version
  run_check "$results_file" "pkcs11 engine and opensc module exist" \
    check_files_exist "${pkcs11_engine}" "${opensc_pkcs11_module}"
  run_check "$results_file" "pcscd is installed" \
    check_pcscd_installed
  run_check "$results_file" "ykcs11 is installed" \
    check_files_exist "${ykcs11_module}"
  if command -v ykman > /dev/null; then
    run_check "$results_file" "ykman runs" ykman --version
  else
    echo "SKIP ykman is not installed" | tee -a "$results_file"
  fi
  echo "$(grep -c '^PASS ' "$results_file") passed, $(grep -c '^FAIL ' "$results_file") failed"
}
################################################################################
#
tests_online() {
  local test_folder=$1
  local results_file=$2

  log_detailed "tests_online: start (test_folder=${test_folder})"
  tests_common "$test_folder" "$results_file"
  log_detailed "tests_online: finish (test_folder=${test_folder})"
}
################################################################################
# runs inside the air-gapped guest. the test folder is the test disk, so the
# results file ends up there for the host to read.
tests_offline() {
  local test_folder=$1
  local results_file=$2

  log_detailed "tests_offline: start (test_folder=${test_folder})"
  tests_common "$test_folder" "$results_file"
  log_detailed "tests_offline: finish (test_folder=${test_folder})"
}
air_gapped_test() {
  local test_folder=$1
  local test_iso_image=$2
  local test_disk_image=$3
  local ubuntu_version_id=$4
  local air_gapped_results_file=$5

  log_detailed "air_gapped_test: start (test_folder=${test_folder}, test_iso_image=${test_iso_image}, test_disk_image=${test_disk_image}, ubuntu_version_id=${ubuntu_version_id})"
  rm -f "$air_gapped_results_file"
  create_offline_disks_images "$test_disk_image" "$ubuntu_version_id"
  run_offline_tests "$test_folder" "$test_iso_image" "$test_disk_image" "$air_gapped_results_file"
  print_offline_test_results "$air_gapped_results_file"
  remove_test_images "$test_folder" "$test_disk_image"
  log_detailed "air_gapped_test: finish (test_folder=${test_folder})"
}
################################################################################
# creates the two offline disks images - the test variant of the sca usb stick
# iso (always rebuilt, so it carries the sca being tested) and an empty disk
# the guest stores its results on. the disk is formatted here, with the label
# the guest looks for, so the guest never partitions or formats anything.
create_offline_disks_images() {
  local test_disk_image_file=$1
  local ubuntu_version_id=$2

  log_detailed "create_offline_disks_images: start ("\
    "test_disk_image_file=${test_disk_image_file}, ubuntu_version_id=${ubuntu_version_id})"
  [ -f "$test_disk_image_file" ] && rm "$test_disk_image_file"
  qemu-img create "$test_disk_image_file" 10M
  mkfs.ext4 -q -F -L "$(get_test_results_disk_label)" "$test_disk_image_file" \
    || error "could not format the test disk image ${test_disk_image_file}" 1
  init_sca_usb_stick --yubikey-support --test-image "$ubuntu_version_id"
  log_detailed "create_offline_disks_images: finish ("\
    "test_disk_image_file=${test_disk_image_file})"
}
################################################################################
# run offline tests by spinning up a simulation
# the simulation consists of booting a virtual machine disconnected from network
# from sca live stick iso and attaching a test disk for storing the test results
# data. the guest writes results.txt and its log to the test disk and powers
# off; they are then copied to the air_gapped_results_file and the log.
#
# example call to quemy-system-x86_64 :
#
# sudo qemu-system-x86_64 -boot d -enable-kvm -machine q35,accel=kvm -device intel-iommu -m 2048 -cpu host -net none -drive format=raw,file=/home/aharon/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso,index=0 -drive format=raw,file=/home/aharon/.sca/downloads/sca-test-disk.img,index=1
run_offline_tests() {
  local test_folder=$1
  local test_iso_image=$2
  local test_disk_image=$3
  local air_gapped_results_file=$4

  log_detailed "run_offline_tests: start (test_folder=${test_folder}, test_iso_image=${test_iso_image} test_disk_image=${test_disk_image})"
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

  mkdir -p "${test_folder}temp/"
  if ! sudo mount -t ext4 -o loop "${test_disk_image}" "${test_folder}temp/"; then
    log_detailed "run_offline_tests: could not mount the test disk. no results to collect."
    return
  fi
  [ -f "${test_folder}temp/results.txt" ] && cp "${test_folder}temp/results.txt" "$air_gapped_results_file"
  [ -f "${test_folder}temp/log" ] && cat "${test_folder}temp/log" >> "${log_file}"
  sudo umount "${test_folder}temp/"
  log_detailed "run_offline_tests: finish (test_folder=${test_folder})"
}
print_offline_test_results() {
  local air_gapped_results_file=$1

  log_detailed "print_offline_test_results: start"
  echo "air-gapped test results:"
  if [ -f "$air_gapped_results_file" ]; then
    cat "$air_gapped_results_file"
    echo "$(grep -c '^PASS ' "$air_gapped_results_file") passed, $(grep -c '^FAIL ' "$air_gapped_results_file") failed"
  else
    echo "FAIL no results were found on the test disk (did the vm boot and run the tests?)"
  fi
  log_detailed "print_offline_test_results: finish"
}
################################################################################
# removes the temporary test disk image and its mount folder
remove_test_images() {
  local test_folder=$1
  local test_disk_image=$2

  log_detailed "remove_test_images: start"
  rm -f "$test_disk_image"
  [ -d "${test_folder}temp/" ] && rmdir "${test_folder}temp/"
  log_detailed "remove_test_images: finish"
}
