################################################################################
# set up git to sign commits and tags with the OpenPGP signature key of a
# yubikey, and print that key's armored public key for the git host
#
# neither mode reads the sca configuration, and neither asks for, reads or logs
# the OpenPGP PIN: gpg runs with --batch, so it never opens pinentry.
security_key_openpgp_git() {
  local mode="$1"
  case "$mode" in
    -h | --help )
      security_key_openpgp_git_help
      return
      ;;
    setup|public_key )
      shift
      log_detailed "security_key_openpgp_git: start (mode=${mode})"
      security_key_openpgp_git_$mode "$@"
      ;;
    * )
      error "security_key_openpgp_git: invalid value '$mode' for the mode. supported "\
"values are 'setup' and 'public_key'. use sca security_key openpgp_git -h for help." 1
      ;;
  esac
}
################################################################################
# sca security_key openpgp_git setup
security_key_openpgp_git_setup() {
  local scope='--global'
  local tags=true
  local dry_run=false
  local OPTS
  OPTS=`getopt -o hn --long help,local,no-tags,dry-run -n "sca security_key openpgp_git setup" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_git -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_git_help
        return
      ;;
      --local )
        scope='--local'
        shift
      ;;
      --no-tags )
        tags=false
        shift
      ;;
      -n | --dry-run )
        dry_run=true
        shift
      ;;
      -- )
        shift
        break
      ;;
      * )
        break
      ;;
    esac
  done
  [ $# -gt 0 ] && error "security_key_openpgp_git setup: unexpected argument '$1'. "\
"use sca security_key openpgp_git -h for help." 1
  security_key_openpgp_git_need_tools gpg git
  log_detailed "security_key_openpgp_git_setup: started (scope=$scope, tags=$tags, dry_run=$dry_run)"
  if [ "$scope" = --local ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    error "security_key_openpgp_git setup: --local must be run inside a git "\
"repository. cd into one, or leave out --local to set up every repository." 1
  fi
  security_key_openpgp_git_read_card setup
  local fingerprint="$security_key_openpgp_git_fingerprint"
  local key_list
  key_list=$(gpg --batch --list-keys --with-colons "$fingerprint" 2>/dev/null)
  if [ $? != 0 ] || [ -z "$key_list" ]; then
    security_key_openpgp_git_no_public_key setup "$fingerprint"
  fi

  # read every target first: nothing is written unless none of them conflicts,
  # since a half-applied config (commit.gpgsign with another signingkey) would
  # make every commit fail
  local keys=(user.signingkey commit.gpgsign)
  local wanted=("${fingerprint}!" true)
  if [ $tags = true ]; then
    keys+=(tag.gpgSign)
    wanted+=(true)
  fi
  local i key want current rc
  local to_set=() already=() conflicts=()
  for i in "${!keys[@]}"; do
    key=${keys[$i]}
    want=${wanted[$i]}
    if [ "$want" = true ]; then
      # --type=bool: yes, on and 1 count as true
      current=$(git config "$scope" --type=bool --get "$key" 2>/dev/null)
    else
      current=$(git config "$scope" --get "$key" 2>/dev/null)
    fi
    rc=$?
    log_detailed "security_key_openpgp_git_setup: $key='$current' (rc=$rc, wanted '$want')"
    if [ $rc = 1 ]; then
      to_set+=("$i")
    elif [ $rc = 0 ] && [ "${current,,}" = "${want,,}" ]; then
      already+=("$i")
    else
      # not a boolean git understands, or a different value: show it as written
      current=$(git config "$scope" --get "$key" 2>/dev/null) || \
        error "security_key_openpgp_git setup: could not read $key with "\
"'git config $scope'. check that git config file." 1
      conflicts+=("$key"$'\x1f'"$current"$'\x1f'"$want")
    fi
  done
  # gpg.format ssh or x509 would sign with something else than this key
  current=$(git config "$scope" --get gpg.format 2>/dev/null)
  rc=$?
  log_detailed "security_key_openpgp_git_setup: gpg.format='$current' (rc=$rc)"
  if [ $rc != 1 ] && [ "${current,,}" != openpgp ]; then
    conflicts+=("gpg.format"$'\x1f'"$current"$'\x1f'openpgp)
  fi

  if [ ${#conflicts[@]} -gt 0 ]; then
    local entry
    {
      echo "these git settings ($scope) already have another value. nothing was changed:"
      for entry in "${conflicts[@]}"; do
        IFS=$'\x1f' read -r key current want <<< "$entry"
        echo
        echo "  $key"
        echo "    current: $current"
        echo "    wanted:  $want"
        echo "    to accept it, run: git config $scope $key $want"
      done
      echo
    } >&2
    error "security_key_openpgp_git setup: ${#conflicts[@]} conflicting git "\
"setting(s). change them as shown above, or keep them and set up signing by "\
"hand (docs/gpg-yubikey.md section 5.4), then rerun." 1
  fi

  local prefix=''
  [ $dry_run = true ] && prefix='would '
  for i in "${already[@]}"; do
    echo "already set: git config $scope ${keys[$i]} ${wanted[$i]}"
  done
  for i in "${to_set[@]}"; do
    echo "${prefix}set: git config $scope ${keys[$i]} ${wanted[$i]}"
    if [ $dry_run = false ]; then
      git config "$scope" "${keys[$i]}" "${wanted[$i]}" || \
        error "security_key_openpgp_git setup: 'git config $scope ${keys[$i]} "\
"${wanted[$i]}' failed." 1
    fi
  done

  # warnings only: git reads the effective values, whichever scope set them
  local program
  program=$(git config --get gpg.program 2>/dev/null)
  if [ -n "$program" ] && ! command -v "$program" >/dev/null 2>&1; then
    >&2 echo "warning: git is set to sign with gpg.program '$program', which is "\
"not found. signing will fail until it is installed or the setting removed."
  fi
  local email
  email=$(git config --get user.email 2>/dev/null)
  log_detailed "security_key_openpgp_git_setup: user.email='$email'"
  if [ -n "$email" ] && ! printf '%s\n' "$key_list" | \
      awk -F: -v email="<${email,,}>" '$1 == "uid" && index(tolower($10), email) { found = 1 } END { exit !found }'; then
    >&2 echo "warning: user.email '$email' is not a user ID of key $fingerprint, "\
"so the git host will show your commits as Unverified. add it to the key "\
"(gpg --edit-key, adduid) or change user.email."
  fi

  cat <<'GIT_HINT'

add this line to your shell's startup file (e.g. ~/.bashrc), so the PIN prompt
shows up in the terminal you run git in (sca does not edit it):

  export GPG_TTY="$(tty)"

get the public key for your git host's GPG keys page (GitHub: Settings, SSH
and GPG keys; GitLab: Preferences, GPG Keys) with
'sca security_key openpgp_git public_key', then test signing in a repository:

  git commit --allow-empty -m test && git log --show-signature -1
GIT_HINT
  log_detailed "security_key_openpgp_git_setup: finished (dry_run=$dry_run)"
}
################################################################################
# sca security_key openpgp_git public_key
security_key_openpgp_git_public_key() {
  local output=''
  local OPTS
  OPTS=`getopt -o ho: --long help,output: -n "sca security_key openpgp_git public_key" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_git -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_git_help
        return
      ;;
      -o | --output )
        output=$2
        shift;shift
      ;;
      -- )
        shift
        break
      ;;
      * )
        break
      ;;
    esac
  done
  [ $# -gt 0 ] && error "security_key_openpgp_git public_key: unexpected argument '$1'. "\
"use sca security_key openpgp_git -h for help." 1
  security_key_openpgp_git_need_tools gpg
  log_detailed "security_key_openpgp_git_public_key: started (output='$output')"
  [ -n "$output" ] && [ -e "$output" ] && \
    error "security_key_openpgp_git public_key: '$output' already exists and is "\
"never overwritten. choose another file with -o FILE." 1
  security_key_openpgp_git_read_card public_key
  local fingerprint="$security_key_openpgp_git_fingerprint"
  # no !: the host gets the primary key with all its subkeys. gpg --export
  # exits 0 when it finds nothing, so empty output is a failure too.
  if [ -z "$output" ]; then
    local key
    key=$(gpg --batch --armor --export "$fingerprint")
    if [ $? != 0 ] || [ -z "$key" ]; then
      security_key_openpgp_git_no_public_key public_key "$fingerprint"
    fi
    printf '%s\n' "$key"
  else
    local tmp
    tmp=$(mktemp "$(dirname "$output")/.sca-openpgp-git.XXXXXX") || \
      error "security_key_openpgp_git public_key: could not create a temporary "\
"file next to '$output'." 1
    trap 'rm -f "$tmp"' EXIT
    if ! gpg --batch --armor --export "$fingerprint" > "$tmp" || [ ! -s "$tmp" ]; then
      security_key_openpgp_git_no_public_key public_key "$fingerprint"
    fi
    chmod 644 "$tmp"
    # -n: a file that appeared meanwhile is still not overwritten
    if ! mv -n "$tmp" "$output" || [ -e "$tmp" ]; then
      error "security_key_openpgp_git public_key: could not write '$output'." 1
    fi
    trap - EXIT
    >&2 echo "the GPG public key was written to '$output'. add it to your git host's GPG keys page."
  fi
  log_detailed "security_key_openpgp_git_public_key: finished (output='$output')"
}
################################################################################
# reads the card's signature key fingerprint into
# security_key_openpgp_git_fingerprint, or exits with what to do
#
# parameters
#   mode - setup or public_key, for the error messages
security_key_openpgp_git_read_card() {
  local mode="$1"
  local card_status
  card_status=$(gpg --batch --card-status --with-colons 2>/dev/null) || \
    error "security_key_openpgp_git $mode: no OpenPGP card found. plug in "\
"the YubiKey, check that pcscd or scdaemon can reach it ('gpg --card-status'), "\
"and that the OpenPGP packages are installed (sca install --openpgp)." 1
  # fpr:<signature>:<encryption>:<authentication>:
  security_key_openpgp_git_fingerprint=$(printf '%s\n' "$card_status" | awk -F: '$1 == "fpr" { print $2; exit }')
  log_detailed "security_key_openpgp_git_read_card: signature key='$security_key_openpgp_git_fingerprint'"
  [[ "$security_key_openpgp_git_fingerprint" =~ ^[0-9A-Fa-f]+$ ]] || \
    error "security_key_openpgp_git $mode: the card has no signature key. put "\
"one on it with 'sca security_key openpgp_key create' and then "\
"'sca security_key openpgp_key to_card', or see docs/gpg-yubikey.md section 3 (Keys)." 1
}
################################################################################
# exits with what to do when the signature key's public key is not in the
# keyring
#
# parameters
#   mode        - setup or public_key, for the error message
#   fingerprint - the card's signature key
security_key_openpgp_git_no_public_key() {
  error "security_key_openpgp_git $1: the public key of the signature key "\
"$2 is not in this machine's keyring: import it with 'gpg --import <file>', "\
"or run 'gpg --card-edit' and 'fetch' if the card has a URL set, then retry." 1
}
################################################################################
# exits, naming the first missing one, unless all the given tools are found
#
# parameters
#   tool... - gpg, git
security_key_openpgp_git_need_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 && continue
    if [ "$tool" = git ]; then
      error "security_key_openpgp_git: git not found. install git (e.g. "\
"sudo apt install git)." 1
    fi
    error "security_key_openpgp_git: $tool not found. install the OpenPGP "\
"packages with sca install --openpgp." 1
  done
}
security_key_openpgp_git_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
