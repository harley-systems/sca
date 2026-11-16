#!/bin/bash
################################################################################
# install the YubiKey fixture broker as a systemd user service
#
# - builds the test image (sca-yubikey-fixture, or the image set in the config)
# - copies the example config to ~/.config/sca/yubikey-fixture.conf if there is
#   none (an existing config is never overwritten)
# - installs sca-yubikey-fixture.socket and .service into ~/.config/systemd/user/,
#   pointing at the broker in this checkout, and starts the socket
#
# needs docker (your user in the docker group) and the fixture's udev rule
# (70-yktouch.rules). see README.md, "Fixture broker".

set -euo pipefail

broker_dir="$(cd "$(dirname "$0")" && pwd)"
fixture_dir="$(dirname "${broker_dir}")"
config="${XDG_CONFIG_HOME:-${HOME}/.config}/sca/yubikey-fixture.conf"
unit_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"

if [ ! -f "${config}" ]; then
  mkdir -p "$(dirname "${config}")"
  cp "${broker_dir}/yubikey-fixture.conf.example" "${config}"
  echo "wrote ${config}: check the slots and serials in it"
fi

image="$(sed -n 's/^[[:space:]]*image[[:space:]]*=[[:space:]]*//p' "${config}" | tail -n 1)"
docker build -t "${image:-sca-yubikey-fixture}" -f "${broker_dir}/Dockerfile" "${fixture_dir}"

mkdir -p "${unit_dir}"
cp "${broker_dir}/sca-yubikey-fixture.socket" "${unit_dir}/"
sed "s|@BROKER@|${fixture_dir}/yubikey-fixture-broker|" \
  "${broker_dir}/sca-yubikey-fixture.service" > "${unit_dir}/sca-yubikey-fixture.service"
systemctl --user daemon-reload
systemctl --user enable --now sca-yubikey-fixture.socket
systemctl --user try-restart sca-yubikey-fixture.service   # pick up a changed broker
echo "broker installed: ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sca-yubikey-fixture.sock"
