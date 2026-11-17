#!/bin/bash
# security_key openpgp_git: setup sets the signing settings once and never
# overwrites or half-applies them, --local, --no-tags and --dry-run do what
# they say, public_key exports the card's signature key, every failure exits
# non-zero with a next step, and neither mode needs the sca configuration.
#
# gpg is stubbed as an exported shell function, as in
# test_security_key_openpgp_ssh.sh. the stub reads what it reports from files
# in $HOME/device, so each case can change one thing. git is the real one,
# with its global config in $HOME/gitconfig and no system config.
# shellcheck source=tests/lib.sh
. "$(dirname "$0")/lib.sh"

export GIT_CONFIG_GLOBAL="$HOME/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

# every call is logged in $HOME/calls, one call per line
# --card-status prints $HOME/device/card_status, or fails if there is none.
# --list-keys prints a key unless $HOME/device/no_public_key exists.
# --export prints an armored key, or nothing (and still exits 0, as gpg does)
# if $HOME/device/no_public_key exists.
# shellcheck disable=SC2317 # the stub is called by sca
gpg() {
  echo "gpg $*" >> "$HOME/calls"
  case "$*" in
    *--card-status* )
      [ -f "$HOME/device/card_status" ] || { echo "gpg: selecting card failed: No such device" >&2; return 2; }
      cat "$HOME/device/card_status"
      ;;
    *--list-keys* )
      if [ -f "$HOME/device/no_public_key" ]; then
        echo "gpg: error reading key: No public key" >&2
        return 2
      fi
      cat <<EOF
pub:u:255:22:AAAAAAAAAAAAAAAA:1700000000:::u:::cC:::::ed25519:::0:
fpr:::::::::$master:
uid:u::::1700000000::HASH::Test User <Test@Example.org>::::::::::0:
sub:u:255:22:1111111111111111:1700000000::::::s:::+::ed25519::
fpr:::::::::$sig:
EOF
      ;;
    *--export* )
      [ -f "$HOME/device/no_public_key" ] && return 0
      printf '%s\n' '-----BEGIN PGP PUBLIC KEY BLOCK-----' '' 'mDMEtest' '-----END PGP PUBLIC KEY BLOCK-----'
      ;;
    * ) return 1 ;;
  esac
}
export -f gpg

# the stub runs in sca's shell, so it needs these exported
export master=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
export sig=1111111111111111111111111111111111111111
enc=2222222222222222222222222222222222222222
aut=3333333333333333333333333333333333333333

# a card with signature, encryption and authentication keys, no git config,
# and the current folder outside any repository
reset_state() {
  cd "$HOME" || exit 2
  rm -rf "$HOME/device" "$HOME/calls" "$HOME/gitconfig" "$HOME/out" "$HOME/repo"
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

gitconfig="$HOME/gitconfig"
config_file="$HOME/.sca/config/sca.config"
# HOME is a temporary folder, so this is outside any repository unless a
# case runs git init
GIT_CEILING_DIRECTORIES="$(dirname "$HOME")"
export GIT_CEILING_DIRECTORIES

checksum() {
  md5sum "$1" | cut -d' ' -f1
}

# everything below runs with no sca configuration
[ ! -e "$config_file" ] || fail "the test starts with a sca config"

# --- -h works without config
output="$(sca security_key openpgp_git -h 2>&1)" || fail "openpgp_git -h fails without config: $output"
[[ "$output" == *"openpgp_git setup"* ]] || fail "openpgp_git -h prints no syntax: $output"
output="$(sca security_key openpgp_git setup -h 2>&1)" || fail "setup -h fails: $output"
output="$(sca security_key openpgp_git public_key -h 2>&1)" || fail "public_key -h fails: $output"

# --- fresh setup sets the three keys, a second run changes nothing
reset_state
output="$(sca security_key openpgp_git setup 2>&1)"
assert_eq 0 "$?" "first setup exit code"
assert_eq "$sig!" "$(git config --global user.signingkey)" "user.signingkey"
assert_eq true "$(git config --global commit.gpgsign)" "commit.gpgsign"
assert_eq true "$(git config --global tag.gpgSign)" "tag.gpgSign"
[ -z "$(git config --global gpg.program)" ] || fail "setup sets gpg.program"
[ -z "$(git config --global gpg.format)" ] || fail "setup sets gpg.format"
[[ "$output" == *"set: git config --global user.signingkey $sig!"* ]] || fail "setup does not say what it set: $output"
# shellcheck disable=SC2016 # the line is literal
[[ "$output" == *'export GPG_TTY="$(tty)"'* ]] || fail "setup does not print the GPG_TTY line unexpanded: $output"
[[ "$output" == *"sca security_key openpgp_git public_key"* ]] || fail "setup does not point to public_key: $output"
[[ "$output" == *"git log --show-signature -1"* ]] || fail "setup does not print a test command: $output"
grep -q -- "--list-keys --with-colons $sig" "$HOME/calls" || fail "setup does not check the public key: $(cat "$HOME/calls")"
[ ! -e "$config_file" ] || fail "setup creates a sca config"
[ ! -e "$HOME/.bashrc" ] || fail "setup writes a shell file"
before="$(checksum "$gitconfig")"
output="$(sca security_key openpgp_git setup 2>&1)"
assert_eq 0 "$?" "second setup exit code"
assert_eq "$before" "$(checksum "$gitconfig")" "git config after the second setup"
[[ "$output" == *"already set: git config --global user.signingkey $sig!"* ]] || fail "second setup does not say already set: $output"
[[ "$output" == *"already set: git config --global tag.gpgSign true"* ]] || fail "second setup, tag.gpgSign: $output"
printf '%s\n' "$output" | grep -q '^set: ' && fail "second setup sets something: $output"

# --- the key in another case, and yes for true, count as already set
reset_state
git config --global user.signingkey "${sig,,}!"
git config --global commit.gpgsign yes
git config --global gpg.format openpgp
before="$(checksum "$gitconfig")"
output="$(sca security_key openpgp_git setup --no-tags 2>&1)"
assert_eq 0 "$?" "setup with equivalent values exit code"
assert_eq "$before" "$(checksum "$gitconfig")" "equivalent values are not rewritten"
[[ "$output" == *"already set: git config --global commit.gpgsign true"* ]] || fail "commit.gpgsign yes is not already set: $output"

# --- --no-tags leaves tag.gpgSign alone
reset_state
sca security_key openpgp_git setup --no-tags >/dev/null 2>&1 || fail "setup --no-tags"
assert_eq true "$(git config --global commit.gpgsign)" "commit.gpgsign with --no-tags"
[ -z "$(git config --global tag.gpgSign)" ] || fail "setup --no-tags sets tag.gpgSign"

# --- a conflicting user.signingkey is reported, and nothing is written
reset_state
git config --global user.signingkey 0123456789ABCDEF
before="$(checksum "$gitconfig")"
output="$(sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 with a conflicting user.signingkey"
assert_eq "$before" "$(checksum "$gitconfig")" "git config after a conflict"
[ -z "$(git config --global commit.gpgsign)" ] || fail "a conflict still writes commit.gpgsign"
[[ "$output" == *"current: 0123456789ABCDEF"* ]] || fail "conflict does not show the current value: $output"
[[ "$output" == *"wanted:  $sig!"* ]] || fail "conflict does not show the wanted value: $output"
[[ "$output" == *"git config --global user.signingkey $sig!"* ]] || fail "conflict does not show the command: $output"
# the fingerprint without ! is a conflict too
git config --global user.signingkey "$sig"
assert_fails sca security_key openpgp_git setup

# --- every conflict is listed: false, gpg.format ssh, a bad boolean
reset_state
git config --global commit.gpgsign false
git config --global gpg.format ssh
git config --global tag.gpgSign maybe
before="$(checksum "$gitconfig")"
output="$(sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 with gpg.format ssh"
assert_eq "$before" "$(checksum "$gitconfig")" "git config after several conflicts"
[ -z "$(git config --global user.signingkey)" ] || fail "a conflict still writes user.signingkey"
[[ "$output" == *"git config --global commit.gpgsign true"* ]] || fail "commit.gpgsign false is no conflict: $output"
[[ "$output" == *"current: ssh"*"git config --global gpg.format openpgp"* ]] || fail "gpg.format ssh is no conflict: $output"
[[ "$output" == *"current: maybe"* ]] || fail "a bad boolean is no conflict: $output"
[[ "$output" == *"3 conflicting"* ]] || fail "conflicts are not counted: $output"

# --- --dry-run creates and changes nothing, and still checks conflicts
reset_state
output="$(sca security_key openpgp_git setup --dry-run 2>&1)"
assert_eq 0 "$?" "setup --dry-run exit code"
[ ! -e "$gitconfig" ] || fail "setup --dry-run creates the git config"
[[ "$output" == *"would set: git config --global user.signingkey $sig!"* ]] || fail "setup --dry-run does not say what it would do: $output"
[[ "$output" == *"would set: git config --global tag.gpgSign true"* ]] || fail "setup --dry-run, tag.gpgSign: $output"
git config --global commit.gpgsign false
before="$(checksum "$gitconfig")"
assert_fails sca security_key openpgp_git setup -n
assert_eq "$before" "$(checksum "$gitconfig")" "git config after setup -n with a conflict"

# --- --local writes the repository's config, and reads only it
reset_state
git init -q "$HOME/repo"
git config --global user.signingkey 0123456789ABCDEF
before="$(checksum "$gitconfig")"
cd "$HOME/repo" || exit 2
output="$(sca security_key openpgp_git setup --local 2>&1)"
assert_eq 0 "$?" "setup --local exit code: $output"
assert_eq "$sig!" "$(git config --local user.signingkey)" "local user.signingkey"
assert_eq true "$(git config --local commit.gpgsign)" "local commit.gpgsign"
assert_eq true "$(git config --local tag.gpgSign)" "local tag.gpgSign"
assert_eq "$before" "$(checksum "$gitconfig")" "the global config after setup --local"
[[ "$output" == *"set: git config --local user.signingkey"* ]] || fail "setup --local output: $output"
cd "$HOME" || exit 2
# outside a repository
output="$(sca security_key openpgp_git setup --local 2>&1)" && fail "setup --local exits 0 outside a repository"
[[ "$output" == *"--local must be run inside a git repository"* ]] || fail "setup --local outside a repository: $output"

# --- user.email: no warning when it is a user ID, a warning when it isn't
reset_state
git config --global user.email test@example.org
output="$(sca security_key openpgp_git setup 2>&1)" || fail "setup with user.email"
[[ "$output" == *"Unverified"* ]] && fail "setup warns about a user.email the key has: $output"
reset_state
git config --global user.email someone@else.org
output="$(sca security_key openpgp_git setup 2>&1)"
assert_eq 0 "$?" "setup with another user.email exit code"
[[ "$output" == *"warning: user.email 'someone@else.org'"*"Unverified"* ]] || fail "setup does not warn about user.email: $output"
# a missing gpg.program is only a warning
reset_state
git config --global gpg.program no-such-gpg
output="$(sca security_key openpgp_git setup 2>&1)"
assert_eq 0 "$?" "setup with a missing gpg.program exit code"
[[ "$output" == *"warning: git is set to sign with gpg.program 'no-such-gpg'"* ]] || fail "setup does not warn about gpg.program: $output"
assert_eq no-such-gpg "$(git config --global gpg.program)" "gpg.program is left alone"

# --- no public key in the keyring
reset_state
touch "$HOME/device/no_public_key"
output="$(sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 with no public key"
[[ "$output" == *"gpg --import"*"fetch"* ]] || fail "no public key message has no next step: $output"
[ ! -e "$gitconfig" ] || fail "setup with no public key writes the git config"

# --- a card with no signature key
reset_state
sed -i "s/^fpr:.*/fpr::$enc:$aut:/" "$HOME/device/card_status"
output="$(sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 with no signature key"
[[ "$output" == *"the card has no signature key"*"docs/gpg-yubikey.md"* ]] || fail "no signature key message: $output"
[ ! -e "$gitconfig" ] || fail "setup with no signature key writes the git config"
output="$(sca security_key openpgp_git public_key 2>&1)" && fail "public_key exits 0 with no signature key"
[[ "$output" == *"the card has no signature key"* ]] || fail "public_key, no signature key message: $output"
grep -q -- "--export" "$HOME/calls" && fail "public_key exports with no signature key"

# --- no card
reset_state
rm "$HOME/device/card_status"
output="$(sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 with no card"
[[ "$output" == *"no OpenPGP card found"*"sca install --openpgp"* ]] || fail "setup, no card message: $output"
[ ! -e "$gitconfig" ] || fail "setup with no card writes the git config"
output="$(sca security_key openpgp_git public_key 2>&1)" && fail "public_key exits 0 with no card"
[[ "$output" == *"no OpenPGP card found"* ]] || fail "public_key, no card message: $output"

# --- public_key exports the signature key without !, the key alone on stdout
reset_state
stdout="$(sca security_key openpgp_git public_key 2>/dev/null)"
assert_eq 0 "$?" "public_key exit code"
assert_eq "$(printf '%s\n' '-----BEGIN PGP PUBLIC KEY BLOCK-----' '' 'mDMEtest' '-----END PGP PUBLIC KEY BLOCK-----')" \
  "$stdout" "public_key stdout"
grep -qxF -- "gpg --batch --armor --export $sig" "$HOME/calls" \
  || fail "public_key does not export the signature fingerprint: $(cat "$HOME/calls")"
[ ! -e "$config_file" ] || fail "public_key creates a sca config"

# --- public_key -o writes the file, and never overwrites one
reset_state
output_file="$HOME/out/signing key.asc"
sca security_key openpgp_git public_key -o "$output_file" >/dev/null 2>&1 || fail "public_key -o"
assert_eq "-----BEGIN PGP PUBLIC KEY BLOCK-----" "$(head -n 1 "$output_file" 2>/dev/null)" "public_key -o file"
assert_eq 644 "$(stat -c %a "$output_file")" "mode of the -o file"
echo "keep me" > "$output_file"
output="$(sca security_key openpgp_git public_key --output "$output_file" 2>&1)" \
  && fail "public_key -o onto an existing file exits 0"
[[ "$output" == *"already exists"* ]] || fail "public_key -o onto an existing file: $output"
assert_eq "keep me" "$(cat "$output_file")" "existing -o file is untouched"

# --- an empty export fails, and leaves no -o file
reset_state
touch "$HOME/device/no_public_key"
output="$(sca security_key openpgp_git public_key 2>&1)" && fail "public_key exits 0 when the export is empty"
[[ "$output" == *"gpg --import"* ]] || fail "empty export does not say to import the key: $output"
output="$(sca security_key openpgp_git public_key -o "$HOME/out/key.asc" 2>&1)" \
  && fail "public_key -o exits 0 when the export is empty"
assert_eq "" "$(ls -A "$HOME/out")" "an empty export leaves a file"

# --- every gpg call ran with --batch
reset_state
git config --global user.email test@example.org
sca security_key openpgp_git setup >/dev/null 2>&1
sca security_key openpgp_git public_key >/dev/null 2>&1
grep -c '^gpg ' "$HOME/calls" | grep -qx 0 && fail "no gpg calls were logged"
grep -- '^gpg ' "$HOME/calls" | grep -qv -- '--batch' && fail "gpg runs without --batch: $(cat "$HOME/calls")"

# --- bad options and arguments are refused
assert_fails sca security_key openpgp_git
assert_fails sca security_key openpgp_git frobnicate
assert_fails sca security_key openpgp_git setup --no-such-option
assert_fails sca security_key openpgp_git setup extra
assert_fails sca security_key openpgp_git public_key extra

# --- missing gpg names sca install --openpgp, missing git names the package
reset_state
nogpg_path="$HOME/bin-nogpg"
mkdir -p "$nogpg_path"
for tool in bash cat dirname getopt grep mkdir mktemp mv rm sed awk tail chmod; do
  ln -s "$(command -v "$tool")" "$nogpg_path/$tool"
done
export -n -f gpg
output="$(PATH="$nogpg_path" sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "setup, missing gpg message: $output"
output="$(PATH="$nogpg_path" sca security_key openpgp_git public_key 2>&1)" && fail "public_key exits 0 without gpg"
[[ "$output" == *"gpg not found"*"sca install --openpgp"* ]] || fail "public_key, missing gpg message: $output"
export -f gpg
output="$(PATH="$nogpg_path" sca security_key openpgp_git setup 2>&1)" && fail "setup exits 0 without git"
[[ "$output" == *"git not found"*"apt install git"* ]] || fail "setup, missing git message: $output"
[ ! -e "$gitconfig" ] || fail "setup without git changes something"

test_done
