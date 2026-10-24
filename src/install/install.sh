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
  # the sca usb stick only carries the packages requested when it was created,
  # so all of them are installed
  install_packages_offline $packages_folder
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
  [ $yubikey_support == true ] && install_yubico_piv_tool
  install_iso_image_tools
  log_detailed "install_online: finish (force=${force}, "\
"yubikey_support=${yubikey_support}, "\
"exclude_pkcs11_support=${exclude_pkcs11_support}, "\
"sca_script_file_name=${sca_script_file_name})"
}
###############################################################################
# we use xorriso for creating the hybrid bios and uefi sca iso image,
# squashfs-tools for reading and packing ubuntu live filesystem layers
# (unsquashfs and mksquashfs), apt-mirror for mirroring apt repositories and
# qemu for running the sca usb stick image in sca test
#
install_iso_image_tools() {
  log_detailed "install_iso_image_tools: start"
  install_package_from_repos squashfs-tools
  install_package_from_repos xorriso
  install_package_from_repos qemu-system-x86
  install_package_from_repos qemu-utils
  install_package_from_repos apt-mirror
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
install_datefudge_packages_online() {
  log_detailed "install_coinstall_datefudge_packages_onlinere_online: start"
  install_package_from_repos datefudge
  log_detailed "install_datefudge_packages_online: finish"
}
################################################################################
# builds and installs pkcs11-provider from source (required for OpenSSL 3
# provider API). the pkcs11-provider package is not available in standard
# Ubuntu repos, so we build from the latchset/pkcs11-provider GitHub project.
install_pkcs11_provider_from_source() {
  local version="${1:-v1.1.0}"
  local provider_target="/usr/lib/x86_64-linux-gnu/engines-3/pkcs11prov.so"

  # Skip if already installed
  if [ -f "$provider_target" ]; then
    log_detailed "install_pkcs11_provider_from_source: pkcs11prov.so already present at $provider_target"
    return 0
  fi

  log_detailed "install_pkcs11_provider_from_source: building pkcs11-provider $version from source"

  # Build dependencies
  install_package_from_repos meson
  install_package_from_repos pkg-config
  install_package_from_repos libssl-dev
  install_package_from_repos gcc

  local build_dir=$(mktemp -d /tmp/pkcs11-provider-build.XXXXXX)
  git clone --depth 1 --branch "$version" \
    https://github.com/latchset/pkcs11-provider.git "$build_dir/pkcs11-provider"
  cd "$build_dir/pkcs11-provider"
  meson setup builddir
  meson compile -C builddir

  # Install the provider .so to the OpenSSL engines directory
  sudo cp builddir/src/pkcs11.so "$provider_target"
  sudo chmod 644 "$provider_target"

  cd - > /dev/null
  rm -rf "$build_dir"

  log_detailed "install_pkcs11_provider_from_source: installed pkcs11prov.so to $provider_target"
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
  install_package_from_repos pkcs11-provider
  log_detailed "install_pkcs11_packages_online: finish"
}
################################################################################
# installs all the packages bundled on the sca usb stick in offline mode
#
# the packages folder holds the requested packages along with the dependencies
# the live session is missing, so they are installed together in one go.
install_packages_offline() {
  local packages_folder=$1

  log_detailed "install_packages_offline: start (packages_folder=${packages_folder})"
  local redirect_output='> /dev/null'
  [[ $verbosity == vv* ]] && redirect_output=">> ${log_file}"
  local deb_files=(${packages_folder}*.deb)
  if ! [ -f "${deb_files[0]}" ]; then
    log_detailed "install_packages_offline: no packages found in ${packages_folder}. assuming sca usb stick was created without them and skipping installation."
    return
  fi
  eval sudo apt-get install -y --no-install-recommends ${deb_files[*]} ${redirect_output}
  if [ $? != 0 ]; then error "failed installing the packages from ${packages_folder}." 1; fi
  log_detailed "install_packages_offline: finish (packages_folder=${packages_folder})"
}
################################################################################
# installs the yubikey tools in online mode, from the ubuntu archive
#
# we use yubico piv tool for managing yubikey credentials and storing
# certificates and keys into the device, ykcs11 for accessing the yubikey with
# pkcs11, yubikey-manager (ykman) for identifying the yubikey and gnupg with
# scdaemon for the yubikey openpgp applet.
install_yubico_piv_tool() {
  log_detailed "install_yubico_piv_tool: start"
  install_package_from_repos yubico-piv-tool
  install_package_from_repos ykcs11
  install_package_from_repos yubikey-manager
  install_package_from_repos gnupg
  install_package_from_repos scdaemon
  log_detailed "install_yubico_piv_tool: finish"
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
