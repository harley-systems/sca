#!/bin/bash
# an unknown option, or an option missing its argument, must make the command
# fail with getopt's message and a pointer to -h, before it does any work.
#
# the hardware tools are stubbed as exported shell functions (see
# test_security_key_init.sh for why) that leave a marker file, so a test can
# see that the command stopped before touching a security key.
# the stubs are only called from the sca child process
# shellcheck disable=SC2317
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

marker="${HOME}/tool-called"
ykman() { touch "${HOME}/tool-called"; }
opensc-tool() { touch "${HOME}/tool-called"; }
yubico-piv-tool() { touch "${HOME}/tool-called"; }
export -f ykman opensc-tool yubico-piv-tool

# without a config sca fails early for another reason, which would make the
# checks below pass for the wrong reason
sca config create all > /dev/null 2>&1 || fail "config create all"

# assert_rejected ARGS... - sca ARGS must exit 1 and point the user to -h
assert_rejected() {
  local output status=0
  output="$(sca "$@" 2>&1)" || status=$?
  assert_eq 1 "${status}" "exit status of sca $*"
  [[ "${output}" == *"-h for help"* ]] \
    || fail "sca $*: no '-h for help' message in: ${output}"
}

assert_rejected create key --bogus service
assert_rejected create key -Z service
assert_rejected security_key info --bogus
assert_rejected security_key info --devcie 1234
assert_rejected security_key init --bogus subca
assert_rejected export p12 --bogus service
# --password needs a value
assert_rejected export p12 service --password
# --dry-run too, so a regression can't start installing packages
assert_rejected install --dry-run --bogus
[ -e "${marker}" ] && fail "a security key tool ran for a rejected command"
[ -e "${HOME}/.sca/keys" ] && [ -n "$(find "${HOME}/.sca/keys" -type f)" ] \
  && fail "a rejected command created files under ~/.sca/keys"

# valid options still parse
assert_succeeds sca create key --help

test_done
