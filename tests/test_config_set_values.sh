#!/bin/bash
# config set values: every value given to `sca config set` must be saved and
# read back exactly as given. spaces, quotes and shell syntax must not split
# the value, break the sed that saves it, or run when the config is sourced.
# commands that switch an entity for a moment (request, display) must put the
# spaced values back exactly.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

config="${HOME}/.sca/config/sca.config"

# run_sca - the built sca with stdin closed, so a prompt fails instead of
# waiting, and a timeout, so a hang fails fast
run_sca() {
  timeout -k 5 60 bash "${SCA}" "$@" < /dev/null
}

# step ARGS... - run sca ARGS; on failure report it and stop the file
step() {
  local output status
  output="$(run_sca "$@" 2>&1)"
  status=$?
  [ "${status}" -eq 0 ] && return 0
  fail "sca $* exited ${status}"
  [ -n "${output}" ] && echo "${output}" >&2
  test_done
}

# assert_sourced VAR EXPECTED - sourcing the config (set -u, in a subshell)
# gives VAR_default exactly EXPECTED
assert_sourced() {
  local actual
  # shellcheck source=/dev/null
  actual="$(set -u; . "${config}" > /dev/null 2>&1; v="$1_default"; printf '%s.' "${!v}")"
  assert_eq "$2." "${actual}" "sourced $1_default"
}

step config create all
assert_succeeds bash -n "${config}"
# the shipped default holds a space too
assert_sourced caps_name "Harley Systems"

# a value with every character that used to break: two spaces, $(...),
# backticks, / & \ ' " and a glob
nasty="a\$(touch \"${HOME}/pwned\")\`touch \"${HOME}/pwned2\"\`/&'\"\\*  b"

# key-value form
step config set ca caps_name "Test Inc"
assert_eq '"harley" "Test Inc"' "$(run_sca config get ca)" "config get ca (key-value)"
assert_sourced caps_name "Test Inc"

# positional form
step config set ca test "Test  Inc *"
assert_eq '"test" "Test  Inc *"' "$(run_sca config get ca)" "config get ca (positional)"
assert_sourced name test
assert_sourced caps_name "Test  Inc *"

step config set ca caps_name "${nasty}"
assert_eq "\"test\" \"${nasty}\"" "$(run_sca config get ca)" "config get ca (shell characters)"
assert_sourced caps_name "${nasty}"

step config set subca ops "Ops Team" "Van Der Berg" "Anna Maria" "A. M."
assert_eq '"ops" "Ops Team" "Van Der Berg" "Anna Maria" "A. M."' \
  "$(run_sca config get subca)" "config get subca"
assert_sourced subca_surname "Van Der Berg"

step config set user use_security_key false
step config set user alice "Alice Smith" "Smith Jones" "Alice B" "A. B."
assert_eq '"alice" "Alice Smith" "Smith Jones" "Alice B" "A. B."' \
  "$(run_sca config get user)" "config get user"
assert_sourced user_given_name "Alice B"

step config set user surname "${nasty}"
assert_eq "\"alice\" \"Alice Smith\" \"${nasty}\" \"Alice B\" \"A. B.\"" \
  "$(run_sca config get user)" "config get user (shell characters)"
assert_sourced user_surname "${nasty}"

# nothing in any value ran, and the config file still parses and sources
[ -e "${HOME}/pwned" ] && fail "a \$(...) in a value ran"
[ -e "${HOME}/pwned2" ] && fail "a backtick command in a value ran"
assert_succeeds bash -n "${config}"
assert_succeeds bash -c "set -u; . '${config}'"

# switching to another user for a moment puts the spaced values back. openssl
# reads '$' in its config as a variable, so issue with plain spaced names
step config set ca caps_name "Test Inc"
step config set user surname "Smith Jones"
before_config="$(cat "${config}")"
before_get="$(run_sca config get user)"
step request user bob
step display csr user bob
step display key user bob
assert_eq "${before_get}" "$(run_sca config get user)" "config get user after switching"
assert_eq "${before_config}" "$(cat "${config}")" "config file after switching"

test_done
