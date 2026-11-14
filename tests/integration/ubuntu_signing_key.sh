#!/bin/bash
################################################################################
# integration check: the live ubuntu SHA256SUMS is still signed by the pinned
# ubuntu cd image signing key.
#
# if ubuntu ever re-signs SHA256SUMS with another key, every sca usb stick build
# stops at the signature check. this catches it without a build:
#
# - sca's own download_ubuntu_sha256sums, without stubs, against the live
#   releases.ubuntu.com: download, the pinned fingerprint check and the latest
#   desktop iso being listed. it passes only if a real build gets past that step.
# - the manual gpgv commands docs/air-gapped-operations.md tells the reader to
#   run, on the same files.
#
# needs: network (a few kilobytes from releases.ubuntu.com), wget, gpg, gpgv.
# no iso, no sudo, no container. not part of 'make check'; run it with
# 'make check-ubuntu-key'. the ubuntu version comes from UBUNTU_VERSION_ID
# (set by the Makefile), defaulting to the one built into sca.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/../lib.sh"

src_dir="$(dirname "${tests_dir}")"
keyring_asc="${src_dir}/src/init/sca_usb_stick/ubuntu-cdimage-keyring.asc"
pinned_fingerprint="843938DF228D22F7B3742BC0D94AA3F0EFE21092"
work="$HOME/downloads/"

for tool in wget gpg gpgv; do
  command -v "${tool}" > /dev/null || { echo "error: ${tool} is required" >&2; exit 2; }
done

# run an sca function from the built sca, as is: no stubs
run_sca() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    # shellcheck disable=SC2034 # read by sca
    log_file="$HOME/sca.log"
    "$@"
  )
}

# shellcheck source=/dev/null
version_id="${UBUNTU_VERSION_ID:-$(. "${SCA}"; echo "${sca_ubuntu_version_id}")}"
version="${version_id%%-*}"
sums="ubuntu-${version}-SHA256SUMS"
echo "ubuntu ${version}: checking the live SHA256SUMS{,.gpg} (a few kilobytes) against ${pinned_fingerprint}"

# sca's own check, against the live servers
mkdir -p "${work}"
if base_url="$(run_sca download_ubuntu_sha256sums "${version}" "${work}")"; then
  echo "  sca: SHA256SUMS from ${base_url} is signed by the pinned key"
  latest="$(run_sca get_latest_ubuntu_iso_filename "${version}" "${work}${sums}")"
  echo "  sca: latest desktop iso listed: ${latest}"
  [ -n "${latest}" ] || fail "no ubuntu ${version} desktop iso listed in ${base_url}SHA256SUMS"
else
  fail "sca's download_ubuntu_sha256sums ${version} failed: a real build would stop here"
  test_done
fi
[ "${pinned_fingerprint}" == "$(run_sca get_ubuntu_cdimage_signing_key_fingerprint)" ] || \
  fail "the fingerprint pinned in sca is not ${pinned_fingerprint}; update this check with it"

# the manual check from docs/air-gapped-operations.md, on the same files
cd "${work}" || exit 2
gpg --dearmor < "${keyring_asc}" > ubuntu-cdimage-keyring.gpg || fail "gpg --dearmor of ${keyring_asc}"
if output="$(gpgv --keyring ./ubuntu-cdimage-keyring.gpg "${sums}.gpg" "${sums}" 2>&1)"; then
  [[ "${output}" == *"Good signature"* ]] || fail "documented gpgv: no 'Good signature': ${output}"
  [[ "${output}" == *"${pinned_fingerprint}"* ]] || fail "documented gpgv: key ${pinned_fingerprint} not named: ${output}"
else
  fail "documented gpgv failed: ${output}"
fi
signers="$(gpgv --status-fd 1 --keyring ./ubuntu-cdimage-keyring.gpg "${sums}.gpg" "${sums}" 2> /dev/null | \
  awk '$2 == "VALIDSIG" { print $NF }')"
echo "${signers}" | grep -qx "${pinned_fingerprint}" || \
  fail "gpgv VALIDSIG primary key: expected ${pinned_fingerprint}, got '${signers}'"

[ "${test_failures}" -eq 0 ] && echo "  documented gpgv: Good signature, VALIDSIG ${pinned_fingerprint}"
test_done
