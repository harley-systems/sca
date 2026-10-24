#!/bin/bash
################################################################################
# sca test helpers - source this at the top of every tests/test_*.sh
#
# Sourcing this file:
#   - moves HOME to a fresh temporary folder (removed on exit), so a test can
#     never read or write the real ~/.sca
#   - clears the environment variables sca would otherwise pick up from the
#     caller's shell (sca_conf_folder, config_file, ...)
#   - defines SCA (path to the built build/sca.sh) and the sca() wrapper
#
# A test file is a plain bash script: call the assert_* functions, then end
# with test_done, which exits non-zero if any assertion failed.

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCA="${SCA:-$(dirname "${tests_dir}")/build/sca.sh}"
if [ ! -f "${SCA}" ]; then
  echo "error: ${SCA} not found. run 'make' (or 'make check') first." >&2
  exit 2
fi

test_home="$(mktemp -d "${TMPDIR:-/tmp}/sca-test.XXXXXX")" || exit 2
trap 'rm -rf "${test_home}"' EXIT
export HOME="${test_home}"
unset sca_conf_folder config_file conventions_file demo_folder verbosity

test_failures=0

# run the built sca, the same way a user would run the installed one
sca() {
  bash "${SCA}" "$@"
}

fail() {
  echo "  FAIL: $*" >&2
  test_failures=$((test_failures + 1))
}

# assert_eq EXPECTED ACTUAL [MESSAGE]
assert_eq() {
  [ "$1" == "$2" ] || fail "${3:-values differ}: expected '$1', got '$2'"
}

# assert_file_exists FILE [MESSAGE]
assert_file_exists() {
  [ -f "$1" ] || fail "${2:-file missing}: $1"
}

# assert_succeeds COMMAND [ARGS...] - command must exit 0
assert_succeeds() {
  local output
  if ! output="$("$@" 2>&1)"; then
    fail "expected success: $*"
    [ -n "${output}" ] && echo "${output}" >&2
  fi
}

# assert_fails COMMAND [ARGS...] - command must exit non-zero
assert_fails() {
  "$@" >/dev/null 2>&1 && fail "expected failure: $*"
}

# test_done - report the result of this test file and exit with it
test_done() {
  if [ "${test_failures}" -gt 0 ]; then
    echo "  ${test_failures} assertion(s) failed" >&2
    exit 1
  fi
  exit 0
}
