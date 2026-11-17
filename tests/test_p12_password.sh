#!/bin/bash
# export p12 and display p12 must hand the p12 password to openssl without
# putting it on a command line, where ps and /proc/<pid>/cmdline show it to
# every local user -- whether it came from -p or from the prompt.
#
# an openssl shim first on PATH records the argv of every openssl call sca
# makes (a real file, not an exported function, so calls from pipelines and
# subshells are caught too) and whether SCA_P12_PASSWORD reached it, then
# runs the real openssl.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

real_openssl="$(command -v openssl)" || { echo "error: openssl not found" >&2; exit 2; }

# next to the built sca rather than in TMPDIR, which may be mounted noexec
shim_dir="$(mktemp -d "$(dirname "${SCA}")/test-openssl.XXXXXX")" || exit 2
test_cleanup+=("${shim_dir}")
shim_log="${shim_dir}/argv.log"
cat > "${shim_dir}/openssl" <<EOF
#!/bin/bash
# one write per line, so the stages of a pipeline can't interleave theirs
line="\${SCA_P12_PASSWORD+[env] }\$(printf '%q ' "\$@")"
printf '%s\\n' "\${line}" >> "${shim_log}"
exec "${real_openssl}" "\$@"
EOF
chmod +x "${shim_dir}/openssl"

pw="s3cr3t-p12-$$"

sca config create all > /dev/null 2>&1 || fail "config create all"

# sca_path NAME - the path sca resolves for the setting NAME
sca_path() {
  (
    # shellcheck source=/dev/null
    . "${HOME}/.sca/config/sca.config"
    # shellcheck source=/dev/null
    . "${HOME}/.sca/config/sca.conventions"
    echo "${!1}"
  )
}
ca_crt="$(sca_path ca_crt_file)"
subca_crt="$(sca_path subca_crt_file)"
user_crt="$(sca_path user_crt_file)"
user_key="$(sca_path user_key_file)"

# a throwaway root, sub-CA and user, made with the real openssl
fixture="${HOME}/fixture"
mkdir -p "${fixture}" "$(dirname "${ca_crt}")" "$(dirname "${subca_crt}")" \
  "$(dirname "${user_crt}")" "$(dirname "${user_key}")"
{
  "${real_openssl}" req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "${fixture}/ca-key.pem" -out "${ca_crt}" -subj "/CN=p12-test-ca" -days 1 &&
  "${real_openssl}" req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "${fixture}/subca-key.pem" -out "${fixture}/subca.csr" -subj "/CN=p12-test-subca" &&
  "${real_openssl}" x509 -req -in "${fixture}/subca.csr" -CA "${ca_crt}" \
    -CAkey "${fixture}/ca-key.pem" -CAcreateserial -out "${subca_crt}" -days 1 &&
  "${real_openssl}" req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout "${user_key}" -out "${fixture}/user.csr" -subj "/CN=p12-test-user" &&
  "${real_openssl}" x509 -req -in "${fixture}/user.csr" -CA "${subca_crt}" \
    -CAkey "${fixture}/subca-key.pem" -CAcreateserial -out "${user_crt}" -days 1
} > /dev/null 2>&1 || fail "create the certificate fixture"

PATH="${shim_dir}:${PATH}"
# if bash skipped the shim (noexec mount), every check below would pass unseen
if [ "$(command -v openssl)" != "${shim_dir}/openssl" ]; then
  echo "error: can't run the openssl shim in ${shim_dir} (noexec?)" >&2
  exit 2
fi

# assert_not_leaked WHAT - the shim saw a pkcs12 call, the password in no argv,
# and SCA_P12_PASSWORD only on the pkcs12 calls
assert_not_leaked() {
  grep -q ' pkcs12 \|^pkcs12 ' "${shim_log}" 2>/dev/null \
    || fail "$1: no openssl pkcs12 call recorded"
  if grep -qF -- "${pw}" "${shim_log}" 2>/dev/null; then
    fail "$1: password on an openssl command line:"
    grep -F -- "${pw}" "${shim_log}" >&2
  fi
  if grep '^\[env\] ' "${shim_log}" | grep -qv '^\[env\] pkcs12 '; then
    fail "$1: SCA_P12_PASSWORD reached a command other than openssl pkcs12:"
    grep '^\[env\] ' "${shim_log}" | grep -v '^\[env\] pkcs12 ' >&2
  fi
  : > "${shim_log}"
}

# assert_opens FILE PASSWORD WHAT - the real openssl opens FILE with PASSWORD
assert_opens() {
  "${real_openssl}" pkcs12 -in "$1" -nokeys -passin pass:"$2" > /dev/null 2>&1 \
    || fail "$3: exported file does not open with its password"
}

# assert_displays OUTPUT STATUS WHAT - display p12 succeeded and listed the user
assert_displays() {
  assert_eq 0 "$2" "$3: exit status"
  [[ "$1" == *"p12-test-user"* ]] || fail "$3: user certificate not listed in: $1"
}

# export with -p
out_p="${HOME}/out-p.p12"
sca export p12 -p "${pw}" -o "${out_p}" user > /dev/null 2>&1 || fail "export p12 -p"
assert_not_leaked "export p12 -p"
assert_opens "${out_p}" "${pw}" "export p12 -p"

# export with the password typed at the prompt
out_prompt="${HOME}/out-prompt.p12"
printf '%s\n%s\n' "${pw}" "${pw}" | sca export p12 -o "${out_prompt}" user > /dev/null 2>&1 \
  || fail "export p12 at the prompt"
assert_not_leaked "export p12 at the prompt"
assert_opens "${out_prompt}" "${pw}" "export p12 at the prompt"

# --legacy still works
out_legacy="${HOME}/out-legacy.p12"
sca export p12 --legacy -p "${pw}" -o "${out_legacy}" user > /dev/null 2>&1 || fail "export p12 --legacy"
assert_not_leaked "export p12 --legacy"

# display with -p
status=0
output="$(sca display p12 -p "${pw}" "${out_p}" 2>&1)" || status=$?
assert_displays "${output}" "${status}" "display p12 -p"
assert_not_leaked "display p12 -p"

# display with the password typed at the prompt
status=0
output="$(printf '%s\n' "${pw}" | sca display p12 "${out_prompt}" 2>&1)" || status=$?
assert_displays "${output}" "${status}" "display p12 at the prompt"
assert_not_leaked "display p12 at the prompt"

# a wrong password still fails with the existing error
status=0
output="$(sca display p12 -p "wrong-${pw}" "${out_p}" 2>&1)" || status=$?
[ "${status}" -ne 0 ] || fail "display p12 with a wrong password: exit status 0"
[[ "${output}" == *"failed to read p12 file. check password."* ]] \
  || fail "display p12 with a wrong password: unexpected output: ${output}"
: > "${shim_log}"

# an empty password (Enter at the prompts), export then display
out_empty="${HOME}/out-empty.p12"
printf '\n\n' | sca export p12 -o "${out_empty}" user > /dev/null 2>&1 || fail "export p12 with an empty password"
assert_opens "${out_empty}" "" "export p12 with an empty password"
status=0
output="$(printf '\n' | sca display p12 "${out_empty}" 2>&1)" || status=$?
assert_displays "${output}" "${status}" "display p12 with an empty password"

# with -d the password must stay out of ~/.sca too: the log records the verb
# dispatch and each dispatcher's start line, and those once held raw argv
# assert_not_in_sca_folder WHAT - the password is in no file under ~/.sca
assert_not_in_sca_folder() {
  if grep -rqF -- "${pw}" "${HOME}/.sca"; then
    fail "$1: password written under ~/.sca:"
    grep -rF -- "${pw}" "${HOME}/.sca" >&2
  fi
}
out_d="${HOME}/out-d.p12"
sca -d export p12 -p "${pw}" -o "${out_d}" user > /dev/null 2>&1 || fail "-d export p12 -p"
assert_not_in_sca_folder "-d export p12 -p"
sca -d export p12 --password="${pw}" -o "${out_d}" user > /dev/null 2>&1 || fail "-d export p12 --password="
assert_not_in_sca_folder "-d export p12 --password="
sca -d export p12 --password "${pw}" -o "${out_d}" user > /dev/null 2>&1 || fail "-d export p12 --password"
assert_not_in_sca_folder "-d export p12 --password"
assert_opens "${out_d}" "${pw}" "-d export p12 --password"
status=0
output="$(sca -d display p12 -p "${pw}" "${out_d}" 2>&1)" || status=$?
assert_displays "${output}" "${status}" "-d display p12 -p"
assert_not_in_sca_folder "-d display p12 -p"
status=0
output="$(sca -d display p12 --password "${pw}" "${out_d}" 2>&1)" || status=$?
assert_displays "${output}" "${status}" "-d display p12 --password"
assert_not_in_sca_folder "-d display p12 --password"
# the log still names the verb and the subcommand
grep -qx 'sca: calling function for the verb export p12' "${HOME}/.sca/log" \
  || fail "-d log: no dispatch line for export p12"
grep -qx 'sca: calling function for the verb display p12' "${HOME}/.sca/log" \
  || fail "-d log: no dispatch line for display p12"
grep -qx 'display: finish (document_type=p12, rc=0)' "${HOME}/.sca/log" \
  || fail "-d log: no finish line for display p12"
grep -qx 'export_: finish (document_type=p12, rc=0)' "${HOME}/.sca/log" \
  || fail "-d log: no finish line for export p12"
: > "${shim_log}"

test_done
