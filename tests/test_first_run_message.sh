#!/bin/bash
# first run: with no configuration, sca names the missing file and tells the
# user to run 'sca config create all' - without sudo, since the configuration
# folder is the user's own ~/.sca/config/
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

config_file="${HOME}/.sca/config/sca.config"

assert_fails sca security_key info
output="$(sca security_key info 2>&1)"

[[ "${output}" == *"${config_file} doesn't"* ]] \
  || fail "message does not name the missing config file ${config_file}"
[[ "${output}" == *"sca config create all"* ]] \
  || fail "message does not tell the user to run 'sca config create all'"
[[ "${output}" != *sudo* ]] \
  || fail "message tells the user to use sudo"
[[ "${output}" == *sca_conf_folder* ]] \
  || fail "message does not mention the sca_conf_folder environment variable"
[[ "${output}" == *"sca config create -h"* ]] \
  || fail "message does not point to 'sca config create -h'"

# the message keeps its line breaks: the advice is on its own line, indented
# as written, rather than flattened into one long line
output="$(sca create key user 2>&1 >/dev/null)" \
  && fail "sca create key user exits 0 without a config"
[ "$(printf '%s\n' "${output}" | wc -l)" -gt 1 ] \
  || fail "the missing config message is on a single line: ${output}"
printf '%s\n' "${output}" | grep -qxF '  sca config create all' \
  || fail "'  sca config create all' is not on its own line in: ${output}"
printf '%s\n' "${output}" | grep -qx 'exiting\.' \
  || fail "'exiting.' is not on its own line in: ${output}"

# other commands are refused the same way, with a non-zero exit
for command in "create key ca" "test --skip-air-gapped-tests"; do
  # shellcheck disable=SC2086 # split the command into its words
  output="$(sca ${command} 2>&1)" && fail "sca ${command} exits 0 without a config"
  [[ "${output}" == *"${config_file} doesn't"* ]] \
    || fail "sca ${command} does not report the missing config: ${output}"
done

# completion only prints a script, so it works without a config. make deploy
# runs it right after copying sca
output="$(sca completion bash 2>&1)" \
  || fail "sca completion bash fails without a config: ${output}"
[[ "${output}" == *"complete -F"* ]] \
  || fail "sca completion bash prints no completion script: ${output}"
[ ! -e "${config_file}" ] || fail "sca completion bash creates a config"

# following the advice, without sudo, makes the message go away
assert_succeeds sca config create all
assert_file_exists "${config_file}"
output="$(sca security_key info 2>&1)"
[[ "${output}" != *"doesn't"*"exist"* ]] \
  || fail "message still shown after 'sca config create all'"

test_done
