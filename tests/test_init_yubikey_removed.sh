#!/bin/bash
# init yubikey was replaced by security_key init. it only points there: it
# exits non-zero, never calls a device tool, and writes or renames no files.
# it is gone from the init help and the init tab completion.
#
# the device tools are stubbed as exported shell functions that leave a
# marker, so any call to them shows.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

marker="$HOME/device-tool-called"
# shellcheck disable=SC2317 # the stubs are called by sca
yubico-piv-tool() { echo "yubico-piv-tool $*" >> "${marker}"; }
# shellcheck disable=SC2317
opensc-tool() { echo "opensc-tool $*" >> "${marker}"; }
# shellcheck disable=SC2317
ykman() { echo "ykman $*" >> "${marker}"; }
export -f yubico-piv-tool opensc-tool ykman

sca config create all >/dev/null 2>&1 || fail "config create all"
before="$(find "$HOME" -printf '%p %s %T@\n' | sort)"

for args in "" "--roll-keys" "-r" "-h" "--help" "subca" "--roll-keys subca"; do
  # shellcheck disable=SC2086 # split the arguments on purpose
  assert_fails sca init yubikey ${args}
  # shellcheck disable=SC2086
  stderr="$(sca init yubikey ${args} 2>&1 >/dev/null)"
  for word in "sca security_key init" "--roll-keys" "--device SERIAL" "--help"; do
    [[ "${stderr}" == *"${word}"* ]] || \
      fail "'sca init yubikey ${args}' does not name '${word}': ${stderr}"
  done
done

[ -e "${marker}" ] && fail "init yubikey called a device tool: $(cat "${marker}")"
assert_eq "${before}" "$(find "$HOME" -printf '%p %s %T@\n' | sort)" \
  "init yubikey changed files under \$HOME"

# help and the invalid value error list only the remaining systems
sca init --help | grep -qw yubikey && fail "sca init --help still lists yubikey"
stderr="$(sca init foo 2>&1 >/dev/null)" && fail "sca init foo succeeded"
[[ "${stderr}" == *"'foo'"* ]] || fail "the invalid value error does not name foo: ${stderr}"
[[ "${stderr}" == *yubikey* ]] && fail "the invalid value error lists yubikey: ${stderr}"

# tab completion offers the remaining systems only
# shellcheck disable=SC2034 # COMP_* and current_word are read by the completion
completions="$(
  # shellcheck source=/dev/null
  . <(sca completion bash) 2>/dev/null
  COMP_WORDS=(sca init "")
  COMP_CWORD=2
  current_word=""
  suggestions=()
  _sca_init_complete 1
  echo "${suggestions[*]}"
)"
assert_eq "openssl_ca_db sca_usb_stick demo" "${completions}" "sca init <TAB>"

test_done
