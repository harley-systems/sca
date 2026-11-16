#!/bin/bash
# the command dispatchers must hand their arguments to the subcommand as they
# were given: an argument with a space stays one argument, and shell syntax in
# an argument is never run. an unknown subcommand is still rejected.
#
# runs offline on the software-key demo, with no security key.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

sca config create all > /dev/null 2>&1 || fail "config create all"
sca init demo "${HOME}/demo" > /dev/null 2>&1 || fail "init demo"

# point at the demo user, the way init_demo_switch_to does
export key_folder="${HOME}/demo/user-key/" transfer_folder="${HOME}/demo/user-transfer/"
export ca_use_security_key=false subca_use_security_key=false user_use_security_key=false

# a fresh working folder, to see whether a command in the password ran
work="${HOME}/work"
mkdir -p "${work}"
cd "${work}" || fail "cd ${work}"

# the single quotes are the point: the password must reach openssl as is
# shellcheck disable=SC2016
password='pa$(touch x)ss'
p12="${HOME}/u.p12"
assert_succeeds sca export p12 -n "two words" -p "${password}" -o "${p12}" user
assert_file_exists "${p12}" "p12 not written"
[ -e "${work}/x" ] && fail "a command in the password ran: ${work}/x exists"
[ -e "${HOME}/x" ] && fail "a command in the password ran: ${HOME}/x exists"

# the p12 opens with exactly that password and keeps the name in one piece
output=$(openssl pkcs12 -in "${p12}" -passin "pass:${password}" -nokeys 2>&1) \
  || fail "p12 does not open with the given password: ${output}"
[[ "${output}" == *"friendlyName: two words"* ]] \
  || fail "p12 friendly name is not 'two words': ${output}"

# an unknown subcommand is still rejected, through more than one dispatcher
# assert_rejected_value VALUE ARGS... - sca ARGS must fail and name VALUE
assert_rejected_value() {
  local value=$1 output status=0
  shift
  output="$(sca "$@" 2>&1)" || status=$?
  [ "${status}" -ne 0 ] || fail "sca $* exited 0"
  [[ "${output}" == *"invalid value '${value}'"* ]] \
    || fail "sca $*: no \"invalid value '${value}'\" message in: ${output}"
}
assert_rejected_value foo export foo user
assert_rejected_value foo list foo
assert_rejected_value foo security_key foo

test_done
