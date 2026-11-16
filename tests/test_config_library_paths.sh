#!/bin/bash
# config create: the pkcs11 engine, opensc and ykcs11 library defaults written
# to sca.config are the libraries found on this host, or their path in this
# host's /usr/lib/<triplet>/ folder. an explicit setting in sca.config still
# wins, and the signing paths name a missing opensc module and its setting.
#
# uname is stubbed to report FAKE_ARCH and the library search folders are a
# fake root, so the result does not depend on what this host has installed.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# shellcheck disable=SC2317 # called by sca
uname() {
  if [ "$1" = -m ]; then echo "${FAKE_ARCH:-x86_64}"; else command uname "$@"; fi
}
export -f uname

fake_root="$(mktemp -d "${TMPDIR:-/tmp}/sca-test-lib.XXXXXX")" || exit 2
# shellcheck disable=SC2154 # test_home is set by lib.sh
trap 'rm -rf "${test_home}" "${fake_root}"' EXIT
config="${HOME}/.sca/config/sca.config"

# run config create all from the built sca, searching only the fake root
# shellcheck disable=SC2317 # the stub is called by sca
config_create() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    pkcs11_library_search_dirs() { echo "${fake_root}"; echo "${fake_root}/second"; }
    sca config create "$@"
  )
}

# assert_line LINE MESSAGE - sca.config holds LINE
assert_line() {
  grep -qxF -- "$1" "${config}" || fail "$2: '$1' not in sca.config: $(grep _default= "${config}" | grep -i pkcs11)"
}

# (a) aarch64, nothing installed: the aarch64 multiarch paths
FAKE_ARCH=aarch64 config_create all >/dev/null 2>&1 || fail "config create all on aarch64"
assert_line "export pkcs11_engine_default=/usr/lib/aarch64-linux-gnu/engines-3/pkcs11.so" "aarch64 engine"
assert_line "export opensc_pkcs11_module_default=/usr/lib/aarch64-linux-gnu/opensc-pkcs11.so" "aarch64 opensc"
assert_line "export ykcs11_module_default=/usr/lib/aarch64-linux-gnu/libykcs11.so" "aarch64 ykcs11"

# armv7l maps to the hard float triplet
FAKE_ARCH=armv7l config_create --recreate all >/dev/null 2>&1 || fail "config create on armv7l"
assert_line "export ykcs11_module_default=/usr/lib/arm-linux-gnueabihf/libykcs11.so" "armv7l ykcs11"

# (b) x86_64, nothing installed: the lines written before this change
FAKE_ARCH=x86_64 config_create --recreate all >/dev/null 2>&1 || fail "config create on x86_64"
assert_line "export pkcs11_engine_default=/usr/lib/x86_64-linux-gnu/engines-3/pkcs11.so" "x86_64 engine"
assert_line "export opensc_pkcs11_module_default=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so" "x86_64 opensc"
assert_line "export ykcs11_module_default=/usr/lib/x86_64-linux-gnu/libykcs11.so" "x86_64 ykcs11"

# (c) installed libraries: their real paths, a versioned name included, and the
# first search folder wins
mkdir -p "${fake_root}/engines-3" "${fake_root}/second"
touch "${fake_root}/engines-3/pkcs11.so" "${fake_root}/libykcs11.so.2" \
  "${fake_root}/second/opensc-pkcs11.so" "${fake_root}/second/libykcs11.so"
FAKE_ARCH=aarch64 config_create --recreate all >/dev/null 2>&1 || fail "config create with libraries"
assert_line "export pkcs11_engine_default=${fake_root}/engines-3/pkcs11.so" "found engine"
assert_line "export opensc_pkcs11_module_default=${fake_root}/second/opensc-pkcs11.so" "found opensc"
assert_line "export ykcs11_module_default=${fake_root}/libykcs11.so.2" "found versioned ykcs11"

# a path with a space is quoted, so sourcing sca.config gives it back whole
rm -f "${fake_root}/libykcs11.so.2"
mkdir -p "${fake_root}/my libs"
touch "${fake_root}/my libs/libykcs11.so"
# shellcheck disable=SC2317 # the stub is called by sca
space_config_create() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    pkcs11_library_search_dirs() { echo "${fake_root}/my libs"; }
    sca config create --recreate all
  )
}
FAKE_ARCH=aarch64 space_config_create >/dev/null 2>&1 || fail "config create with a space"
# shellcheck source=/dev/null disable=SC2154 # sca.config sets it
assert_eq "${fake_root}/my libs/libykcs11.so" "$(. "${config}" >/dev/null 2>&1; echo "${ykcs11_module_default}")" \
  "a path with a space is sourced whole"

# (d) an existing sca.config is not rewritten and its explicit setting wins
echo 'export ykcs11_module=/custom/lib.so' >> "${config}"
cp "${config}" "${config}.before"
FAKE_ARCH=x86_64 config_create all >/dev/null 2>&1 || fail "config create on an existing config"
cmp -s "${config}" "${config}.before" || fail "an existing sca.config is not rewritten"
resolved="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  config_load "${config}" "${HOME}/.sca/config/sca.conventions" >/dev/null 2>&1
  # shellcheck disable=SC2154 # set by config_load
  echo "${ykcs11_module}"
)"
assert_eq "/custom/lib.so" "${resolved}" "the explicit ykcs11_module wins"

# (e) a missing opensc module stops the signing paths, naming the path and the
# setting to fix
output="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  # shellcheck disable=SC2034 # read by require_pkcs11_library
  opensc_pkcs11_module=/nowhere/opensc-pkcs11.so
  # shellcheck disable=SC2034 # read by require_pkcs11_library
  config_file="${config}"
  require_pkcs11_library opensc_pkcs11_module 2>&1
)"
status=$?
assert_eq 1 "${status}" "a missing opensc module exits 1: ${output}"
[[ "${output}" == *"not found at '/nowhere/opensc-pkcs11.so'"*"set opensc_pkcs11_module in ${config}"* ]] \
  || fail "the message names the path and the setting: ${output}"

# an existing opensc module passes
touch "${fake_root}/opensc-pkcs11.so"
output="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  # shellcheck disable=SC2034 # read by require_pkcs11_library
  opensc_pkcs11_module="${fake_root}/opensc-pkcs11.so"
  require_pkcs11_library opensc_pkcs11_module 2>&1
)"
assert_eq 0 "$?" "an existing opensc module passes: ${output}"

test_done
