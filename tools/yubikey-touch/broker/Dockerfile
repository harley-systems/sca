# Test image for the YubiKey fixture broker: what a tests/hw/ script can use.
# Built by install.sh from tools/yubikey-touch/ (the build context).
FROM debian:stable-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash make openssl opensc pcscd libccid python3 yubikey-manager yubico-piv-tool ykcs11 \
 && rm -rf /var/lib/apt/lists/*
COPY yubikey-fixture /usr/local/bin/yubikey-fixture
COPY broker/run-step /usr/local/bin/run-step
ENTRYPOINT ["/usr/local/bin/run-step"]
