#!/bin/bash
# ca flow: the software-key CA path end to end. a root CA, a sub-CA it signs,
# a service certificate the sub-CA approves and the service's p12 bundle must
# all be made with the documented commands, and openssl must accept the chain.
#
# this is the software baseline for the hardware tests: it uses no security
# key, and the tools that could reach one (ykman, yubico-piv-tool, pkcs11-tool,
# p11tool, gpg) are stubbed as exported shell functions that record the call
# and fail, so the run can never touch a real key.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

key_tools_log="${HOME}/key-tools.log"
: > "${key_tools_log}"
# shellcheck disable=SC2317 # the stubs are called by sca
{
  ykman() { echo "ykman $*" >> "${key_tools_log}"; return 1; }
  yubico-piv-tool() { echo "yubico-piv-tool $*" >> "${key_tools_log}"; return 1; }
  pkcs11-tool() { echo "pkcs11-tool $*" >> "${key_tools_log}"; return 1; }
  p11tool() { echo "p11tool $*" >> "${key_tools_log}"; return 1; }
  gpg() { echo "gpg $*" >> "${key_tools_log}"; return 1; }
}
export key_tools_log
export -f ykman yubico-piv-tool pkcs11-tool p11tool gpg

# run_sca - the built sca with stdin closed, so a prompt fails instead of
# waiting, and a timeout, so a hang fails fast
run_sca() {
  timeout -k 5 60 bash "${SCA}" "$@" < /dev/null
}

# step ARGS... - run sca ARGS; on failure report it and stop the file, so one
# broken step doesn't cascade into unrelated failures
step() {
  local output status
  output="$(run_sca "$@" 2>&1)"
  status=$?
  [ "${status}" -eq 0 ] && return 0
  if [ "${status}" -eq 124 ]; then
    fail "sca $* timed out"
  else
    fail "sca $* exited ${status}"
  fi
  [ -n "${output}" ] && echo "${output}" >&2
  test_done
}

p12_password="ca-flow-test-password"

step config create all
# positional, with a space in the organisation: the form that broke on #205
step config set ca test "Test Inc"
step config set subca subca ops
step config set service service web
step config set ca use_security_key false
step config set subca use_security_key false

# never go on to create keys with a config that would use a security key
for entity in ca subca; do
  if ! grep -qx "export ${entity}_use_security_key_default=false" \
    "${HOME}/.sca/config/sca.config"; then
    fail "${entity}_use_security_key_default is not false in sca.config"
    test_done
  fi
done

step create key ca
step create csr ca
step create crt ca
step create key subca
step create csr subca
step approve subca
step create key service
step create csr service
step approve service
step export p12 service -p "${p12_password}"

keys="${HOME}/.sca/keys/test"
ca_crt="${keys}/test-ca-crt.pem"
subca_crt="${keys}/ops/test-ops-subca-crt.pem"
service_dir="${keys}/ops/services/web"
service_crt="${service_dir}/test-ops-web-crt.pem"
service_key="${service_dir}/private/test-ops-web-key.pem"
service_pub_ssh="${service_dir}/test-ops-web-pub.ssh"
p12="${HOME}/.sca/transfer/web.p12"
for file in "${ca_crt}" "${subca_crt}" "${service_crt}" "${service_key}" \
  "${service_dir}/test-ops-web-pub.pem" "${p12}"; do
  assert_file_exists "${file}"
done

# the chain verifies, also for a tls server
assert_succeeds openssl verify -CAfile "${ca_crt}" -untrusted "${subca_crt}" \
  "${service_crt}"
assert_succeeds openssl verify -purpose sslserver -CAfile "${ca_crt}" \
  -untrusted "${subca_crt}" "${service_crt}"

# the service certificate has the configured name
subject="$(openssl x509 -in "${service_crt}" -noout -subject -nameopt multiline)"
cn="$(sed -n 's/^ *commonName *= //p' <<< "${subject}")"
assert_eq "web.test.systems" "${cn}" "service certificate CN"

# the organisation keeps its space on every certificate
for crt in "${ca_crt}" "${subca_crt}" "${service_crt}"; do
  org="$(openssl x509 -in "${crt}" -noout -subject -nameopt multiline \
    | sed -n 's/^ *organizationName *= //p')"
  assert_eq "Test Inc" "${org}" "organizationName of $(basename "${crt}")"
done

# extensions: a tls server leaf under two CAs, the root self-signed
service_text="$(openssl x509 -in "${service_crt}" -noout -text)"
grep -q "TLS Web Server Authentication" <<< "${service_text}" \
  || fail "service certificate has no serverAuth extended key usage"
grep -q "CA:FALSE" <<< "${service_text}" \
  || fail "service certificate is not CA:FALSE"
grep -q "CA:TRUE" <<< "$(openssl x509 -in "${subca_crt}" -noout -text)" \
  || fail "sub-CA certificate is not CA:TRUE"
grep -q "CA:TRUE" <<< "$(openssl x509 -in "${ca_crt}" -noout -text)" \
  || fail "root CA certificate is not CA:TRUE"
assert_eq "$(openssl x509 -in "${ca_crt}" -noout -subject | sed 's/^subject=//')" \
  "$(openssl x509 -in "${ca_crt}" -noout -issuer | sed 's/^issuer=//')" \
  "root CA is not self-signed (subject vs issuer)"

# the p12 opens with its password and holds the service key, the service
# certificate and both CA certificates. the password is a throwaway, so
# passing it on the command line is fine here
if p12_text="$(openssl pkcs12 -in "${p12}" -passin "pass:${p12_password}" \
  -nodes 2>/dev/null)"; then
  assert_eq 1 "$(grep -c -- '-----BEGIN .*PRIVATE KEY-----' <<< "${p12_text}")" \
    "private keys in the p12"
  assert_eq 3 "$(grep -c -- '-----BEGIN CERTIFICATE-----' <<< "${p12_text}")" \
    "certificates in the p12"
  assert_eq "$(openssl pkey -in "${service_key}" -pubout 2>&1)" \
    "$(openssl pkey -pubout 2>&1 <<< "${p12_text}")" \
    "p12 key does not match the service key"
  assert_eq "$(openssl x509 -in "${service_crt}" -noout -pubkey 2>&1)" \
    "$(openssl pkey -pubout 2>&1 <<< "${p12_text}")" \
    "p12 key does not match the service certificate"
else
  fail "p12 does not open with its password"
fi
assert_fails openssl pkcs12 -in "${p12}" -passin pass:wrong-password -nodes

# the ssh public key needs ssh-keygen; without it approve leaves an empty file
if command -v ssh-keygen > /dev/null; then
  [ -s "${service_pub_ssh}" ] || fail "ssh public key is missing or empty: ${service_pub_ssh}"
  assert_succeeds ssh-keygen -l -f "${service_pub_ssh}"
else
  echo "  skip: ssh-keygen not installed, .pub.ssh not checked"
fi

# request, approve and display for another service switch to it for a moment
# and must put the configuration back exactly, spaced organisation included
before_config="$(cat "${HOME}/.sca/config/sca.config")"
step request service api
step approve service api
step display crt service api
step display pub service api
assert_file_exists "${keys}/ops/services/api/test-ops-api-crt.pem"
assert_eq '"web"' "$(run_sca config get service)" "config get service after switching"
assert_eq '"test" "Test Inc"' "$(run_sca config get ca)" "config get ca after switching"
assert_eq "${before_config}" "$(cat "${HOME}/.sca/config/sca.config")" \
  "config file after switching"

# config get for another user reads the names from its certificate subject
# only: the issuer (the sub-CA, which has a GN by default) must not leak in
step request user bob Bob Builder Robert B.B.
step approve user bob
assert_eq '"bob" "Bob" "Builder" "Robert" "B.B."' \
  "$(run_sca config get user bob)" "config get user bob"

# nothing tried to reach a security key
assert_eq "" "$(cat "${key_tools_log}")" "security key tools were called"

test_done
