#!/bin/bash
# sca install: ~/bin must be added to PATH in ~/.bashrc exactly once, and only
# when it is not on PATH already.
#
# install runs in a subshell that sources the built sca, so the package
# installation steps (apt, sudo) can be replaced with no-ops: functions defined
# in the script would override stubs exported from here.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

marker="# set PATH so it includes user's private bin if it exists"

# run_install PATH [INSTALL-OPTIONS...] - runs sca install with PATH set to PATH
run_install() {
  local path=$1
  shift
  # shellcheck disable=SC2317 # the stubs are called by sca install
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    install_core_online() { :; }
    install_core_offline() { :; }
    install_pkcs11_packages_online() { :; }
    install_pkcs11_packages_offline() { :; }
    install_yubico_piv_tool() { :; }
    install_iso_image_tools() { :; }
    PATH="${path}"
    sca install "$@"
  )
}

marker_count() {
  grep -cxF "${marker}" "$HOME/.bashrc" 2>/dev/null || true
}

# a fresh HOME with only the default sca config, which install expects
reset_home() {
  rm -rf "${HOME:?}/bin" "${HOME:?}/.sca" "${HOME:?}/.bashrc"
  sca config create all >/dev/null 2>&1
}

for mode in online offline; do
  options=()
  [ "${mode}" = offline ] && options+=(--air-gapped)

  # ~/bin is not on PATH: the snippet is added once, and not again on --force
  reset_home
  output="$(run_install "/usr/bin:/bin" "${options[@]}" 2>&1)"
  assert_eq 1 "$(marker_count)" "${mode}: snippet added on first install"
  [[ "${output}" == *". ~/.bashrc"* ]] \
    || fail "${mode}: no hint to reload ~/.bashrc: ${output}"
  output="$(run_install "/usr/bin:/bin" "${options[@]}" --force 2>&1)"
  assert_eq 1 "$(marker_count)" "${mode}: snippet not added again on --force"
  [[ "${output}" == *". ~/.bashrc"* ]] \
    && fail "${mode}: reload hint printed though nothing was added"
  # the snippet puts ~/bin on PATH when ~/.bashrc is sourced
  assert_eq "$HOME/bin" \
    "$(PATH=/usr/bin:/bin bash -c '. "$HOME/.bashrc"; echo "${PATH%%:*}"')" \
    "${mode}: snippet puts ~/bin on PATH"

  # ~/bin is on PATH already: ~/.bashrc is left untouched
  reset_home
  echo "# existing bashrc" > "$HOME/.bashrc"
  run_install "$HOME/bin:/usr/bin:/bin" "${options[@]}" >/dev/null 2>&1
  assert_eq "# existing bashrc" "$(cat "$HOME/.bashrc")" \
    "${mode}: ~/.bashrc untouched when ~/bin is on PATH"
done

test_done
