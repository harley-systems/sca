#!/bin/bash
# sca scrub_log must redact every secret an older sca wrote to its log -- pins,
# management keys and p12 passwords -- and leave the rest of each line alone.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

sca config create all > /dev/null 2>&1 || fail "config create all"

pin="918273"
mgmt="0a1b2c3d4e5f60718293a4b5c6d7e8f9"
pw="s3cr3t-p12-$$"
log="${HOME}/old.log"

# lines as older versions wrote them, each followed by what scrub_log must
# leave of it
expected=()
add() {
  printf '%s\n' "$1" >> "${log}"
  expected+=("$2")
}
# pins and management keys
add "ykman piv access change-pin --pin-value=${pin} --new-pin=x" \
    "ykman piv access change-pin --pin-value=<REDACTED> --new-pin=x"
add "openssl pkcs12 -passin pass:${pin} -in a.p12" \
    "openssl pkcs12 -passin pass:<REDACTED> -in a.p12"
add "OPENSSL_PKCS11_PIN=${pin} openssl req" \
    "OPENSSL_PKCS11_PIN=<REDACTED> openssl req"
add "yubico-piv-tool --key=${mgmt} -a generate" \
    "yubico-piv-tool --key=<REDACTED> -a generate"
add "ykman piv keys generate -k ${mgmt} 9c" \
    "ykman piv keys generate -k <REDACTED> 9c"
add "security_key: management key is set '${mgmt}'" \
    "security_key: management key is set '<REDACTED>'"
# p12 passwords: the verb dispatch line, in every form getopt accepts
add "sca: calling function for the verb export p12 -p ${pw} service" \
    "sca: calling function for the verb export p12 -p <REDACTED> service"
add "sca: calling function for the verb export p12 --legacy -o out.p12 --password ${pw} service" \
    "sca: calling function for the verb export p12 --legacy -o out.p12 --password <REDACTED> service"
add "sca: calling function for the verb export p12 --password=${pw} service" \
    "sca: calling function for the verb export p12 --password=<REDACTED> service"
add "sca: calling function for the verb export p12 -lp${pw} service" \
    "sca: calling function for the verb export p12 -lp<REDACTED> service"
add "sca: calling function for the verb display p12 --pass ${pw} out.p12" \
    "sca: calling function for the verb display p12 --pass <REDACTED> out.p12"
add "sca: calling function for the verb display p12 --password ${pw} service" \
    "sca: calling function for the verb display p12 --password <REDACTED> service"
# p12 passwords: the display and export start and finish lines
add "display: start (document_type=p12, entity=--password, entity_id=${pw})" \
    "display: start (document_type=p12, entity=--password, entity_id=<REDACTED>)"
add "display: start (document_type=p12, entity=-p, entity_id=${pw})" \
    "display: start (document_type=p12, entity=-p, entity_id=<REDACTED>)"
add "display: start (document_type=p12, entity=-p${pw}, entity_id=out.p12)" \
    "display: start (document_type=p12, entity=-p<REDACTED>, entity_id=out.p12)"
add "display: finish (document_type=p12, entity=--password=${pw}, rc=0)" \
    "display: finish (document_type=p12, entity=--password=<REDACTED>, rc=0)"
add "export_: start (document_type=p12, entity=--password=${pw})" \
    "export_: start (document_type=p12, entity=--password=<REDACTED>)"
add "export_: finish (document_type=p12, entity=--password=${pw}, rc=0)" \
    "export_: finish (document_type=p12, entity=--password=<REDACTED>, rc=0)"
# lines that hold no secret stay as they are
for line in \
  "sca: calling function for the verb export p12 service" \
  "sca: calling function for the verb export crt_pub_ssh -p service" \
  "display: start (document_type=p12, entity=-p, entity_id=)" \
  "export_: start (document_type=p12, entity=service)" \
  "export_: finish (document_type=p12, entity=-p, rc=1)" \
  "openssl pkcs12 -export -passout env:SCA_P12_PASSWORD"; do
  add "${line}" "${line}"
done

output="$(sca scrub_log "${log}" 2>&1)" || fail "scrub_log failed: ${output}"
assert_eq "secrets redacted from ${log}." "${output}" "scrub_log output"

mapfile -t actual < "${log}"
assert_eq "${#expected[@]}" "${#actual[@]}" "number of lines after scrub_log"
for i in "${!expected[@]}"; do
  assert_eq "${expected[$i]}" "${actual[$i]}" "line $((i + 1))"
done
for secret in "${pin}" "${mgmt}" "${pw}"; do
  grep -qF -- "${secret}" "${log}" && fail "secret '${secret}' still in the scrubbed log"
done

# a second run finds nothing left
output="$(sca scrub_log "${log}" 2>&1)" || fail "second scrub_log failed: ${output}"
assert_eq "no secrets found in ${log}." "${output}" "second scrub_log output"

test_done
