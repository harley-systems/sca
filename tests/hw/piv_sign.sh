#!/bin/bash
# PIV on the test key: generate a 9c key (touch policy never), sign a
# certificate with it using PIN 123456, and check the signature with openssl
# shellcheck source=tests/hw/lib.sh
. "$(dirname "$0")/lib.sh"

make_key
sign || fail "signing with the 9c key"
[ "$(openssl x509 -in /tmp/cert.pem -noout -pubkey)" = "$(openssl pkey -pubin -in /tmp/pub.pem)" ] \
  || fail "the certificate is not for the 9c key"
openssl verify -partial_chain -check_ss_sig -CAfile /tmp/cert.pem /tmp/cert.pem \
  || fail "the certificate's signature does not verify"
echo "PASS"
