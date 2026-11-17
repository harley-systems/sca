#!/bin/bash
# error output: error prints its message on stderr exactly as written (line
# breaks, spacing and glob characters kept) and exits with the given code; the
# log helpers and error leave a caller's 'message' alone; and the invalid
# value messages print without their source indentation.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# shellcheck disable=SC2154 # test_home is set by lib.sh
glob_dir="${test_home}/glob"
mkdir -p "${glob_dir}"
touch "${glob_dir}/aS" "${glob_dir}/S" "${glob_dir}/xyz"

# sca_error MESSAGE CODE - call error from the built sca in a subshell
# started in glob_dir, where the glob characters would match files
sca_error() {
  (
    cd "${glob_dir}" || exit 2
    # shellcheck source=/dev/null
    . "${SCA}"
    error "$@"
  )
}

# glob characters are printed literally, on stderr only, with the exit code
status=0
stdout="$(sca_error 'a* [S] ?yz' 3 2>/dev/null)" || status=$?
assert_eq "" "${stdout}" "error writes to stdout"
stderr="$(sca_error 'a* [S] ?yz' 3 2>&1 >/dev/null)"
assert_eq 'a* [S] ?yz' "${stderr}" "error expands or changes glob characters"
assert_eq 3 "${status}" "error exit code"

# spacing and line breaks are kept, and only one newline is added
message='two  spaces
  indented line'
stderr="$(sca_error "${message}" 4 2>&1 >/dev/null; echo x)"
assert_eq "${message}"$'\n'x "${stderr}" "error changes spacing or line breaks"

# the helpers don't overwrite a caller's local message or exit_code
for helper in log_verbose log_detailed log_extreemly_detailed log; do
  result="$(
    # shellcheck source=/dev/null
    . "${SCA}"
    # shellcheck disable=SC2034 # read by the helpers
    log_file="${test_home}/sca.log"
    f() {
      local message=keep exit_code=7
      verbosity=vvv "${helper}" "x"
      echo "${message} ${exit_code}"
    }
    f
  )"
  assert_eq "keep 7" "${result}" "${helper} overwrites the caller's message"
done
result="$(
  # shellcheck source=/dev/null
  . "${SCA}"
  f() {
    local message=keep exit_code=7
    ( error "x" 1 ) 2>/dev/null
    echo "${message} ${exit_code}"
  }
  f
)"
assert_eq "keep 7" "${result}" "error overwrites the caller's message"

# the invalid value messages: no line starts with whitespace
assert_succeeds sca config create all
for command in "foo" "create foo" "list foo" "display foo" "config foo" \
    "security_key foo" "appliance foo" "completion foo"; do
  # shellcheck disable=SC2086 # split the command into its words
  output="$(sca ${command} 2>&1)" && fail "sca ${command} exits 0"
  [[ "${output}" == *"invalid value 'foo'"* ]] \
    || fail "sca ${command}: no invalid value message in: ${output}"
  ! printf '%s\n' "${output}" | grep -q '^[[:space:]]' \
    || fail "sca ${command}: a line starts with whitespace in: ${output}"
done

test_done
