#!/bin/bash
################################################################################
# sca test helpers - source this at the top of every tests/test_*.sh
#
# Sourcing this file:
#   - moves HOME to a fresh temporary folder (removed on exit), so a test can
#     never read or write the real ~/.sca. Add any other temporary path to
#     test_cleanup (test_cleanup+=(PATH)) to have it removed too; don't set
#     your own EXIT trap
#   - clears the environment variables sca would otherwise pick up from the
#     caller's shell (sca_conf_folder, config_file, ...)
#   - defines SCA (path to the built build/sca.sh) and the sca() wrapper
#
# A test file is a plain bash script: call the assert_* functions, then end
# with test_done, which exits non-zero if any assertion failed. A file that
# exits without calling test_done (forgotten, or an early exit) fails too, so
# failed assertions can't be hidden.

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCA="${SCA:-$(dirname "${tests_dir}")/build/sca.sh}"
if [ ! -f "${SCA}" ]; then
  echo "error: ${SCA} not found. run 'make' (or 'make check') first." >&2
  exit 2
fi

test_home="$(mktemp -d "${TMPDIR:-/tmp}/sca-test.XXXXXX")" || exit 2

test_failures=0
test_done_called=false
# extra paths to remove on exit
test_cleanup=()

# test_exit - EXIT trap: remove the temporary folders; fail a file that
# ended without test_done, so a skipped or early exit can't hide failures
test_exit() {
  local status=$?
  rm -rf "${test_home}" "${test_cleanup[@]}"
  if [ "${test_done_called}" != true ]; then
    echo "  FAIL: $0 exited without test_done (${test_failures} assertion(s) failed)" >&2
    [ "${status}" -ne 0 ] || status=1
  fi
  exit "${status}"
}
trap test_exit EXIT

export HOME="${test_home}"
unset sca_conf_folder config_file conventions_file demo_folder verbosity

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
  test_done_called=true
  if [ "${test_failures}" -gt 0 ]; then
    echo "  ${test_failures} assertion(s) failed" >&2
    exit 1
  fi
  exit 0
}
