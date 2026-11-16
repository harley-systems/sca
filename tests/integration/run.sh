#!/bin/bash
################################################################################
# integration test: runs tests/integration/sca_usb_stick.sh, which builds the
# sca usb stick image from a real ubuntu iso, in a privileged ubuntu container.
#
# not part of 'make check'; run it with 'make integration'. it needs:
#
# - docker, and the right to run a --privileged container (loop mounts). a
#   privileged container is root on this host: run it only on code you trust,
#   never on pull requests.
# - network: the ubuntu iso (~6 GB) on the first run, the apt packages every run.
# - ~15 GB free under docker's root.
#
# the iso and its SHA256SUMS / SHA256SUMS.gpg are kept between runs in a docker
# volume, SCA_INTEGRATION_CACHE (default sca-integration-downloads), so only
# the first run downloads the iso. remove the volume to start from scratch:
#   docker volume rm sca-integration-downloads
#
# UBUNTU_VERSION_ID (set by the Makefile) picks the ubuntu release of the
# container and of the image.

cd "$(dirname "$0")/../.." || exit 2

version_id="${UBUNTU_VERSION_ID:?UBUNTU_VERSION_ID is not set. run 'make integration'}"
cache="${SCA_INTEGRATION_CACHE:-sca-integration-downloads}"
image="ubuntu:${version_id%%-*}"

command -v docker > /dev/null || { echo "error: docker is required" >&2; exit 2; }

echo "sca usb stick integration test: ${image}, privileged, downloads cache in docker volume ${cache}"
echo "the first run downloads the ubuntu iso (~6 GB); later runs only SHA256SUMS and apt packages."
docker run --rm --privileged \
  -e UBUNTU_VERSION_ID="${version_id}" \
  -v "${cache}":/home/sca/.sca/downloads \
  -v "${PWD}":/src:ro \
  "${image}" bash /src/tests/integration/sca_usb_stick.sh
