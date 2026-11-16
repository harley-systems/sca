################################################################################
# echoes the debian multiarch triplet of this host, such as x86_64-linux-gnu,
# derived from uname -m. libraries such as opensc-pkcs11.so are installed
# under /usr/lib/<triplet>/ on debian and ubuntu.
host_multiarch_triplet() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64 )
      echo "x86_64-linux-gnu"
      ;;
    aarch64|arm64 )
      echo "aarch64-linux-gnu"
      ;;
    armv7l|armv6l )
      echo "arm-linux-gnueabihf"
      ;;
    * )
      echo "${machine}-linux-gnu"
      ;;
  esac
}
################################################################################
# echoes the folders searched for pkcs#11 libraries, one per line, in the order
# they are searched. only this host's multiarch folder is searched, so a
# library built for another architecture is never picked.
pkcs11_library_search_dirs() {
  echo "/usr/lib/$(host_multiarch_triplet)"
  echo "/usr/lib64"
  echo "/usr/lib"
  echo "/usr/local/lib"
  echo "/opt/homebrew/lib"
  echo "${HOME}/.nix-profile/lib"
  echo "/run/current-system/sw/lib"
}
################################################################################
# echoes the full path of a pkcs#11 library: the first of the search folders
# holding it as <relative_path>, <relative_path>.<version> or, for a .so, as a
# .dylib. if none holds it, echoes /usr/lib/<triplet>/<relative_path> and
# returns 1.
#
# parameters
#   relative_path - the library path below a lib folder, such as
#                   engines-3/pkcs11.so or libykcs11.so
find_pkcs11_library() {
  local relative_path=$1
  local dir candidate
  while IFS= read -r dir; do
    for candidate in "${dir}/${relative_path}" "${dir}/${relative_path}".*; do
      if [ -f "${candidate}" ]; then
        echo "${candidate}"
        return 0
      fi
    done
    if [[ "${relative_path}" == *.so ]] && [ -f "${dir}/${relative_path%.so}.dylib" ]; then
      echo "${dir}/${relative_path%.so}.dylib"
      return 0
    fi
  done < <(pkcs11_library_search_dirs)
  echo "/usr/lib/$(host_multiarch_triplet)/${relative_path}"
  return 1
}
################################################################################
# fails unless the library named by the given setting exists, naming the
# missing path and the setting to fix in the message
#
# parameters
#   setting - the name of the config setting holding the library path, such
#             as opensc_pkcs11_module
require_pkcs11_library() {
  local setting=$1
  local library="${!setting}"
  local description="${setting//_/ }" package="it"
  case "${setting}" in
    opensc_pkcs11_module ) description="opensc PKCS#11 module"; package="opensc" ;;
    ykcs11_module ) description="ykcs11 PKCS#11 module"; package="yubico-piv-tool" ;;
    pkcs11_engine ) description="PKCS#11 engine"; package="libengine-pkcs11-openssl" ;;
  esac
  if [ ! -f "${library}" ]; then
    error "${description} not found at '${library}'. install ${package} and set ${setting} in ${config_file:-~/.sca/config/sca.config} to its full path." 1
  fi
}
