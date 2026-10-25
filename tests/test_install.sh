#!/bin/bash
# install: a package that fails to install, a missing .deb, or a system without
# apt must make sca install fail and say which packages are affected.
#
# apt-get, dpkg-query and sudo are stubbed as exported shell functions (see
# test_security_key_init.sh for why functions rather than scripts on PATH).
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# nothing is installed yet, unless ALL_INSTALLED is set; apt-get records what
# it was asked to install and fails for any package named in APT_FAIL
dpkg-query() {
  [ -n "${ALL_INSTALLED:-}" ] && echo "install ok installed"
  [ -n "${ALL_INSTALLED:-}" ]
}
apt-get() {
  echo "$*" >> "$HOME/apt-get.log"
  local arg
  for arg in "$@"; do
    [[ " ${APT_FAIL:-} " == *" ${arg} "* ]] && return 100
  done
  return 0
}
apt-add-repository() {
  return 0
}
# sudo records each call in ~/sudo.log and on stderr, so a test can see both
# whether it ran and what was printed just before it
sudo() {
  echo "$*" >> "$HOME/sudo.log"
  echo "sudo: $*" >&2
  "$@"
}
export -f dpkg-query apt-get apt-add-repository sudo

# sca refuses most commands, install with options included, until a config
# exists, so each case starts from a fresh home with the default config
reset_home() {
  rm -rf "${HOME:?}"/* "${HOME}"/.[!.]*
  sca config create all > /dev/null 2>&1 || fail "config create all"
}

# a successful run installs sca and exits 0, as before
reset_home
assert_succeeds sca install --yubikey-support
assert_file_exists "$HOME/bin/sca" "sca copied to ~/bin"
grep -q 'install -y ykcs11' "$HOME/apt-get.log" 2>/dev/null \
  || fail "ykcs11 was not installed with --yubikey-support"

# one package fails: the rest are still attempted, the run fails and names it
reset_home
output="$(APT_FAIL="ykcs11 opensc" sca install --yubikey-support 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "install exits non-zero when a package fails"
[[ "${output}" == *"ykcs11 - retry with: sudo apt-get install -y ykcs11"* ]] \
  || fail "failure message names ykcs11 and the retry command: ${output}"
[[ "${output}" == *"opensc - retry with: sudo apt-get install -y opensc"* ]] \
  || fail "all failures are reported together: ${output}"
grep -q 'install -y syslinux-utils' "$HOME/apt-get.log" 2>/dev/null \
  || fail "packages after the failed one are still attempted"

# every package is listed, and its name is printed right before sudo runs
reset_home
output="$(sca install 2>&1)"
[[ "${output}" == *"checking prerequisite packages:"* ]] \
  || fail "the package checks are announced: ${output}"
[[ "${output}" == *"  openssl: not installed, installing (sudo apt-get install -y openssl)"$'\n'"sudo: apt-get install -y openssl"* ]] \
  || fail "the package is named before sudo runs: ${output}"

# sca already installed and every package present: the packages are listed as
# skipped, the message says the checks go on, and sudo is never run
reset_home
sca install > /dev/null 2>&1
rm -f "$HOME/sudo.log"
output="$(ALL_INSTALLED=1 sca install 2>&1)"
status=$?
assert_eq 0 "${status}" "install on a provisioned host exits 0"
[[ "${output}" == *"skipping the sca script step"*"prerequisite checks continue."* ]] \
  || fail "already-installed message says the checks continue: ${output}"
[[ "${output}" == *"  openssl: already installed, skipping"* ]] \
  || fail "skipped packages are listed: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "sudo is not run on a provisioned host: $(cat "$HOME/sudo.log")"

# --dry-run: the missing packages are listed as would-install, exit 0, and
# nothing is run with sudo or written to ~/bin and ~/.bashrc
reset_home
output="$(sca install --dry-run --yubikey-support 2>&1)"
status=$?
assert_eq 0 "${status}" "dry run exits 0"
[[ "${output}" == *"  ykcs11: not installed, would install (sudo apt-get install -y ykcs11)"* ]] \
  || fail "dry run lists the missing package: ${output}"
[[ "${output}" == *"dry run: nothing was installed or changed."* ]] \
  || fail "dry run says nothing changed: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "dry run runs no sudo: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "dry run does not touch ~/bin"
[ ! -e "$HOME/.bashrc" ] || fail "dry run does not edit ~/.bashrc"

# -n works offline too, and a missing .deb does not fail the dry run
reset_home
output="$(sca install -n --air-gapped 2>&1)"
status=$?
assert_eq 0 "${status}" "offline dry run exits 0: ${output}"
[ ! -e "$HOME/sudo.log" ] || fail "offline dry run runs no sudo: $(cat "$HOME/sudo.log")"
[ ! -e "$HOME/bin" ] || fail "offline dry run does not touch ~/bin"

# offline: a .deb the selected options need but that is missing is an error
if [ ! -d /opt/sca/packages ]; then
  reset_home
  output="$(sca install --air-gapped 2>&1)"
  status=$?
  [ "${status}" -ne 0 ] || fail "offline install exits non-zero when a .deb is missing"
  [[ "${output}" == *"datefudge - no datefudge_*.deb in /opt/sca/packages/"* ]] \
    || fail "missing .deb is named: ${output}"
fi

# no apt-get / dpkg-query: fail before touching ~/bin, listing the packages.
# PATH is a folder linking every tool except those two.
reset_home
no_apt_bin="$(mktemp -d "${TMPDIR:-/tmp}/sca-test-bin.XXXXXX")" || exit 2
# shellcheck disable=SC2154 # test_home is set by lib.sh
trap 'rm -rf "${test_home}" "${no_apt_bin}"' EXIT
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin; do
  for tool in "${dir}"/*; do
    case "${tool##*/}" in apt-get | dpkg-query ) continue ;; esac
    [ -e "${no_apt_bin}/${tool##*/}" ] || ln -s "${tool}" "${no_apt_bin}/${tool##*/}"
  done
done
output="$(unset -f apt-get dpkg-query; PATH="${no_apt_bin}" sca install --yubikey-support 2>&1)"
status=$?
[ "${status}" -ne 0 ] || fail "install exits non-zero without apt-get"
[ ! -e "$HOME/bin" ] || fail "\$HOME/bin is not touched without apt-get"
[[ "${output}" == *"ykcs11"* && "${output}" == *"opensc"* && "${output}" == *"datefudge"* ]] \
  || fail "required packages are listed: ${output}"
[[ "${output}" == *"docs/ssh-yubikey-options.md"* ]] \
  || fail "platform docs are referenced: ${output}"
[ ! -e "$HOME/apt-get.log" ] || fail "nothing is installed without apt-get"

test_done
