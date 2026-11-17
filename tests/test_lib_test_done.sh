#!/bin/bash
# tests/lib.sh: a test file that exits without test_done fails, test_done
# behaves as before, and the temporary folders are removed in every case
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

scripts_dir="$(mktemp -d "${TMPDIR:-/tmp}/sca-test-lib.XXXXXX")" || exit 2
test_cleanup+=("${scripts_dir}")
export SCA

# run_child NAME BODY - write a test file that sources lib.sh, records its
# HOME in NAME.home and runs BODY; run it and set child_status, child_stderr
# and child_home
run_child() {
  local name="$1" body="$2"
  cat > "${scripts_dir}/${name}.sh" <<EOF
#!/bin/bash
. "${tests_dir}/lib.sh"
echo "\${HOME}" > "${scripts_dir}/${name}.home"
${body}
EOF
  child_stderr="$(bash "${scripts_dir}/${name}.sh" 2>&1 >/dev/null)"
  child_status=$?
  child_home="$(cat "${scripts_dir}/${name}.home" 2>/dev/null)"
  [ -n "${child_home}" ] || fail "${name}: child recorded its HOME"
  [ ! -e "${child_home}" ] || fail "${name}: temporary HOME is removed: ${child_home}"
}

# (a) a failing assertion and no test_done
run_child fail_no_done 'assert_eq a b "differ"'
[ "${child_status}" -ne 0 ] || fail "fail_no_done: exits non-zero"
[[ "${child_stderr}" == *"exited without test_done (1 assertion(s) failed)"* ]] \
  || fail "fail_no_done: reports the missing test_done: ${child_stderr}"

# (b) a passing assertion and no test_done
run_child pass_no_done 'assert_eq a a "same"'
[ "${child_status}" -ne 0 ] || fail "pass_no_done: exits non-zero"
[[ "${child_stderr}" == *"exited without test_done (0 assertion(s) failed)"* ]] \
  || fail "pass_no_done: reports the missing test_done: ${child_stderr}"

# (c) a passing assertion and test_done
run_child pass_done 'assert_eq a a "same"
test_done'
assert_eq 0 "${child_status}" "pass_done: exit status"
assert_eq "" "${child_stderr}" "pass_done: stderr"

# (d) a failing assertion and test_done
run_child fail_done 'assert_eq a b "differ"
test_done'
assert_eq 1 "${child_status}" "fail_done: exit status"
[[ "${child_stderr}" == *"1 assertion(s) failed"* ]] \
  || fail "fail_done: reports the failed assertion: ${child_stderr}"
[[ "${child_stderr}" != *"without test_done"* ]] \
  || fail "fail_done: no missing test_done message: ${child_stderr}"

# an explicit non-zero exit without test_done keeps its status
run_child exit_3 'exit 3'
assert_eq 3 "${child_status}" "exit_3: exit status"
[[ "${child_stderr}" == *"exited without test_done"* ]] \
  || fail "exit_3: reports the missing test_done: ${child_stderr}"

# an early exit 0 without test_done fails
run_child exit_0 'exit 0'
assert_eq 1 "${child_status}" "exit_0: exit status"

# (e) subshells exiting don't trigger the message
# shellcheck disable=SC2016 # the child expands it
run_child subshell '( exit 1 )
output="$(exit 1)"
test_done'
assert_eq 0 "${child_status}" "subshell: exit status"
assert_eq "" "${child_stderr}" "subshell: stderr"

# (f) paths in test_cleanup are removed, with or without test_done
run_child cleanup_done "extra=\"\$(mktemp -d \"${scripts_dir}/extra.XXXXXX\")\"
echo \"\${extra}\" > \"${scripts_dir}/cleanup_done.extra\"
test_cleanup+=(\"\${extra}\")
test_done"
assert_eq 0 "${child_status}" "cleanup_done: exit status"
extra="$(cat "${scripts_dir}/cleanup_done.extra" 2>/dev/null)"
if [ -z "${extra}" ] || [ -e "${extra}" ]; then
  fail "cleanup_done: test_cleanup path is removed: '${extra}'"
fi

run_child cleanup_no_done "extra=\"\$(mktemp -d \"${scripts_dir}/extra.XXXXXX\")\"
echo \"\${extra}\" > \"${scripts_dir}/cleanup_no_done.extra\"
test_cleanup+=(\"\${extra}\")"
[ "${child_status}" -ne 0 ] || fail "cleanup_no_done: exits non-zero"
extra="$(cat "${scripts_dir}/cleanup_no_done.extra" 2>/dev/null)"
if [ -z "${extra}" ] || [ -e "${extra}" ]; then
  fail "cleanup_no_done: test_cleanup path is removed: '${extra}'"
fi

test_done
