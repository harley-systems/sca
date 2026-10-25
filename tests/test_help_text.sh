#!/bin/bash
# help text is printed verbatim: quotes, $VARIABLES and backticks in a help
# file must not be parsed as shell by the generated *_help functions.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

src_dir="$(dirname "${tests_dir}")/src"

# no help wrapper may embed its text in a quoted echo
while IFS= read -r wrapper; do
  if grep -B1 -E '^@@@(GENERIC )?HELP@@@$' "${wrapper}" | grep -qE "echo [\"']$"; then
    fail "help is wrapped in a quoted echo: ${wrapper#"${src_dir}/"}"
  fi
done < <(grep -rlE '^@@@(GENERIC )?HELP@@@$' "${src_dir}")

# every wrapper, filled in the way the Makefile fills it, prints the help
# file unchanged
help_file="${HOME}/help.txt"
cat > "${help_file}" <<'EOF'
a "double-quoted" <major>.<minor> example, it's an apostrophe,
$HOME stays literal and `date` is not run
EOF
while IFS= read -r wrapper; do
  built="${HOME}/wrapper.sh"
  sed -e "/^@@@\(GENERIC \)\?HELP@@@\$/{r ${help_file}" -e 'd}' "${wrapper}" > "${built}"
  # the function that contains the marker line
  marker_line=$(grep -nE '^@@@(GENERIC )?HELP@@@$' "${wrapper}" | head -1 | cut -d: -f1)
  help_function=$(head -n "${marker_line}" "${wrapper}" |
    grep -oE '^ *[a-z0-9_]+\(\) *\{' | tail -1 | grep -oE '[a-z0-9_]+')
  name="${wrapper#"${src_dir}/"}:${help_function}"
  # shellcheck source=/dev/null # the wrapper is generated above
  if ! output=$( (. "${built}" && "${help_function}") 2>&1); then
    fail "${name} exited non-zero"
  fi
  assert_eq "$(printf '\n%s\n' "$(cat "${help_file}")")" "${output}" "${name} output"
done < <(grep -rlE '^@@@HELP@@@$' "${src_dir}")

# the built help that contains quotes renders, end to end
sca config create all >/dev/null 2>&1
assert_succeeds sca init sca_usb_stick --help
sca init sca_usb_stick --help | grep -qF '"<major>.<minor>.<fix>-<release_name>"' ||
  fail "sca init sca_usb_stick --help lost its quoted example"
assert_succeeds sca test --help

test_done
