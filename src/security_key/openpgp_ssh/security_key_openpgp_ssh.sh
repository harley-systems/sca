################################################################################
# set up gpg-agent to serve the OpenPGP authentication key of a yubikey as an
# SSH key, and print that key's SSH public key
#
# neither mode reads the sca configuration, and neither asks for, reads or logs
# the OpenPGP PIN: gpg runs with --batch, so it never opens pinentry.
security_key_openpgp_ssh() {
  local mode="$1"
  case "$mode" in
    -h | --help )
      security_key_openpgp_ssh_help
      return
      ;;
    setup|public_key )
      shift
      log_detailed "security_key_openpgp_ssh: start (mode=${mode})"
      security_key_openpgp_ssh_$mode "$@"
      ;;
    * )
      error "security_key_openpgp_ssh: invalid value '$mode' for the mode. supported "\
"values are 'setup' and 'public_key'. use sca security_key openpgp_ssh -h for help." 1
      ;;
  esac
}
################################################################################
# sca security_key openpgp_ssh setup
security_key_openpgp_ssh_setup() {
  local shell_rc=''
  local dry_run=false
  local OPTS
  OPTS=`getopt -o hn --long help,shell-rc:,dry-run -n "sca security_key openpgp_ssh setup" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_ssh_help
        return
      ;;
      --shell-rc )
        shell_rc=$2
        shift;shift
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
  [ $# -gt 0 ] && error "security_key_openpgp_ssh setup: unexpected argument '$1'. "\
"use sca security_key openpgp_ssh -h for help." 1
  security_key_openpgp_ssh_need_tools gpgconf
  log_detailed "security_key_openpgp_ssh_setup: started (shell_rc='$shell_rc', dry_run=$dry_run)"
  local homedir
  homedir=$(gpgconf --list-dirs homedir)
  if [ $? != 0 ] || [ -z "$homedir" ]; then
    error "security_key_openpgp_ssh setup: 'gpgconf --list-dirs homedir' failed. "\
"check the GnuPG installation, or run sca install --openpgp." 1
  fi
  local agent_conf="$homedir/gpg-agent.conf"
  log_detailed "security_key_openpgp_ssh_setup: agent_conf='$agent_conf'"
  local prefix=''
  [ $dry_run = true ] && prefix='would '

  # gpg-agent.conf. the agent is restarted only when the file changed: killing
  # it drops the PINs it has cached.
  if [ -f "$agent_conf" ] && \
      grep -q '^[[:space:]]*enable-ssh-support[[:space:]]*$' "$agent_conf"; then
    echo "enable-ssh-support is already enabled in '$agent_conf'; gpg-agent is not restarted."
  else
    echo "${prefix}append enable-ssh-support to '$agent_conf'"
    echo "${prefix}run gpgconf --kill gpg-agent"
    if [ $dry_run = false ]; then
      if [ ! -d "$homedir" ]; then
        (umask 077; mkdir -p "$homedir") || \
          error "security_key_openpgp_ssh setup: could not create '$homedir'." 1
      fi
      security_key_openpgp_ssh_append_lines "$agent_conf" '' enable-ssh-support || \
        error "security_key_openpgp_ssh setup: could not write '$agent_conf'." 1
      gpgconf --kill gpg-agent || \
        error "security_key_openpgp_ssh setup: enable-ssh-support was added, but "\
"'gpgconf --kill gpg-agent' failed. restart gpg-agent before using it for SSH." 1
    fi
  fi

  # the shell lines are printed as they go into the rc file, unexpanded
  local shell_lines
  shell_lines=$(cat <<'SHELL_LINES'
export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
gpgconf --launch gpg-agent
SHELL_LINES
)
  local marker='# added by sca security_key openpgp_ssh setup'
  echo
  if [ -z "$shell_rc" ]; then
    echo "add these lines to your shell's startup file (sh, bash or zsh, e.g."
    echo "~/.bashrc), in place of starting ssh-agent, or rerun with --shell-rc FILE:"
    echo
    printf '%s\n' "$shell_lines" | sed 's/^/  /'
  else
    local line missing=() present=()
    while IFS= read -r line; do
      if [ -f "$shell_rc" ] && grep -qxF -- "$line" "$shell_rc"; then
        present+=("$line")
      else
        missing+=("$line")
      fi
    done <<< "$shell_lines"
    for line in "${present[@]}"; do
      echo "already in '$shell_rc': $line"
    done
    for line in "${missing[@]}"; do
      echo "${prefix}append to '$shell_rc': $line"
    done
    if [ ${#missing[@]} -gt 0 ] && [ $dry_run = false ]; then
      security_key_openpgp_ssh_append_lines "$shell_rc" "$marker" "${missing[@]}" || \
        error "security_key_openpgp_ssh setup: could not write '$shell_rc'." 1
    fi
    [ ${#missing[@]} -gt 0 ] && \
      echo "open a new shell, or source '$shell_rc', for them to take effect."
  fi
  cat <<'SSH_HINT'

if the PIN prompt shows up in another terminal, or ssh fails with "agent
refused operation", add this to ~/.ssh/config (sca does not edit it):

  Match host * exec "gpg-connect-agent updatestartuptty /bye"

then check with 'ssh-add -L', which should list a "cardno:..." key, and get
the public key for the server with 'sca security_key openpgp_ssh public_key'.
SSH_HINT
  log_detailed "security_key_openpgp_ssh_setup: finished (dry_run=$dry_run)"
}
################################################################################
# sca security_key openpgp_ssh public_key
security_key_openpgp_ssh_public_key() {
  local output=''
  local OPTS
  OPTS=`getopt -o ho: --long help,output: -n "sca security_key openpgp_ssh public_key" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_ssh_help
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
  [ $# -gt 0 ] && error "security_key_openpgp_ssh public_key: unexpected argument '$1'. "\
"use sca security_key openpgp_ssh -h for help." 1
  security_key_openpgp_ssh_need_tools gpg gpgconf
  log_detailed "security_key_openpgp_ssh_public_key: started (output='$output')"
  [ -n "$output" ] && [ -e "$output" ] && \
    error "security_key_openpgp_ssh public_key: '$output' already exists and is "\
"never overwritten. choose another file with -o FILE." 1
  local card_status
  card_status=$(gpg --batch --card-status --with-colons 2>/dev/null) || \
    error "security_key_openpgp_ssh public_key: no OpenPGP card found. plug in "\
"the YubiKey, check that pcscd or scdaemon can reach it ('gpg --card-status'), "\
"and that the OpenPGP packages are installed (sca install --openpgp)." 1
  # fpr:<signature>:<encryption>:<authentication>:
  local fingerprint
  fingerprint=$(printf '%s\n' "$card_status" | awk -F: '$1 == "fpr" { print $4; exit }')
  log_detailed "security_key_openpgp_ssh_public_key: authentication key='$fingerprint'"
  [[ "$fingerprint" =~ ^[0-9A-Fa-f]+$ ]] || \
    error "security_key_openpgp_ssh public_key: the card has no authentication "\
"key. put one on it, see docs/gpg-yubikey.md section 3 (Keys), or step 1 of "\
"OpenPGP (gpg-agent) SSH in docs/ssh-yubikey-options.md." 1
  # the ! exports this subkey, not whichever authentication key gpg picks
  if [ -z "$output" ]; then
    gpg --batch --export-ssh-key "${fingerprint}!" || \
      security_key_openpgp_ssh_export_failed "$fingerprint"
  else
    local tmp
    tmp=$(mktemp "$(dirname "$output")/.sca-openpgp-ssh.XXXXXX") || \
      error "security_key_openpgp_ssh public_key: could not create a temporary "\
"file next to '$output'." 1
    trap 'rm -f "$tmp"' EXIT
    if ! gpg --batch --export-ssh-key "${fingerprint}!" > "$tmp" || [ ! -s "$tmp" ]; then
      security_key_openpgp_ssh_export_failed "$fingerprint"
    fi
    chmod 644 "$tmp"
    # -n: a file that appeared meanwhile is still not overwritten
    if ! mv -n "$tmp" "$output" || [ -e "$tmp" ]; then
      error "security_key_openpgp_ssh public_key: could not write '$output'." 1
    fi
    trap - EXIT
    >&2 echo "the SSH public key was written to '$output'. add it to the server's ~/.ssh/authorized_keys."
  fi
  log_detailed "security_key_openpgp_ssh_public_key: finished (output='$output')"
}
################################################################################
# exits with what to do when gpg --export-ssh-key fails
#
# parameters
#   fingerprint - the card's authentication key
security_key_openpgp_ssh_export_failed() {
  error "security_key_openpgp_ssh public_key: gpg could not export the "\
"authentication key $1. its public key is probably not in this machine's "\
"keyring: import it with 'gpg --import <file>', or run 'gpg --card-edit' and "\
"'fetch' if the card has a URL set, then retry." 1
}
################################################################################
# exits, naming the first missing one, unless all the given tools are found
#
# parameters
#   tool... - gpg, gpgconf
security_key_openpgp_ssh_need_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || \
      error "security_key_openpgp_ssh: $tool not found. install the OpenPGP "\
"packages with sca install --openpgp." 1
  done
}
################################################################################
# appends lines to a file, adding a newline first if the file doesn't end with
# one. a missing file is created with mode 600.
#
# parameters
#   file   - the file to append to
#   marker - a comment line written before the lines, or empty for none
#   line...  - the lines to append
security_key_openpgp_ssh_append_lines() {
  local file="$1"
  local marker="$2"
  shift 2
  if [ ! -e "$file" ]; then
    (umask 077; : > "$file") || return 1
  fi
  {
    [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ] && echo
    [ -n "$marker" ] && printf '%s\n' "$marker"
    printf '%s\n' "$@"
  } >> "$file"
}
security_key_openpgp_ssh_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
