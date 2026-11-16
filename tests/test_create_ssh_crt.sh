#!/bin/bash
# create ssh_crt: OpenSSH user and host certificates signed by the subca (or
# ca) key, from a key file as in the sca init demo setup, and, when SoftHSM is
# installed, from a PKCS#11 token standing in for the yubikey, with the PIN
# read from the PIN file and kept off the command line and out of the log.
#
# fixtures/ssh_crt holds FIDO2 public keys (sk-ssh-ed25519@openssh.com and
# sk-ecdsa-sha2-nistp256@openssh.com) built from fixed test points: only the
# public key is needed to certify one, so no FIDO2 device is involved.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

if ! command -v ssh-keygen > /dev/null; then
  echo "  skipped: ssh-keygen is not installed"
  test_done
fi

fixtures="${tests_dir}/fixtures/ssh_crt"

# the demo's subca works from its own key folder; its key is a file there
assert_succeeds sca config create all
sca init demo "$HOME/demo" > /dev/null 2>&1
export key_folder="$HOME/demo/subca-key/"
export subca_use_security_key=false
export ca_use_security_key=false
subca_folder="${key_folder}harley/aharon/"
subca_pub_ssh="${subca_folder}harley-aharon-subca-pub.ssh"
user_cert="${subca_folder}users/aharon/harley-aharon-aharon-pub-ssh-cert.pub"
host_cert="${subca_folder}hosts/black/harley-aharon-black-pub-ssh-cert.pub"

# the line of ssh-keygen -L output that starts with the given label
cert_field() {
  ssh-keygen -L -f "$1" | sed -n "s/^ *$2: *//p"
}
# the principals, one per line, of the certificate
cert_principals() {
  ssh-keygen -L -f "$1" | awk '/^ *Principals:/ { p = 1; next } p && /^ *[A-Z][A-Za-z ]*:/ { p = 0 } p { print $1 }'
}
ca_fingerprint() {
  ssh-keygen -l -f "$1" | awk '{ print $2 }'
}

# --- user certificate, signed by the subca key file
assert_succeeds sca create ssh_crt user
assert_file_exists "$user_cert" "user certificate"
assert_eq "\"aharon@harley.systems\"" "$(cert_field "$user_cert" "Key ID")" "user key id"
assert_eq "aharon" "$(cert_principals "$user_cert")" "user principals"
case "$(cert_field "$user_cert" Type)" in
  *"user certificate" ) ;;
  * ) fail "user certificate type: $(cert_field "$user_cert" Type)" ;;
esac
case "$(cert_field "$user_cert" "Signing CA")" in
  *"$(ca_fingerprint "$subca_pub_ssh")"* ) ;;
  * ) fail "user certificate is not signed by the key in $subca_pub_ssh" ;;
esac
case "$(cert_field "$user_cert" Valid)" in
  "from "*" to "* ) ;;
  * ) fail "user certificate validity: $(cert_field "$user_cert" Valid)" ;;
esac

# --- a second run without --force refuses and leaves the certificate alone
before="$(cat "$user_cert")"
assert_fails sca create ssh_crt user
assert_eq "$before" "$(cat "$user_cert")" "certificate unchanged without --force"
# --- with --force, the old one is backed up
assert_succeeds sca create ssh_crt -f --validity +1d --principals alice,bob user
assert_eq 1 "$(find "$(dirname "$user_cert")" -name "$(basename "$user_cert").*.bak" | wc -l)" \
  "backup of the replaced certificate"
assert_eq "alice
bob" "$(cert_principals "$user_cert")" "--principals"
valid="$(cert_field "$user_cert" Valid)"
valid_from="$(date -d "$(echo "$valid" | awk '{ print $2 }')" +%s)"
valid_to="$(date -d "$(echo "$valid" | awk '{ print $4 }')" +%s)"
[ $((valid_to - valid_from)) -le $((24 * 3600 + 120)) ] || fail "--validity +1d gave: $valid"

# --- host certificate
assert_succeeds sca create ssh_crt host
assert_file_exists "$host_cert" "host certificate"
case "$(cert_field "$host_cert" Type)" in
  *"host certificate" ) ;;
  * ) fail "host certificate type: $(cert_field "$host_cert" Type)" ;;
esac
assert_eq "black.harley.systems" "$(cert_principals "$host_cert")" "host principal"
next_steps="$(sca create ssh_crt -f host 2>&1)"
case "$next_steps" in
  *"@cert-authority *.harley.systems $(cat "$subca_pub_ssh")"* ) ;;
  * ) fail "host next steps lack the known_hosts line: $next_steps" ;;
esac

# --- --pub signs any OpenSSH public key, including FIDO2 ones
ssh-keygen -q -t ed25519 -N '' -C test -f "$HOME/id_ed25519"
for key in "$HOME/id_ed25519.pub" "$fixtures/sk-ssh-ed25519.pub" \
    "$fixtures/sk-ecdsa-sha2-nistp256.pub"; do
  assert_succeeds sca create ssh_crt -f --pub "$key" user
  assert_eq "$(ca_fingerprint "$key")" \
    "$(cert_field "$user_cert" "Public key" | awk '{ print $2 }')" "--pub $(basename "$key")"
done

# --- the ca can sign too, from its own key folder
assert_succeeds env key_folder="$HOME/demo/ca-key/" bash "$SCA" create ssh_crt \
  --pub "$HOME/id_ed25519.pub" user ca
ca_user_cert="$HOME/demo/ca-key/harley/aharon/users/aharon/harley-aharon-aharon-pub-ssh-cert.pub"
assert_file_exists "$ca_user_cert" "user certificate signed by the ca"
case "$(cert_field "$ca_user_cert" "Signing CA")" in
  *"$(ca_fingerprint "$HOME/demo/ca-key/harley/harley-ca-pub.ssh")"* ) ;;
  * ) fail "certificate is not signed by the ca" ;;
esac

# --- errors, none of which touches the existing certificate
before="$(cat "$user_cert")"
assert_fails sca create ssh_crt service
assert_fails sca create ssh_crt user user
assert_fails sca create ssh_crt -f --pub "$HOME/no-such-key.pub" user
assert_fails sca create ssh_crt -f --pub "$HOME/id_ed25519" user
assert_fails sca create ssh_crt -f --validity not-a-time user
assert_eq "$before" "$(cat "$user_cert")" "a failed run leaves the certificate in place"
rm -f "${subca_folder}users/aharon/harley-aharon-aharon-pub.ssh"
assert_fails sca create ssh_crt -f user

# --- token signer, with SoftHSM standing in for the yubikey's PKCS#11 module
softhsm_module=''
for candidate in "${SOFTHSM2_MODULE:-}" /usr/lib/softhsm/libsofthsm2.so \
    /usr/lib/*-linux-gnu/softhsm/libsofthsm2.so; do
  [ -n "$candidate" ] && [ -f "$candidate" ] && { softhsm_module="$candidate"; break; }
done
if [ -z "$softhsm_module" ] || ! command -v softhsm2-util > /dev/null; then
  echo "  skipped the token signer checks: SoftHSM is not installed"
  test_done
fi
pin=482916
pin_file="${subca_folder}private/harley-aharon-subca-yubikey-pin.txt"
printf '%s' "$pin" > "$pin_file"
mkdir -p "$HOME/tokens"
export SOFTHSM2_CONF="$HOME/softhsm2.conf"
printf 'directories.tokendir = %s\nobjectstore.backend = file\n' "$HOME/tokens" > "$SOFTHSM2_CONF"
softhsm2-util --module "$softhsm_module" --init-token --free --label subca \
  --pin "$pin" --so-pin 12345678 > /dev/null
softhsm2-util --module "$softhsm_module" --import "${subca_folder}private/harley-aharon-subca-key.pem" \
  --token subca --label subca --id 02 --pin "$pin" > /dev/null
mv "${subca_folder}private/harley-aharon-subca-key.pem" "$HOME/subca-key.pem"

# one yubikey with the serial the default config expects for the subca
# shellcheck disable=SC2317 # the stubs are called by sca
opensc-tool() {
  [ "$1" = "--list-readers" ] || return 1
  printf 'Nr.  Card  Features  Name\n'
  printf '0    Yes             Yubico YubiKey OTP+FIDO+CCID 00 00\n'
}
# shellcheck disable=SC2317
ykman() {
  echo "Serial number: 5414483"
}
export -f opensc-tool ykman
# ssh-keygen as a script on PATH that records its arguments
mkdir -p "$HOME/bin"
printf '#!/bin/sh\necho "$*" >> "%s"\nexec "%s" "$@"\n' "$HOME/ssh-keygen.args" \
  "$(command -v ssh-keygen)" > "$HOME/bin/ssh-keygen"
chmod 755 "$HOME/bin/ssh-keygen"

if ! token_output="$(env PATH="$HOME/bin:$PATH" subca_use_security_key=true \
    ykcs11_module="$softhsm_module" bash "$SCA" -d create ssh_crt -f \
    --pub "$HOME/id_ed25519.pub" user 2>&1)"; then
  fail "expected success: create ssh_crt with the subca on a token"
  echo "$token_output" >&2
fi
case "$token_output" in
  *"$pin"* ) fail "the PIN is in the -d output" ;;
esac
assert_file_exists "$HOME/ssh-keygen.args" "ssh-keygen was run"
case "$(cert_field "$user_cert" "Signing CA")" in
  *"$(ca_fingerprint "$subca_pub_ssh")"* ) ;;
  * ) fail "token-signed certificate is not signed by the key in $subca_pub_ssh" ;;
esac
grep -q -- "-D $softhsm_module" "$HOME/ssh-keygen.args" || fail "ssh-keygen was not given the PKCS#11 module"
grep -q "$pin" "$HOME/ssh-keygen.args" && fail "the PIN is in the ssh-keygen arguments"
grep -q "$pin" "$HOME/.sca/log" && fail "the PIN is in the detailed log"

test_done
