#!/bin/bash
# init sca_usb_stick: the stick's bash completion is generated from the sca it
# ships, ~/bin/sca, so it is there whichever way sca was installed on the host:
# 'make deploy' never writes ~/bin/sca_completion, and a leftover one from
# 'sca install' is never copied. a missing ~/bin/sca, or a completion that
# cannot be generated, stops the build with an error instead of a bare 'cp:'
# line followed by exit 0.
#
# add_sca is called directly with sudo stubbed to run the command as the user,
# so nothing needs root. the build host, tools and download checks are stubbed,
# so the test runs on any host and offline.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

repo_dir="$(dirname "${tests_dir}")"
live_filesystem="$HOME/live_filesystem/"
stick_completion="${live_filesystem}etc/bash_completion.d/sca"
download_log="$HOME/download.log"

# run add_sca from the built sca, with sudo running its command as the user.
# verbosity is detailed, so any log output leaking into the generated
# completion would show
# shellcheck disable=SC2317 # the stubs are called by sca
add_sca_to_live_filesystem() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    export verbosity=vv
    export log_file="$HOME/.sca/log"
    sudo() { "$@"; }
    add_sca "${live_filesystem}" "${live_filesystem}opt/sca/" false test/ false false
  )
}

# run init sca_usb_stick from the built sca with the host checks and the
# download stubbed out. the download is logged, so the test can tell whether
# the build got that far
# shellcheck disable=SC2317 # the stubs are called by sca
init_sca_usb_stick() {
  (
    # shellcheck source=/dev/null
    . "${SCA}"
    check_build_host_ubuntu_version() { :; }
    check_iso_image_tools() { :; }
    download_ubuntu_image() { echo "download" >> "${download_log}"; return 1; }
    sudo() { return 1; }
    sca init sca_usb_stick
  )
}

sca config create all >/dev/null 2>&1 || fail "config create all"

# make deploy: the route the docs recommend, which leaves no ~/bin/sca_completion.
# make deploy runs the deployed sca, which a noexec temporary folder (e.g. /tmp)
# does not allow. there, copying the built sca to ~/bin/sca, which is what make
# deploy does with the default INSTALL_DIR, stands in for it
printf '#!/bin/sh\n' > "$HOME/exec_check" && chmod 755 "$HOME/exec_check"
if "$HOME/exec_check" 2>/dev/null; then
  make -s -C "${repo_dir}" deploy INSTALL_DIR="$HOME/bin" \
    COMPLETION_DIR="$HOME/.local/share/bash-completion/completions" >/dev/null 2>&1 || \
    fail "make deploy"
else
  echo "  note: $HOME is noexec, copying ${SCA} to ~/bin/sca instead of make deploy" >&2
  mkdir -p "$HOME/bin" && cp "${SCA}" "$HOME/bin/sca" && chmod 755 "$HOME/bin/sca"
fi
rm -f "$HOME/exec_check"
[ -e "$HOME/bin/sca_completion" ] && fail "make deploy wrote ~/bin/sca_completion"
expected="$(bash "$HOME/bin/sca" completion bash)"
[ -n "${expected}" ] || fail "bash \$HOME/bin/sca completion bash printed nothing"

rm -rf "${live_filesystem}"
output="$(add_sca_to_live_filesystem 2>&1)" || \
  fail "add_sca failed after make deploy: ${output}"
assert_file_exists "${stick_completion}" "no completion on the stick after make deploy"
[ -s "${stick_completion}" ] || fail "the stick's completion is empty after make deploy"
assert_eq "${expected}" "$(cat "${stick_completion}")" \
  "the stick's completion after make deploy is not ~/bin/sca completion bash"

# sca install: a stale ~/bin/sca_completion is left next to ~/bin/sca. it is
# never the source of the stick's completion
echo "# stale completion" > "$HOME/bin/sca_completion"
rm -rf "${live_filesystem}"
output="$(add_sca_to_live_filesystem 2>&1)" || \
  fail "add_sca failed with a ~/bin/sca_completion present: ${output}"
assert_eq "${expected}" "$(cat "${stick_completion}")" \
  "the stick's completion is not generated when ~/bin/sca_completion exists"

# a ~/bin/sca that cannot generate the completion fails add_sca
cp "$HOME/bin/sca" "$HOME/sca.deployed"
printf '#!/bin/bash\nexit 1\n' > "$HOME/bin/sca"
rm -rf "${live_filesystem}"
output="$(add_sca_to_live_filesystem 2>&1)" && \
  fail "a failed completion generation did not fail add_sca"
[[ "${output}" == *"could not generate the sca completion"* ]] || \
  fail "the error does not name the completion step: ${output}"

# no ~/bin/sca at all: add_sca fails, and so does the build, before downloading
rm -f "$HOME/bin/sca"
rm -rf "${live_filesystem}"
output="$(add_sca_to_live_filesystem 2>&1)" && \
  fail "a missing ~/bin/sca did not fail add_sca"
[[ "${output}" == *"~/bin/sca"* ]] || \
  fail "the add_sca error does not name ~/bin/sca: ${output}"

rm -f "${download_log}"
output="$(init_sca_usb_stick 2>&1)" && \
  fail "a missing ~/bin/sca did not fail init sca_usb_stick"
[[ "${output}" == *"~/bin/sca not found"* ]] || \
  fail "the init error does not name ~/bin/sca: ${output}"
[[ "${output}" == *"make deploy"* && "${output}" == *"sca install"* ]] || \
  fail "the init error does not say how to install sca: ${output}"
[ -e "${download_log}" ] && fail "init sca_usb_stick downloaded with no ~/bin/sca"

test_done
