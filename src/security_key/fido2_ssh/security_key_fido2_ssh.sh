################################################################################
# create or restore a FIDO2 SSH key (ed25519-sk / ecdsa-sk) on a yubikey
#
# sca does not set, read or store the FIDO2 PIN: ssh-keygen asks for it, with
# the terminal attached, and nothing it prints is captured or logged.
security_key_fido2_ssh() {
  local mode="$1"
  case "$mode" in
    -h | --help )
      security_key_fido2_ssh_help
      return
      ;;
    create|restore )
      shift
      log_detailed "security_key_fido2_ssh: start (mode=${mode})"
      security_key_fido2_ssh_$mode "$@"
      ;;
    * )
      error "security_key_fido2_ssh: invalid value '$mode' for the mode. supported "\
"values are 'create' and 'restore'. use sca security_key fido2_ssh -h for help." 1
      ;;
  esac
}
################################################################################
# sca security_key fido2_ssh create
security_key_fido2_ssh_create() {
  local resident=true
  local verify=true
  local application_name=sca
  local comment=''
  local comment_set=false
  local output=''
  local OPTS
  OPTS=`getopt -o h --long help,non-resident,no-verify,application:,comment:,output: \
    -n "sca security_key fido2_ssh create" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key fido2_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_fido2_ssh_help
        return
      ;;
      --non-resident )
        resident=false
        shift
      ;;
      --no-verify )
        verify=false
        shift
      ;;
      --application )
        application_name=${2#ssh:}
        shift;shift
      ;;
      --comment )
        comment=$2
        comment_set=true
        shift;shift
      ;;
      --output )
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
  [ $# -gt 0 ] && error "security_key_fido2_ssh create: unexpected argument '$1'. "\
"use sca security_key fido2_ssh -h for help." 1
  [[ "$application_name" =~ ^[A-Za-z0-9._-]+$ ]] || \
    error "security_key_fido2_ssh create: invalid --application '$application_name'. "\
"use NAME or ssh:NAME, where NAME has only letters, digits, '.', '_' and '-'." 1
  log_detailed "security_key_fido2_ssh_create: started (resident=$resident, "\
"verify=$verify, application=ssh:$application_name, output='$output')"
  local need_pin=false
  [ $resident = true ] || [ $verify = true ] && need_pin=true
  security_key_fido2_ssh_preflight $need_pin $verify
  local key_type
  key_type=$(security_key_fido2_ssh_key_type) || exit $?
  # the names ssh tries by default, and for a resident key the name ssh-keygen
  # -K gives it on another machine, so that create and restore agree
  if [ -z "$output" ]; then
    output=~/.ssh/id_${key_type//-/_}
    [ $resident = true ] && output="${output}_rk_${application_name}"
  fi
  # ssh-keygen only asks "Overwrite (y/n)?", and that prompt must never be
  # reached: an existing key is refused before ssh-keygen runs
  local existing
  for existing in "$output" "$output.pub"; do
    if [ -e "$existing" ]; then
      local hint="--output FILE"
      [ $resident = true ] && hint="--output FILE or another --application NAME"
      error "security_key_fido2_ssh create: '$existing' already exists and is "\
"never overwritten. choose another file with $hint." 1
    fi
  done
  local output_dir
  output_dir=$(dirname "$output")
  if [ ! -d "$output_dir" ]; then
    (umask 077; mkdir -p "$output_dir") || \
      error "security_key_fido2_ssh create: could not create '$output_dir'." 1
  fi
  local keygen=(ssh-keygen -t "$key_type" -f "$output" -O "application=ssh:$application_name")
  [ $resident = true ] && keygen+=(-O resident)
  [ $verify = true ] && keygen+=(-O verify-required)
  [ $comment_set = true ] && keygen+=(-C "$comment")
  log_detailed "security_key_fido2_ssh_create: running ssh-keygen (key_type=$key_type, "\
"output='$output', resident=$resident, verify=$verify)"
  echo "creating a FIDO2 SSH key in '$output'. touch the YubiKey when it blinks."
  # with the terminal attached: ssh-keygen asks for the touch, the FIDO2 PIN
  # and an optional passphrase
  "${keygen[@]}" || \
    error "security_key_fido2_ssh create: ssh-keygen failed, no key was created." 1
  [ -f "$output.pub" ] || \
    error "security_key_fido2_ssh create: ssh-keygen did not write '$output.pub'." 1
  echo
  echo "the public key ('$output.pub'):"
  echo
  cat "$output.pub"
  echo
  echo "next step: add this line to the server's ~/.ssh/authorized_keys. the"
  if [ $verify = true ]; then
    echo "server needs OpenSSH 8.2 or later, and 8.4 or later to enforce"
    echo "verify-required."
  else
    echo "server needs OpenSSH 8.2 or later."
  fi
  if [ "$output" != ~/.ssh/id_${key_type//-/_} ]; then
    echo "ssh does not try '$output' by default: use 'ssh -i $output',"
    echo "an 'IdentityFile $output' line in ~/.ssh/config, or 'ssh-add $output'."
  fi
  log_detailed "security_key_fido2_ssh_create: finished (output='$output')"
}
################################################################################
# sca security_key fido2_ssh restore
security_key_fido2_ssh_restore() {
  local output_dir=~/.ssh
  local OPTS
  OPTS=`getopt -o h --long help,output-dir: -n "sca security_key fido2_ssh restore" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key fido2_ssh -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_fido2_ssh_help
        return
      ;;
      --output-dir )
        output_dir=$2
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
  [ $# -gt 0 ] && error "security_key_fido2_ssh restore: unexpected argument '$1'. "\
"use sca security_key fido2_ssh -h for help." 1
  log_detailed "security_key_fido2_ssh_restore: started (output_dir='$output_dir')"
  security_key_fido2_ssh_preflight true false
  if [ ! -d "$output_dir" ]; then
    (umask 077; mkdir -p "$output_dir") || \
      error "security_key_fido2_ssh restore: could not create '$output_dir'." 1
  fi
  # ssh-keygen -K writes to the current folder and asks before overwriting, so
  # it runs in an empty folder next to the target, on the same filesystem, and
  # only what doesn't exist yet is moved out of it
  local restore_dir
  restore_dir=$(mktemp -d "$output_dir/.sca-fido2-restore.XXXXXX") || \
    error "security_key_fido2_ssh restore: could not create a temporary folder in '$output_dir'." 1
  trap 'rm -rf "$restore_dir"' EXIT
  echo "restoring the resident FIDO2 SSH keys. touch the YubiKey when it blinks."
  ( cd "$restore_dir" && ssh-keygen -K ) || \
    error "security_key_fido2_ssh restore: ssh-keygen -K failed, nothing was restored." 1
  local restored=() skipped=()
  local file name
  for file in "$restore_dir"/* "$restore_dir"/.[!.]*; do
    [ -e "$file" ] || continue
    name=${file##*/}
    if [ -e "$output_dir/$name" ] || ! mv -n "$file" "$output_dir/$name" || \
        [ -e "$file" ]; then
      skipped+=("$output_dir/$name")
    else
      restored+=("$output_dir/$name")
    fi
  done
  # the trap only covers the exits above: restore_dir is local, so it is gone
  # by the time the script exits after a return
  rm -rf "$restore_dir"
  trap - EXIT
  log_detailed "security_key_fido2_ssh_restore: restored=${#restored[@]}, skipped=${#skipped[@]}"
  if [ ${#restored[@]} -eq 0 ] && [ ${#skipped[@]} -eq 0 ]; then
    echo "no resident keys on this device."
    return
  fi
  for file in "${restored[@]}"; do
    echo "restored: $file"
  done
  for file in "${skipped[@]}"; do
    echo "skipped: $file (kept the existing file, the restored copy was discarded)"
  done
  [ ${#skipped[@]} -gt 0 ] && \
    error "security_key_fido2_ssh restore: ${#skipped[@]} file(s) already existed "\
"and were kept. to get the restored copies, use another --output-dir." 1
  log_detailed "security_key_fido2_ssh_restore: finished (output_dir='$output_dir')"
}
################################################################################
# the checks before ssh-keygen runs. each failure exits with what to do next.
#
# parameters
#   need_pin    - true when the FIDO2 PIN will be asked for (resident keys,
#                 verify-required, restore)
#   need_verify - true when -O verify-required is used
security_key_fido2_ssh_preflight() {
  local need_pin=$1
  local need_verify=$2
  command -v ssh-keygen >/dev/null 2>&1 || \
    error "security_key_fido2_ssh: ssh-keygen not found. install OpenSSH 8.2 or "\
"later with FIDO2 support; on Ubuntu/Debian sca install --fido2." 1
  local version
  version=$(openssh_client_version)
  log_detailed "security_key_fido2_ssh_preflight: openssh version='$version'"
  [ -z "$version" ] && \
    error "security_key_fido2_ssh: could not tell the OpenSSH version from 'ssh -V'. "\
"FIDO2 SSH keys need the OpenSSH client 8.2 or later; on Ubuntu/Debian sca install --fido2." 1
  openssh_version_at_least "$version" 8.2 || \
    error "security_key_fido2_ssh: OpenSSH $version is too old for FIDO2 SSH keys, "\
"which need 8.2 or later. install a newer OpenSSH; on Ubuntu/Debian sca install --fido2." 1
  if [ "$need_verify" = true ] && ! openssh_version_at_least "$version" 8.3; then
    error "security_key_fido2_ssh: OpenSSH $version has no verify-required, which "\
"needs 8.3 or later. install a newer OpenSSH, or create the key with --no-verify." 1
  fi
  command -v ykman >/dev/null 2>&1 || \
    error "security_key_fido2_ssh: ykman not found. on Ubuntu/Debian sca install "\
"--fido2 installs it." 1
  # ykman list, not --serials: Security Key series devices often have no serial
  local devices
  devices=$(ykman list 2>/dev/null | awk 'NF' | wc -l | tr -d ' ')
  log_detailed "security_key_fido2_ssh_preflight: devices=$devices"
  [ "$devices" -eq 0 ] && \
    error "security_key_fido2_ssh: no YubiKey found. plug in the YubiKey to use, "\
"and leave exactly one plugged in." 1
  [ "$devices" -gt 1 ] && \
    error "security_key_fido2_ssh: $devices YubiKeys are plugged in, and ssh-keygen "\
"can not choose between them. leave exactly one plugged in." 1
  if [ "$need_pin" = true ]; then
    # ykman 4 prints "PIN is not set", ykman 5 "PIN: Not set". anything else
    # passes, and ssh-keygen reports its own failures.
    if ykman fido info 2>&1 | grep -qiE 'PIN.*not set'; then
      error "security_key_fido2_ssh: no FIDO2 PIN is set on the YubiKey, and "\
"resident keys and verify-required need one. set one with 'ykman fido access "\
"change-pin' (it is separate from the PIV and OpenPGP PINs), or create a "\
"non-resident key with --non-resident --no-verify." 1
    fi
  fi
}
################################################################################
# prints ed25519-sk when the yubikey firmware is 5.2.3 or later, otherwise
# ecdsa-sk, which works on every FIDO key. says which, and why, on stderr.
security_key_fido2_ssh_key_type() {
  local firmware
  firmware=$(ykman info 2>/dev/null | \
    sed -n 's/^[[:space:]]*Firmware version:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | \
    head -n 1)
  log_detailed "security_key_fido2_ssh_key_type: firmware='$firmware'"
  local key_type=ecdsa-sk
  if [ -z "$firmware" ]; then
    >&2 echo "using ecdsa-sk (the firmware version could not be read; ecdsa-sk works on every FIDO key)"
  else
    if printf '%s\n' "$firmware" | \
        awk -F. '{ exit !($1 > 5 || ($1 == 5 && ($2 > 2 || ($2 == 2 && $3 >= 3)))) }'; then
      key_type=ed25519-sk
    fi
    >&2 echo "using $key_type (firmware $firmware)"
  fi
  echo $key_type
}
security_key_fido2_ssh_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
