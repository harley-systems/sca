#!/bin/bash
################################################################################
# on a real yubikey: security_key init (and --roll-keys), create key (upload
# key), upload crt (and --force), verify and unblock_pin (with and without
# --keep-pin) work with the pin, puk and management key passed on stdin and in
# the environment, and none of them is ever on a tool's command line.
#
# this RESETS the PIV application of the key: run it only through the fixture
# broker, against a test key:
#   yubikey-fixture run tests/hw/security_key_secrets.sh "$(git rev-parse HEAD)" 4
#
# self-contained for now; once the broker's tests/hw/lib.sh is on main it can
# use that instead.

set -u

if [ -z "${YUBIKEY_FIXTURE_SERIAL:-}" ]; then
  echo "error: run this through the fixture broker (yubikey-fixture run ...)" >&2
  exit 2
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

yk() {
  ykman --device "${YUBIKEY_FIXTURE_SERIAL}" "$@"
}

echo "yubico-piv-tool: $(yubico-piv-tool --version 2>&1 | head -n 1)"
echo "opensc: $(opensc-tool --info 2>&1 | head -n 1)"
echo "ykman: $(ykman --version 2>&1 | head -n 1)"

# the source is read-only, so sca is built in a copy
work="$(mktemp -d)"
cp -r "$(cd "$(dirname "$0")/../.." && pwd)" "${work}/sca"
make -C "${work}/sca" >/dev/null || fail "building sca"
sca() {
  bash "${work}/sca/build/sca.sh" -d "$@"
}

# every yubico-piv-tool and pkcs11-tool call sca makes is recorded with its
# argv, then handed to the real tool
export REAL_YUBICO_PIV_TOOL REAL_PKCS11_TOOL ARGV_LOG="${work}/argv"
REAL_YUBICO_PIV_TOOL="$(command -v yubico-piv-tool)"
REAL_PKCS11_TOOL="$(command -v pkcs11-tool)"
yubico-piv-tool() {
  echo "yubico-piv-tool $*" >> "${ARGV_LOG}"
  "${REAL_YUBICO_PIV_TOOL}" "$@"
}
pkcs11-tool() {
  echo "pkcs11-tool $*" >> "${ARGV_LOG}"
  "${REAL_PKCS11_TOOL}" "$@"
}
export -f yubico-piv-tool pkcs11-tool

# step NAME COMMAND... - run an sca command, show its output, stop if it fails
step() {
  local name="$1"
  shift
  echo "== ${name}"
  "$@" 2>&1 | tee "${work}/out"
  [ "${PIPESTATUS[0]}" -eq 0 ] || fail "${name}"
}

yk piv reset -f >/dev/null || fail "piv reset"

sca config create all >/dev/null 2>&1 || fail "config create all"
cat >> "$HOME/.sca/config/sca.config" <<EOF
export subca_security_key_id=${YUBIKEY_FIXTURE_SERIAL}
export subca_yubikey_touch_policy=never
EOF

file_of() {
  find "$HOME/.sca" -name "*-subca-yubikey-$1.txt"
}

step "security_key init subca" sca security_key init subca
step "create key subca (uploads the key)" sca create key subca
key_file="$(find "$HOME/.sca" -name '*-subca-key.pem')"
crt_file="$(dirname "$(dirname "${key_file}")")/$(basename "${key_file%key.pem}")crt.pem"
openssl req -x509 -new -key "${key_file}" -subj /CN=sca-hw-test -days 1 -out "${crt_file}" || \
  fail "a certificate to upload"
step "security_key upload subca crt" sca security_key upload subca crt
step "security_key upload --force subca crt" sca security_key upload --force subca crt
step "security_key verify subca" sca security_key verify subca
grep -q SUCCESS "${work}/out" || fail "verify did not sign"

# block the pin with three wrong ones, then unblock it with the stored puk
block_pin() {
  local wrong=000000 _
  [ "$(cat "$(file_of pin)")" = "${wrong}" ] && wrong=999999
  for _ in 1 2 3; do
    yk piv access change-pin -P "${wrong}" -n "${wrong}" >/dev/null 2>&1
  done
  yk piv info | grep -i "pin tries remaining"
}
block_pin
step "security_key unblock_pin --keep-pin subca" sca security_key unblock_pin --keep-pin subca
step "security_key verify subca (after --keep-pin)" sca security_key verify subca
grep -q SUCCESS "${work}/out" || fail "verify after unblock_pin --keep-pin"
block_pin
step "security_key unblock_pin subca" sca security_key unblock_pin subca
step "security_key verify subca (after a new pin)" sca security_key verify subca
grep -q SUCCESS "${work}/out" || fail "verify after unblock_pin"

step "security_key init --roll-keys subca" sca security_key init --roll-keys subca
step "security_key verify subca (after --roll-keys)" sca security_key verify subca
grep -q SUCCESS "${work}/out" || fail "verify after init --roll-keys"

echo "== command lines"
cat "${ARGV_LOG}"
leaked=0
while read -r secret; do
  [ -n "${secret}" ] || continue
  if grep -qF -- "${secret}" "${ARGV_LOG}" "$HOME/.sca/log"; then
    echo "a pin, puk or management key is on a command line or in the log" >&2
    leaked=1
  fi
done < <(printf '%s\n' 010203040506070801020304050607080102030405060708 123456 12345678; \
  find "$HOME/.sca" -name '*yubikey-*.txt*' -exec sh -c 'cat "$1"; echo' _ {} \;)
[ "${leaked}" -eq 0 ] || fail "secrets leaked"

yk piv reset -f >/dev/null
echo "PASS"
