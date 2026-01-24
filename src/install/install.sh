################################################################################
# perfoms installation of sca and it's prerequisites
#
install() {
  local mode=online
  local force=false
  local yubikey_support=false
  local exclude_pkcs11_support=false

  # local sca_script_file_name="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
  local sca_script_file_name=$0

  local OPTS=`getopt -o hafyx --long help,air-gapped,force,yubikey-support,exclude-pkcs11-support -n 'sca install' -- "$@"`
  if [ $? != 0 ] ; then \
    error "failed parsing options. use sca install -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        install_help
        return
        ;;
      -a | --air-gapped )
        mode=offline; shift;
        ;;
      -f | --force )
        force=true; shift;
        ;;
      -y | --yubikey-support )
        yubikey_support=true
        shift
        ;;
      -x | --exclude-pkcs11-support )
        exclude_pkcs11_support=true
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

  log_detailed "install: start (mode=${mode}, force=${force}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "\
"sca_script_file_name=${sca_script_file_name})"
  # if mode is not supplied, auto-detect by pinging a host?
  local packages_folder='/opt/sca/packages/'
  if [ "$mode" = 'offline' ]; then
    install_offline $packages_folder $yubikey_support $exclude_pkcs11_support $force $sca_script_file_name
  else
    install_online $force $sca_script_file_name $yubikey_support \
      $exclude_pkcs11_support
  fi
  log_detailed "install: finish (mode=${mode}, force=${force}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "\
"sca_script_file_name=${sca_script_file_name})"
}
install_help() {
  echo '
@@@HELP@@@
'
}
################################################################################
# installs sca in offline mode
#
# when offline, we assume that functionalites related to image creation are not
# to be used, so no need to install the tooling. Also, part of the tooling to
# be installed needs to be installed from locally available packages when offline.
# therefore, separate installations fof offline and online modes.
install_offline() {
  local packages_folder=$1
  local yubikey_support=$2
  local exclude_pkcs11_support=$3
  local force=$4
  local sca_script_file_name=$5

  # TODO: validate that we are in offline mode by:
  #     - pinging a host (make sure we are not online by a mistake)
  #     - checking if packages are present in expected folders, if not, assume
  #       we are not running from a sca usb stick, so show error and exit
  log_detailed "install_offline: start (packages_folder=${packages_folder}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "
  install_sca_offline $force $sca_script_file_name
  install_core_offline $packages_folder
  [ $exclude_pkcs11_support = false ] && install_pkcs11_packages_offline $packages_folder
  [ $yubikey_support = true ] && install_yubico_piv_tool offline
  log_detailed "install_offline: finish (packages_folder=${packages_folder}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "
}
################################################################################
# installs sca in online mode
#
# when online, we will need image related tooling
install_online() {
  local force=$1
  local sca_script_file_name=$2
  local yubikey_support=$3
  local exclude_pkcs11_support=$4

  log_detailed "install_online: start (force=${force}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "\
"sca_script_file_name=${sca_script_file_name})"
  install_sca_online $force $sca_script_file_name
  install_core_online
  [ $exclude_pkcs11_support != true ] && install_pkcs11_packages_online
  [ $yubikey_support == true ] && install_yubico_piv_tool online
  install_iso_image_tools
  log_detailed "install_online: finish (force=${force}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "\
"sca_script_file_name=${sca_script_file_name})"
}
###############################################################################
# we use genisoimage for mkisofs, syslinux-utils for converting the output of
# mkisofs to usb stick suitable image (isohybrid), squashfs-tools for unpacking
# and packing ubintu live filesystem (unsquashfs and mksquashfs) and apt-mirror
# for mirroring apt reposotproes
#
install_iso_image_tools() {
  log_detailed "install_iso_image_tools: start"
  install_package_from_repos squashfs-tools
  install_package_from_repos qemu-kvm
  install_package_from_repos genisoimage
  install_package_from_repos apt-mirror
  install_package_from_repos syslinux-utils
  log_detailed "install_iso_image_tools: finish"
}
################################################################################
# in online mode, sca install is used to initialize the sca configuration.
# in offline mode we do not need to do it as sca was pre-deployed on the
# sca USB stick
install_sca_online() {
  local force=$1
  local sca_script_file_name=$2

  log_detailed "install_sca_online: start (force=${force}, "\
"sca_script_file_name=${sca_script_file_name})"
  mkdir -p ~/bin/
  #[ -f ~/bin/sca ] && [ "$force" = true  ] && rm ~/bin/sca
  [ -f ~/bin/sca_completion ] && [ "$force" = true  ] && rm ~/bin/sca_completion
  if [ -f ~/bin/sca ] && [ ! $force = true ]; then
    echo "sca is already installed."
    echo "if you want to force the installation over existing, use 'sca install --force'."
    return
  fi
  [ ! $sca_script_file_name == ~/bin/sca ] && /bin/cp -f $sca_script_file_name ~/bin/sca
  chmod 755 ~/bin/sca
  completion bash > ~/bin/sca_completion
  if [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
    add_to_path_content='
    # set PATH so it includes user''s private bin if it exists
    if [ -d "$HOME/bin" ] ; then
        PATH="$HOME/bin:$PATH"
    fi
    '
    echo "${add_to_path_content}" >> ~/.bashrc
  fi
  if [ $force = true ]; then
    config_create --recreate all
  else
    config_create all
  fi
  echo "run . ~/bin/sca_completion"
  log_detailed "install_sca_online: finish (force=${force}, "\
"sca_script_file_name=${sca_script_file_name})"
}
################################################################################
# in offline mode we need to copy sca form /opt/sca/bin/ to ~/bin/
install_sca_offline() {
  local force=$1
  local sca_script_file_name=$2
  log_detailed "install_sca_offline: start (force=${force}, "\
"sca_script_file_name=${sca_script_file_name})"
  mkdir -p ~/bin/
  [ -f ~/bin/sca_completion ] && [ "$force" = true  ] && rm ~/bin/sca_completion
  if [ -f ~/bin/sca ] && [ ! $force = true ]; then
    echo "sca is already installed."
    echo "if you want to force the installation over existing, use 'sca install --force'."
    return
  fi
  [ ! $sca_script_file_name == ~/bin/sca ] && /bin/cp -f $sca_script_file_name ~/bin/sca
  chmod 755 ~/bin/sca
  if [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
    add_to_path_content='
    # set PATH so it includes user''s private bin if it exists
    if [ -d "$HOME/bin" ] ; then
        PATH="$HOME/bin:$PATH"
    fi
    '
    echo "${add_to_path_content}" >> ~/.bashrc
  fi
  log_detailed "install_sca_online: finish (force=${force}, "\
"sca_script_file_name=${sca_script_file_name})"
}
################################################################################
# core packages include key management packages
# we use datefudge package for faking the creation date of ca certificates
install_core_online() {
  log_detailed "install_core_online: start"
  install_package_from_repos openssl
  install_package_from_repos openssh-client
  install_package_from_repos datefudge
  log_detailed "install_core_online: finish"
}
install_core_offline() {
  local packages_folder=$1

  log_detailed "install_core_offline: start (packages_folder=${packages_folder})"
  # check if those packages are incuded in offline. if not, prepare a download
  # method and implement the installation here.
  # sudo apt-get install openssl openssh-client
  install_datefudge_packages_offline $packages_folder
  log_detailed "install_core_offline: finish (packages_folder=${packages_folder})"
}
install_datefudge_packages_online() {
  log_detailed "install_coinstall_datefudge_packages_onlinere_online: start"
  install_package_from_repos datefudge
  log_detailed "install_datefudge_packages_online: finish"
}
################################################################################
# installs datefudge in offline mode
#
install_datefudge_packages_offline() {
  local packages_folder=$1

  log_detailed "install_datefudge_packages_offline: start"
  local package_deb_file=$(get_available_package_version "datefudge" "$packages_folder")
  install_deb_file $package_deb_file
  log_detailed "install_datefudge_packages_offline: finish"
}
################################################################################
# installs pkcs11 related packages in online mode
# we need pkcs11 packages for openssl integration with yubikey.
install_pkcs11_packages_online() {
  log_detailed "install_pkcs11_packages_online: start"
  install_package_from_repos libengine-pkcs11-openssl
  install_package_from_repos pcscd
  install_package_from_repos libccid
  install_package_from_repos opensc-pkcs11
  install_package_from_repos opensc
  log_detailed "install_pkcs11_packages_online: finish"
}
install_pkcs11_packages_offline() {
  local packages_folder=$1

  log_detailed "install_pkcs11_packages_offline: start (packages_folder=${packages_folder})"

  local packages=("libengine-pkcs11-openssl" "libccid" "pcscd"  "opensc-pkcs11" "opensc")
  for package_name in "${packages[@]}"
  do
    local package_deb_file=$(get_available_package_version "$package_name" "$packages_folder")
    install_deb_file $package_deb_file
  done

  log_detailed "install_pkcs11_packages_offline: finish (packages_folder=${packages_folder})"
}
################################################################################
# installs yubico-piv-tool in both online and offline mode
# NOTE: we install it the same way in both modes as we mirror yubico repository
# on sca usb stick
# we use yubico piv tool for managing yubikey credentials and storing
# certificates and keys into the device.
#
# example search through installed repositories
#
# for APT in `find /etc/apt/ -name \*.list`; do \
# grep -Po "(?<=^deb\s).*?(?=#|$)" $APT | while read ENTRY ; do \
# HOST=`echo $ENTRY | cut -d/ -f3`; \
# if [ "ppa.launchpad.net" = "$HOST" ]; then \
#   USER=`echo $ENTRY | cut -d/ -f4`; \
#   PPA=`echo $ENTRY | cut -d/ -f5`; \
#   echo "${APT}: sudo apt-add-repository ppa:$USER/$PPA"; \
# else \
#   echo ${APT}: sudo apt-add-repository \'${ENTRY}\'; \
# fi \
# done \
# done
#
install_yubico_piv_tool() {
  local mode=$1

  log_detailed "install_yubico_piv_tool: start (mode=${mode})"
  # if running online, first need to add the yubico lunchpad ppa
  if [ "$mode" = "online" ]; then
    # check if sources.list already contains the yubico lunchpad registered
    local yubikey_source_installed=$(grep -r --include '*.list' '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/ | grep yubico)
    # if not, add it
    if [ -z "$yubikey_source_installed" ]; then
      sudo apt-add-repository ppa:yubico/stable
    fi
  fi
  # if running offline, the sources list has been updated for us
  install_package_from_repos yubico-piv-tool
  log_detailed "install_yubico_piv_tool: finish (mode=${mode})"
}
################################################################################
# utility function that serves as a single point for package manager
# installation execution when installing from repositories.
install_package_from_repos() {
  local package_name=$1

  log_detailed "install_package_from_repos: start (package_name=${package_name})"
  local redirect_output='2> /dev/null'
  if [[ $verbosity == vv* ]]; then redirect_output=">> ${log_file}"; else redirect_output='> /dev/null'; fi

  local package_is_ok=$(dpkg-query -W --showformat='${Status}\n' ${package_name}|grep "install ok installed")
  log_detailed "install_package_from_repos: checking if ${package_name} is installed: $package_is_ok"
  if [ "" == "$package_is_ok" ]; then
    log_detailed "install_package_from_repos: not installed, installing..."
    eval sudo apt-get install -y $package_name $redirect_output
    # sudo apt-get --force-yes --yes install $package_name
  else
    log_detailed "install_package_from_repos: already installed. skipping"
  fi
  log_detailed "install_package_from_repos: finish (package_name=${package_name})"
}
################################################################################
# utility function that serves as a single point for package manager
# installation execution when installing from deb file.
install_deb_file() {
  local deb_file=$1

  log_detailed "install_deb_file: start (deb_file=${deb_file})"
  local redirect_output='2> /dev/null'
  if [[ $verbosity == vv* ]]; then redirect_output=">> ${log_file}"; else redirect_output='> /dev/null'; fi
  if ! [ -f $deb_file ]; then
    log_detailed "deb file $deb_file not found. assuming sca usb stick was created without related support and skipping installation."
    log_detailed "install_deb_file: finish (deb_file=${deb_file})"
    return
  fi
  eval sudo apt-get install -y $deb_file $redirect_output
  log_detailed "install_deb_file: finish (deb_file=${deb_file})"
}
get_available_package_version() {
  local package_name=$1
  local packages_folder=$2

  ls -b ${packages_folder}${package_name}_*
}
