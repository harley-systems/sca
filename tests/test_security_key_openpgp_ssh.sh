#!/bin/bash
# security_key openpgp_ssh: setup enables ssh support in gpg-agent once and
# restarts the agent only then, --shell-rc and --dry-run do what they say,
# public_key exports the card's authentication key, every failure exits
# non-zero with a next step, and neither mode needs the sca configuration.
#
# gpg and gpgconf are stubbed as exported shell functions, as in
# test_security_key_unblock_pin.sh. the stubs read what they report from files
# in $HOME/device, so each case can change one thing.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

# every call is logged in $HOME/calls, one call per line
# shellcheck disable=SC2317 # the stubs are called by sca
gpgconf() {
  echo "gpgconf $*" >> "$HOME/calls"
  case "$*" in
    "--list-dirs homedir" ) echo "${GNUPGHOME:-$HOME/gnupg-test}" ;;
    "--kill gpg-agent" ) return 0 ;;
    * ) return 1 ;;
  esac
}
# --card-status prints $HOME/device/card_status, or fails if there is none.
# --export-ssh-key prints a key unless $HOME/device/export_fails exists.
# shellcheck disable=SC2317 # the stubs are called by sca
gpg() {
  echo "gpg $*" >> "$HOME/calls"
  case "$*" in
    *--card-status* )
      [ -f "$HOME/device/card_status" ] || { echo "gpg: selecting card failed: No such device" >&2; return 2; }
      cat "$HOME/device/card_status"
      ;;
    *--export-ssh-key* )
      if [ -f "$HOME/device/export_fails" ]; then
        echo "gpg: key \"$3\" not found: No public key" >&2
        return 2
      fi
      echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest openpgp:0x9A8B7C6D"
      ;;
    * ) return 1 ;;
  esac
}
export -f gpg gpgconf

sig=1111111111111111111111111111111111111111
enc=2222222222222222222222222222222222222222
aut=3333333333333333333333333333333333333333

# a card with signature, encryption and authentication keys, and an empty
# gnupg home
reset_state() {
  unset GNUPGHOME
  rm -rf "$HOME/device" "$HOME/calls" "$HOME/gnupg-test" "$HOME/out" "$HOME/rc" "$HOME/other-gnupg"
  mkdir -p "$HOME/device" "$HOME/out"
  : > "$HOME/calls"
  cat > "$HOME/device/card_status" <<EOF
Reader:Yubico YubiKey OTP FIDO CCID 00 00:AID:D2760001240103040006123456780000:openpgp-card
version:0304
vendor:0006:Yubico:
serial:12345678:
fpr:$sig:$enc:$aut:
fprtime:1700000000:1700000000:1700000000:
EOF
}

kill_count() {
  grep -c '^gpgconf --kill gpg-agent$' "$HOME/calls"
}

agent_conf="$HOME/gnupg-test/gpg-agent.conf"
config_file="$HOME/.sca/config/sca.config"

# everything below runs with no sca configuration
[ ! -e "$config_file" ] || fail "the test starts with a sca config"

# --- -h works without config
output="$(sca security_key openpgp_ssh -h 2>&1)" || fail "openpgp_ssh -h fails without config: $output"
[[ "$output" == *"openpgp_ssh setup"* ]] || fail "openpgp_ssh -h prints no syntax: $output"
output="$(sca security_key openpgp_ssh public_key -h 2>&1)" || fail "public_key -h fails: $output"

# --- other security_key commands still need the config
output="$(sca security_key info 2>&1)" && fail "security_key info exits 0 without a config"
[[ "$output" == *"$config_file doesn't"* ]] || fail "security_key info does not report the missing config: $output"

# --- setup, twice: one enable-ssh-support line, the agent restarted once
reset_state
output="$(sca security_key openpgp_ssh setup 2>&1)"
assert_eq 0 "$?" "first setup exit code"
assert_file_exists "$agent_conf" "setup creates gpg-agent.conf"
assert_eq 1 "$(grep -cx 'enable-ssh-support' "$agent_conf")" "enable-ssh-support lines after the first setup"
assert_eq 1 "$(kill_count)" "gpg-agent restarts on the first setup"
assert_eq 700 "$(stat -c %a "$HOME/gnupg-test")" "mode of the new gnupg home"
assert_eq 600 "$(stat -c %a "$agent_conf")" "mode of the new gpg-agent.conf"
# shellcheck disable=SC2016 # the lines are literal
[[ "$output" == *'export GPG_TTY="$(tty)"'* ]] || fail "setup does not print the GPG_TTY line unexpanded: $output"
# shellcheck disable=SC2016 # the lines are literal
[[ "$output" == *'export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"'* ]] \
  || fail "setup does not print the SSH_AUTH_SOCK line: $output"
[[ "$output" == *'gpgconf --launch gpg-agent'* ]] || fail "setup does not print the launch line: $output"
[[ "$output" == *'Match host * exec "gpg-connect-agent updatestartuptty /bye"'* ]] \
  || fail "setup does not print the ~/.ssh/config hint: $output"
[ ! -e "$HOME/.ssh/config" ] || fail "setup writes ~/.ssh/config"
[ ! -e "$config_file" ] || fail "setup creates a sca config"
output="$(sca security_key openpgp_ssh setup 2>&1)"
assert_eq 0 "$?" "second setup exit code"
assert_eq 1 "$(grep -cx 'enable-ssh-support' "$agent_conf")" "enable-ssh-support lines after the second setup"
assert_eq 1 "$(kill_count)" "gpg-agent is not restarted when nothing changed"
[[ "$output" == *"already enabled"* ]] || fail "second setup does not say it is already enabled: $output"

# --- an existing conf: kept, a missing final newline added, a commented-out
# option does not count
reset_state
mkdir -p "$HOME/gnupg-test"
printf 'default-cache-ttl 600\n# enable-ssh-support\npinentry-program /usr/bin/pinentry' > "$agent_conf"
sca security_key openpgp_ssh setup >/dev/null 2>&1 || fail "setup with an existing conf"
assert_eq "$(printf 'default-cache-ttl 600\n# enable-ssh-support\npinentry-program /usr/bin/pinentry\nenable-ssh-support')" \
  "$(cat "$agent_conf")" "existing gpg-agent.conf after setup"
assert_eq 1 "$(kill_count)" "gpg-agent restarts after adding to an existing conf"
# an indented option already counts
reset_state
mkdir -p "$HOME/gnupg-test"
printf '  enable-ssh-support  \n' > "$agent_conf"
sca security_key openpgp_ssh setup >/dev/null 2>&1 || fail "setup with the option indented"
assert_eq 1 "$(grep -c 'enable-ssh-support' "$agent_conf")" "indented option counts as present"
assert_eq 0 "$(kill_count)" "no restart when the option is already there"

# --- GNUPGHOME is honoured (through gpgconf --list-dirs homedir)
reset_state
export GNUPGHOME="$HOME/other-gnupg"
sca security_key openpgp_ssh setup >/dev/null 2>&1 || fail "setup with GNUPGHOME"
assert_eq 1 "$(grep -cx 'enable-ssh-support' "$GNUPGHOME/gpg-agent.conf" 2>/dev/null)" "GNUPGHOME gpg-agent.conf"
[ ! -e "$agent_conf" ] || fail "setup with GNUPGHOME writes the default home"
unset GNUPGHOME

# --- --shell-rc is idempotent, with one marker comment
reset_state
rc="$HOME/rc"
# shellcheck disable=SC2016 # the lines are literal
printf '# my rc\nexport GPG_TTY="$(tty)"' > "$rc"
output="$(sca security_key openpgp_ssh setup --shell-rc "$rc" 2>&1)"
assert_eq 0 "$?" "setup --shell-rc exit code"
[[ "$output" == *"already in '$rc': export GPG_TTY"* ]] || fail "setup --shell-rc does not report the line already there: $output"
# shellcheck disable=SC2016 # the lines are literal
expected='# my rc
export GPG_TTY="$(tty)"
# added by sca security_key openpgp_ssh setup
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
gpgconf --launch gpg-agent'
assert_eq "$expected" "$(cat "$rc")" "rc file after the first setup --shell-rc"
sca security_key openpgp_ssh setup --shell-rc "$rc" >/dev/null 2>&1 || fail "second setup --shell-rc"
assert_eq "$expected" "$(cat "$rc")" "rc file after the second setup --shell-rc"
# a missing rc file, with a space in its name, is created
rc="$HOME/out/my rc"
sca security_key openpgp_ssh setup --shell-rc "$rc" >/dev/null 2>&1 || fail "setup --shell-rc with a new file"
assert_eq 4 "$(wc -l < "$rc" | tr -d ' ')" "lines in a new rc file"

# --- --dry-run writes nothing and restarts nothing
reset_state
rc="$HOME/rc"
output="$(sca security_key openpgp_ssh setup --dry-run --shell-rc "$rc" 2>&1)"
assert_eq 0 "$?" "setup --dry-run exit code"
[ ! -e "$HOME/gnupg-test" ] || fail "setup --dry-run creates the gnupg home"
[ ! -e "$rc" ] || fail "setup --dry-run creates the rc file"
assert_eq 0 "$(kill_count)" "setup --dry-run restarts gpg-agent"
[[ "$output" == *"would append enable-ssh-support"* ]] || fail "setup --dry-run does not say what it would do: $output"
[[ "$output" == *"would run gpgconf --kill gpg-agent"* ]] || fail "setup --dry-run does not mention the restart: $output"
[[ "$output" == *"would append to '$rc'"* ]] || fail "setup --dry-run does not mention the rc file: $output"
sca security_key openpgp_ssh setup -n >/dev/null 2>&1 || fail "setup -n"
[ ! -e "$HOME/gnupg-test" ] || fail "setup -n creates the gnupg home"

# --- public_key exports the authentication key, the key alone on stdout
reset_state
stdout="$(sca security_key openpgp_ssh public_key 2>/dev/null)"
assert_eq 0 "$?" "public_key exit code"
assert_eq "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest openpgp:0x9A8B7C6D" "$stdout" "public_key stdout"
grep -qxF -- "gpg --batch --export-ssh-key $aut!" "$HOME/calls" \
  || fail "public_key does not export the auth fingerprint: $(cat "$HOME/calls")"
grep -q -- "--card-status" "$HOME/calls" || fail "public_key does not read the card"
grep -- '^gpg ' "$HOME/calls" | grep -qv -- '--batch' && fail "gpg runs without --batch: $(cat "$HOME/calls")"
[ ! -e "$config_file" ] || fail "public_key creates a sca config"

# --- public_key -o writes the file, and never overwrites one
reset_state
output_file="$HOME/out/id gpg.pub"
sca security_key openpgp_ssh public_key -o "$output_file" >/dev/null 2>&1 || fail "public_key -o"
assert_eq "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest openpgp:0x9A8B7C6D" "$(cat "$output_file" 2>/dev/null)" "public_key -o file"
echo "keep me" > "$output_file"
output="$(sca security_key openpgp_ssh public_key --output "$output_file" 2>&1)" \
  && fail "public_key -o onto an existing file exits 0"
[[ "$output" == *"already exists"* ]] || fail "public_key -o onto an existing file: $output"
assert_eq "keep me" "$(cat "$output_file")" "existing -o file is untouched"

# --- a failed export leaves no -o file and names the fix
reset_state
touch "$HOME/device/export_fails"
output="$(sca security_key openpgp_ssh public_key -o "$HOME/out/key.pub" 2>&1)" \
  && fail "public_key exits 0 when the export fails"
[ ! -e "$HOME/out/key.pub" ] || fail "a failed export leaves the -o file"
assert_eq "" "$(ls -A "$HOME/out")" "a failed export leaves a temporary file"
[[ "$output" == *"gpg --import"* ]] || fail "failed export does not say to import the key: $output"

# --- a card with no authentication key
reset_state
sed -i "s/^fpr:.*/fpr:$sig:$enc::/" "$HOME/device/card_status"
output="$(sca security_key openpgp_ssh public_key 2>&1)" && fail "public_key exits 0 with no auth key"
[[ "$output" == *"the card has no authentication key"* ]] || fail "no auth key message: $output"
[[ "$output" == *"docs/gpg-yubikey.md"* ]] || fail "no auth key message has no next step: $output"
grep -q -- "--export-ssh-key" "$HOME/calls" && fail "public_key exports with no auth key"

# --- no card
reset_state
rm "$HOME/device/card_status"
output="$(sca security_key openpgp_ssh public_key 2>&1)" && fail "public_key exits 0 with no card"
[[ "$output" == *"no OpenPGP card found"* ]] || fail "no card message: $output"
[[ "$output" == *"sca install --openpgp"* ]] || fail "no card message does not name sca install --openpgp: $output"

# --- bad options and arguments are refused
assert_fails sca security_key openpgp_ssh
assert_fails sca security_key openpgp_ssh frobnicate
assert_fails sca security_key openpgp_ssh setup --no-such-option
assert_fails sca security_key openpgp_ssh setup extra
assert_fails sca security_key openpgp_ssh public_key extra

# --- missing gpg / gpgconf name sca install --openpgp
reset_state
nogpg_path="$HOME/bin-nogpg"
mkdir -p "$nogpg_path"
for tool in bash cat dirname getopt grep mkdir mktemp mv rm sed awk tail chmod; do
  ln -s "$(command -v "$tool")" "$nogpg_path/$tool"
done
export -n -f gpg gpgconf
output="$(PATH="$nogpg_path" sca security_key openpgp_ssh setup 2>&1)" && fail "setup exits 0 without gpgconf"
[[ "$output" == *"gpgconf not found"*"sca install --openpgp"* ]] || fail "missing gpgconf message: $output"
[ ! -e "$HOME/gnupg-test" ] || fail "setup without gpgconf changes something"
output="$(PATH="$nogpg_path" sca security_key openpgp_ssh public_key 2>&1)" && fail "public_key exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "missing gpg message: $output"

test_done
