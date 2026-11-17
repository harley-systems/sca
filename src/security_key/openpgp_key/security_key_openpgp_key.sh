################################################################################
# create an OpenPGP identity (an offline certify-only master key with sign,
# encrypt and authenticate subkeys) and back it up, then move the subkeys to
# the OpenPGP applet of a yubikey
#
# neither mode reads the sca configuration. without --passphrase-file and
# --admin-pin-file sca handles no secret: gpg's pinentry asks for them. with
# them, the secrets go to gpg through a file it reads (create) or the
# --command-fd pipe (to_card), never through argv, the environment or the log.
security_key_openpgp_key() {
  local mode="$1"
  case "$mode" in
    -h | --help )
      security_key_openpgp_key_help
      return
      ;;
    create|to_card )
      shift
      log_detailed "security_key_openpgp_key: start (mode=${mode})"
      security_key_openpgp_key_$mode "$@"
      ;;
    * )
      error "security_key_openpgp_key: invalid value '$mode' for the mode. supported "\
"values are 'create' and 'to_card'. use sca security_key openpgp_key -h for help." 1
      ;;
  esac
}
# the backup files create writes, named as in docs/gpg-yubikey.md section 3.3
security_key_openpgp_key_backups=(master-and-subkeys.asc subkeys.asc public.asc revoke.asc)
################################################################################
# sca security_key openpgp_key create
security_key_openpgp_key_create() {
  local name='' email='' algo=ed25519 expire=2y backup_dir='' passphrase_file=''
  local OPTS
  OPTS=`getopt -o h --long help,name:,email:,algo:,expire:,backup-dir:,passphrase-file: -n "sca security_key openpgp_key create" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_key -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_key_help
        return
      ;;
      --name )
        name=$2
        shift;shift
      ;;
      --email )
        email=$2
        shift;shift
      ;;
      --algo )
        algo=$2
        shift;shift
      ;;
      --expire )
        expire=$2
        shift;shift
      ;;
      --backup-dir )
        backup_dir=$2
        shift;shift
      ;;
      --passphrase-file )
        passphrase_file=$2
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
  [ $# -gt 0 ] && error "security_key_openpgp_key create: unexpected argument '$1'. "\
"use sca security_key openpgp_key -h for help." 1
  [ -n "$name" ] && [ -n "$email" ] || error "security_key_openpgp_key create: "\
"--name and --email are required. use sca security_key openpgp_key -h for help." 1
  [[ "$name" == *[\<\>]* || "$name" == *$'\n'* ]] && error "security_key_openpgp_key "\
"create: the name '$name' must not contain '<', '>' or a newline." 1
  [[ "$email" =~ ^[^[:space:]\<\>@]+@[^[:space:]\<\>@]+$ ]] || error \
"security_key_openpgp_key create: '$email' is not an email address (name@domain)." 1
  local master_algo sub_algos
  case "$algo" in
    ed25519 )
      master_algo=ed25519
      sub_algos=(ed25519 cv25519 ed25519)
      ;;
    rsa4096 )
      master_algo=rsa4096
      sub_algos=(rsa4096 rsa4096 rsa4096)
      ;;
    * )
      error "security_key_openpgp_key create: invalid value '$algo' for --algo. "\
"supported values are 'ed25519' and 'rsa4096' (for firmware before 5.2.3)." 1
      ;;
  esac
  # checked here: a value gpg refuses would leave a master key without subkeys
  [[ "$expire" =~ ^(never|[1-9][0-9]*[dwmy]?|[0-9]{4}-[0-9]{2}-[0-9]{2})$ ]] || \
    error "security_key_openpgp_key create: invalid value '$expire' for --expire. "\
"use never, a number of days, weeks, months or years (e.g. 2y), or a date "\
"(YYYY-MM-DD)." 1
  security_key_openpgp_key_need_tools gpg gpgconf
  local secret_opts=()
  if [ -n "$passphrase_file" ]; then
    # only checked: gpg reads the file itself
    security_key_openpgp_key_read_secret '' "$passphrase_file" --passphrase-file
    secret_opts=(--pinentry-mode loopback --passphrase-file "$passphrase_file")
  fi
  local uid="$name <$email>"
  log_detailed "security_key_openpgp_key_create: started (uid='$uid', algo=$algo, "\
"expire=$expire, backup_dir='$backup_dir', passphrase_file='$passphrase_file')"
  local homedir
  homedir=$(gpgconf --list-dirs homedir)
  if [ $? != 0 ] || [ -z "$homedir" ]; then
    error "security_key_openpgp_key create: 'gpgconf --list-dirs homedir' failed. "\
"check the GnuPG installation, or run sca install --openpgp." 1
  fi

  # everything that can stop the backup is checked before a key exists, so a
  # refusal leaves no key without a backup in the keyring
  local file
  if [ -n "$backup_dir" ]; then
    for file in "${security_key_openpgp_key_backups[@]}"; do
      [ -e "$backup_dir/$file" ] && error "security_key_openpgp_key create: "\
"'$backup_dir/$file' already exists and is never overwritten. nothing was "\
"created. choose another --backup-dir." 1
    done
    security_key_openpgp_key_make_dir "$backup_dir"
  else
    security_key_openpgp_key_make_dir "$HOME/.sca/keys/openpgp"
  fi

  local status fingerprint
  status=$(gpg --batch "${secret_opts[@]}" --status-fd 3 \
    --quick-generate-key "$uid" "$master_algo" cert never 3>&1 1>&2)
  local rc=$?
  log_detailed "security_key_openpgp_key_create: generate rc=$rc, status: $status"
  # KEY_CREATED P <fingerprint>
  fingerprint=$(printf '%s\n' "$status" | awk '$1 == "[GNUPG:]" && $2 == "KEY_CREATED" { print $4; exit }')
  if [ $rc != 0 ] || ! [[ "$fingerprint" =~ ^[0-9A-F]{40}([0-9A-F]{24})?$ ]]; then
    error "security_key_openpgp_key create: gpg could not create the master "\
"key (see its message above). nothing was created." 1
  fi
  local usages=(sign encr auth) i
  for i in 0 1 2; do
    if ! gpg --batch "${secret_opts[@]}" --quick-add-key "$fingerprint" \
        "${sub_algos[$i]}" "${usages[$i]}" "$expire"; then
      error "security_key_openpgp_key create: the master key $fingerprint was "\
"created, but gpg could not add its ${usages[$i]} subkey (see its message "\
"above). nothing was backed up. delete the key (gpg --delete-secret-and-public-key "\
"$fingerprint) and retry, or add the subkeys by hand (docs/gpg-yubikey.md section 3.2)." 1
    fi
  done

  [ -z "$backup_dir" ] && backup_dir="$HOME/.sca/keys/openpgp/$fingerprint"
  local written=() missing=()
  # a failure here shows up below as files not written
  [ -d "$backup_dir" ] || (umask 077; mkdir -p "$backup_dir")
  for file in "${security_key_openpgp_key_backups[@]}"; do
    case "$file" in
      master-and-subkeys.asc )
        set -- gpg --batch "${secret_opts[@]}" --armor --export-secret-keys "$fingerprint" ;;
      subkeys.asc )
        set -- gpg --batch "${secret_opts[@]}" --armor --export-secret-subkeys "$fingerprint" ;;
      public.asc )
        set -- gpg --batch --armor --export "$fingerprint" ;;
      revoke.asc )
        set -- cat "$homedir/openpgp-revocs.d/$fingerprint.rev" ;;
    esac
    if security_key_openpgp_key_write_backup "$backup_dir/$file" "$@"; then
      written+=("$file")
    else
      missing+=("$file")
    fi
  done
  log_detailed "security_key_openpgp_key_create: written='${written[*]}', missing='${missing[*]}'"
  if [ ${#missing[@]} -gt 0 ]; then
    error "security_key_openpgp_key create: the key $fingerprint was created, but "\
"not all of its backup was written to '$backup_dir'. written: ${written[*]:-none}. "\
"not written: ${missing[*]}. the key was not deleted: write the missing files by "\
"hand (docs/gpg-yubikey.md section 3.3) before moving it to a card." 1
  fi

  cat <<CREATE_DONE
created the OpenPGP key $fingerprint
  user ID:     $uid
  subkeys:     [S] ${sub_algos[0]}, [E] ${sub_algos[1]}, [A] ${sub_algos[2]}, expiring $expire
  GNUPGHOME:   $homedir
  backup:      $backup_dir
               $(printf '%s ' "${security_key_openpgp_key_backups[@]}")

copy the backup files, together with the admin PIN and reset code, to an
encrypted USB drive (or two) that stays offline. only public.asc leaves the
offline machine. the secret key backups are protected by the key's
passphrase: keep the passphrase with them, or they can't be restored. keep a
copy of the whole GNUPGHOME too, to load a backup YubiKey, rotate subkeys or
extend their expiry later.

next, move the subkeys to the YubiKey:

  sca security_key openpgp_key to_card --device <serial>
CREATE_DONE
  log_detailed "security_key_openpgp_key_create: finished (fingerprint=$fingerprint)"
}
################################################################################
# sca security_key openpgp_key to_card
security_key_openpgp_key_to_card() {
  local device='' fingerprint='' backup_dir='' force=false backup_check=true
  local passphrase_file='' admin_pin_file=''
  local OPTS
  OPTS=`getopt -o h --long help,device:,fingerprint:,backup-dir:,force,no-backup-check,passphrase-file:,admin-pin-file: -n "sca security_key openpgp_key to_card" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options. use sca security_key openpgp_key -h for help." 1; fi
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      -h | --help )
        security_key_openpgp_key_help
        return
      ;;
      --device )
        device=$2
        shift;shift
      ;;
      --fingerprint )
        fingerprint=$2
        shift;shift
      ;;
      --backup-dir )
        backup_dir=$2
        shift;shift
      ;;
      --force )
        force=true
        shift
      ;;
      --no-backup-check )
        backup_check=false
        shift
      ;;
      --passphrase-file )
        passphrase_file=$2
        shift;shift
      ;;
      --admin-pin-file )
        admin_pin_file=$2
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
  [ $# -gt 0 ] && error "security_key_openpgp_key to_card: unexpected argument '$1'. "\
"use sca security_key openpgp_key -h for help." 1
  security_key_openpgp_key_need_tools gpg
  # with a secret file gpg runs in loopback mode, and every secret, given or
  # not, comes through the --command-fd pipe. without, pinentry asks for them.
  local loopback=false passphrase='' admin_pin=''
  if [ -n "$passphrase_file" ] || [ -n "$admin_pin_file" ]; then
    loopback=true
    # loopback mode has no pinentry to fall back on for the admin PIN
    [ -n "$admin_pin_file" ] || error "security_key_openpgp_key to_card: "\
"--passphrase-file needs --admin-pin-file too, or leave out both to type them "\
"in pinentry." 1
    security_key_openpgp_key_need_tools gpg-connect-agent
    [ -n "$passphrase_file" ] && \
      security_key_openpgp_key_read_secret passphrase "$passphrase_file" --passphrase-file
    [ -n "$admin_pin_file" ] && \
      security_key_openpgp_key_read_secret admin_pin "$admin_pin_file" --admin-pin-file
  fi
  log_detailed "security_key_openpgp_key_to_card: started (device='$device', "\
"fingerprint='$fingerprint', backup_dir='$backup_dir', force=$force, "\
"backup_check=$backup_check, passphrase_file='$passphrase_file', "\
"admin_pin_file='$admin_pin_file')"

  # 1 and 2: the key, and one subkey per card slot
  security_key_openpgp_key_pick "$fingerprint"
  fingerprint=$security_key_openpgp_key_fpr
  local slot_names=('' 'Signature key' 'Encryption key' 'Authentication key')
  local index=('' "${security_key_openpgp_key_index[@]}")
  local sub_fpr=('' "${security_key_openpgp_key_sub_fpr[@]}")
  local grip=('' "${security_key_openpgp_key_grip[@]}")
  local attr=('' "${security_key_openpgp_key_attr[@]}")
  local slot
  for slot in 1 2 3; do
    log_detailed "security_key_openpgp_key_to_card: slot $slot: key ${index[$slot]} "\
"${sub_fpr[$slot]} (${attr[$slot]})"
  done

  # 3: the card gpg will write to
  local card_status
  card_status=$(gpg --batch --card-status --with-colons 2>/dev/null) || \
    error "security_key_openpgp_key to_card: no OpenPGP card found. plug in "\
"the YubiKey, check that pcscd or scdaemon can reach it ('gpg --card-status'), "\
"and that the OpenPGP packages are installed (sca install --openpgp)." 1
  local card_serial
  card_serial=$(printf '%s\n' "$card_status" | awk -F: '$1 == "serial" { sub(/^0+/, "", $2); print $2; exit }')
  log_detailed "security_key_openpgp_key_to_card: card serial='$card_serial'"
  local ykman_device=''
  if [ -n "$device" ]; then
    # a yubikey 5's OpenPGP serial is its device serial
    [ "$card_serial" = "$(sed 's/^0*//' <<< "$device")" ] || \
      error "security_key_openpgp_key to_card: gpg would write to the card "\
"with serial '$card_serial', not $device. unplug the other keys, so only $device "\
"is attached, and retry." 1
    ykman_device=$device
  else
    command -v ykman >/dev/null 2>&1 || error "security_key_openpgp_key to_card: "\
"ykman not found, so sca can't check that only one YubiKey is attached. install "\
"it with sca install --openpgp, or name the key with --device SERIAL." 1
    local serials
    mapfile -t serials < <(ykman list --serials 2>/dev/null | grep .)
    log_detailed "security_key_openpgp_key_to_card: attached serials: ${serials[*]}"
    if [ ${#serials[@]} -gt 1 ]; then
      {
        echo "more than one YubiKey is attached:"
        printf '  %s\n' "${serials[@]}"
      } >&2
      error "security_key_openpgp_key to_card: choose the key with --device "\
"SERIAL, and unplug the others: gpg writes to whichever card it finds first." 1
    fi
    ykman_device=${serials[0]}
  fi

  # 4: ed25519 and cv25519 on the card need firmware 5.2.3
  if [[ "${attr[*]}" == *25519* ]]; then
    if ! command -v ykman >/dev/null 2>&1; then
      >&2 echo "warning: ykman not found, so the firmware is not checked. ed25519 "\
"and cv25519 keys need YubiKey firmware 5.2.3 or later."
    else
      local firmware
      if [ -n "$ykman_device" ]; then
        firmware=$(ykman --device "$ykman_device" info 2>/dev/null)
      else
        firmware=$(ykman info 2>/dev/null)
      fi
      firmware=$(printf '%s\n' "$firmware" | awk -F': *' '/^Firmware version/ { print $2; exit }')
      log_detailed "security_key_openpgp_key_to_card: firmware='$firmware'"
      if [[ "$firmware" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        if [ $(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] )) -lt 50203 ]; then
          error "security_key_openpgp_key to_card: the YubiKey has firmware "\
"$firmware, and ed25519/cv25519 keys need 5.2.3 or later. recreate the key "\
"with 'sca security_key openpgp_key create --algo rsa4096'." 1
        fi
      else
        >&2 echo "warning: could not read the YubiKey's firmware version, so it "\
"is not checked. ed25519 and cv25519 keys need firmware 5.2.3 or later."
      fi
    fi
  fi

  # 5: slots that already hold a key. fpr:<signature>:<encryption>:<authentication>:
  local card_fpr card_attr filled=()
  IFS=: read -r -a card_fpr <<< "$(printf '%s\n' "$card_status" | awk -F: '$1 == "fpr" { print; exit }')"
  for slot in 1 2 3; do
    [ -n "${card_fpr[$slot]}" ] && filled+=("  ${slot_names[$slot]}: ${card_fpr[$slot]}")
  done
  if [ ${#filled[@]} -gt 0 ]; then
    if [ $force = false ]; then
      {
        echo "these card slots already hold a key:"
        printf '%s\n' "${filled[@]}"
      } >&2
      error "security_key_openpgp_key to_card: nothing was moved. to replace "\
"those keys (they are lost unless they are backed up), rerun with --force." 1
    fi
    >&2 echo "replacing the keys in these card slots (--force):"
    >&2 printf '%s\n' "${filled[@]}"
  fi

  # 6: a backup of this key, since save deletes the subkeys from the disk
  [ -z "$backup_dir" ] && backup_dir="$HOME/.sca/keys/openpgp/$fingerprint"
  if [ $backup_check = true ]; then
    local backup="$backup_dir/master-and-subkeys.asc"
    [ -s "$backup" ] || error "security_key_openpgp_key to_card: no backup "\
"'$backup' found. moving the subkeys deletes them from this machine, so back "\
"them up first (docs/gpg-yubikey.md section 3.3), give its folder with "\
"--backup-dir DIR, or skip this check with --no-backup-check." 1
    gpg --batch --show-keys --with-colons "$backup" 2>/dev/null | \
      awk -F: -v fpr="$fingerprint" '$1 == "fpr" && toupper($10) == fpr { found = 1 } END { exit !found }' || \
      error "security_key_openpgp_key to_card: '$backup' is not a backup of "\
"the key $fingerprint. give the right folder with --backup-dir DIR, or skip "\
"this check with --no-backup-check." 1
  fi

  # which secrets loopback mode will ask for: the key's passphrase only when
  # the subkey is protected, and the admin PIN once per verification
  local protected=('' '' '' '') pin_asks=('' 1 1 1)
  if [ $loopback = true ]; then
    local keyinfo
    for slot in 1 2 3; do
      keyinfo=$(gpg-connect-agent "KEYINFO ${grip[$slot]}" /bye 2>/dev/null | awk '$1 == "S" && $2 == "KEYINFO" { print $8; exit }')
      log_detailed "security_key_openpgp_key_to_card: slot $slot protection='$keyinfo'"
      case "$keyinfo" in
        P ) protected[$slot]=true ;;
        C ) protected[$slot]=false ;;
        * )
          error "security_key_openpgp_key to_card: gpg-agent can't tell whether "\
"the subkey ${sub_fpr[$slot]} has a passphrase. leave out --passphrase-file and "\
"--admin-pin-file, and type them in pinentry." 1
          ;;
      esac
      if [ ${protected[$slot]} = true ] && [ -z "$passphrase_file" ]; then
        error "security_key_openpgp_key to_card: the subkeys have a passphrase: "\
"give it with --passphrase-file FILE as well, or leave out --admin-pin-file to "\
"type both in pinentry." 1
      fi
      # GnuPG 2.2 asks for the admin PIN a second time when it first has to
      # change the slot's key attribute (e.g. from rsa2048 to ed25519)
      card_attr=$(printf '%s\n' "$card_status" | awk -F: -v slot=$slot '$1 == "keyattr" && $2 == slot { print $3 ":" $4; exit }')
      [ -n "$card_attr" ] && [ "${card_attr,,}" != "${attr[$slot],,}" ] && pin_asks[$slot]=2
      log_detailed "security_key_openpgp_key_to_card: slot $slot card attribute "\
"'$card_attr', admin PIN asked at most ${pin_asks[$slot]} time(s)"
    done
  fi

  # 7: move them, in one gpg --edit-key session
  local cmds=()
  for slot in 1 2 3; do
    cmds+=("key ${index[$slot]}" keytocard "key ${index[$slot]}")
  done
  cmds+=(save)
  local gpg_opts=(--no-tty --no-greeting --command-fd 0 --status-fd 1)
  [ $loopback = true ] && gpg_opts+=(--pinentry-mode loopback)
  # stdin is the pipe, so tell pinentry which terminal to use
  [ -z "$GPG_TTY" ] && [ -t 0 ] && GPG_TTY=$(tty) && export GPG_TTY
  >&2 echo "moving the subkeys of $fingerprint to the card $card_serial..."
  log_detailed "security_key_openpgp_key_to_card: gpg ${gpg_opts[*]} --edit-key $fingerprint"
  coproc SCA_OPENPGP_KEY_GPG { gpg "${gpg_opts[@]}" --edit-key "$fingerprint"; }
  local gpg_pid=$SCA_OPENPGP_KEY_GPG_PID gpg_out gpg_in
  # copies: bash closes the coproc's own descriptors as soon as gpg exits
  exec {gpg_out}<&"${SCA_OPENPGP_KEY_GPG[0]}" {gpg_in}>&"${SCA_OPENPGP_KEY_GPG[1]}"
  local line words answer next=0 step=0 failure='' written=()
  local asked_slot=0 sent_passphrase=0 sent_pin=0 op_failed=''
  local prompts=0
  while IFS= read -r line <&"$gpg_out"; do
    [[ "$line" == "[GNUPG:] "* ]] || continue
    log_detailed "security_key_openpgp_key_to_card: gpg: ${line#\[GNUPG:\] }"
    read -r -a words <<< "${line#\[GNUPG:\] }"
    answer=''
    case "${words[0]}" in
      SC_OP_FAILURE )
        case "${words[1]}" in
          1 ) op_failed='it was cancelled' ;;
          2 ) op_failed='the card refused the admin PIN' ;;
          * ) op_failed='gpg-agent or the card reported an error (wrong passphrase?)' ;;
        esac
        continue
        ;;
      GET_LINE|GET_BOOL|GET_HIDDEN )
        prompts=$((prompts + 1))
        ;;
      * )
        continue
        ;;
    esac
    # a prompt: anything not expected right now aborts the run
    case "${words[0]} ${words[1]}" in
      "GET_LINE keyedit.prompt" )
        if [ $step != 0 ]; then
          # back from keytocard: it worked if it asked for the slot and
          # nothing failed. gpg prints no status for success.
          if [ -z "$failure" ] && [ $asked_slot = 1 ] && [ -z "$op_failed" ]; then
            written+=("$step")
          elif [ -z "$failure" ]; then
            failure="moving the subkey to the ${slot_names[$step],,} slot failed: ${op_failed:-see the gpg messages above}"
          fi
          step=0
        fi
        if [ -n "$failure" ]; then
          answer=quit
        else
          answer=${cmds[$next]}
          next=$((next + 1))
          if [ "$answer" = keytocard ]; then
            step=$(( (next + 2) / 3 ))
            asked_slot=0 sent_passphrase=0 sent_pin=0 op_failed=''
          fi
        fi
        ;;
      "GET_LINE cardedit.genkeys.storekeytype" )
        if [ -z "$failure" ] && [ $step != 0 ] && [ $asked_slot = 0 ]; then
          answer=$step
          asked_slot=1
        else
          [ -z "$failure" ] && failure="gpg asked for the card slot again (the card may not take this key type)"
          answer=$'\x04'
        fi
        ;;
      "GET_BOOL cardedit.genkeys.replace_key" )
        if [ -z "$failure" ] && [ $step != 0 ] && [ $force = true ]; then
          answer=y
        else
          [ -z "$failure" ] && failure="the ${slot_names[$step],,} slot already holds a key (use --force to replace it)"
          answer=n
        fi
        ;;
      "GET_BOOL keyedit.save.okay" )
        answer=n
        ;;
      "GET_HIDDEN passphrase.enter" )
        # gpg-agent asks for the subkey's passphrase first, every time, then
        # scdaemon for the admin PIN. a wrong one fails the operation before
        # anything else is asked, so nothing is ever sent twice after a refusal.
        answer=$'\x04'
        if [ -n "$failure" ] || [ $loopback = false ] || [ $step = 0 ] || [ $asked_slot = 0 ]; then
          [ -z "$failure" ] && failure="gpg asked for a passphrase or PIN where sca expects none"
        elif [ "${protected[$step]}" = true ] && [ $sent_passphrase = 0 ]; then
          if [ $sent_pin = 0 ]; then
            log_detailed "security_key_openpgp_key_to_card: answering with the passphrase (not logged)"
            printf '%s\n' "$passphrase" >&"$gpg_in"
            sent_passphrase=1
            continue
          fi
          failure="gpg asked for the passphrase after the admin PIN"
        elif [ $sent_pin -lt "${pin_asks[$step]}" ] && [ -n "$admin_pin_file" ]; then
          log_detailed "security_key_openpgp_key_to_card: answering with the admin PIN (not logged)"
          printf '%s\n' "$admin_pin" >&"$gpg_in"
          sent_pin=$((sent_pin + 1))
          continue
        elif [ -z "$admin_pin_file" ]; then
          failure="gpg asked for the admin PIN: give it with --admin-pin-file FILE too, or leave out --passphrase-file to type both in pinentry"
        else
          failure="gpg asked for a passphrase or PIN again, so the one given was probably wrong. nothing more was sent"
        fi
        ;;
      * )
        [ -z "$failure" ] && failure="gpg asked something sca does not expect (${words[0]} ${words[1]})"
        if [ "${words[0]}" = GET_BOOL ]; then answer=n; else answer=$'\x04'; fi
        ;;
    esac
    # a gpg that keeps asking is stopped; its secrets are still on disk
    if [ $prompts -gt 100 ]; then
      kill "$gpg_pid" 2>/dev/null
      break
    fi
    log_detailed "security_key_openpgp_key_to_card: answering '${answer//$'\x04'/^D}'"
    printf '%s\n' "$answer" >&"$gpg_in"
  done
  exec {gpg_in}>&- {gpg_out}<&-
  wait "$gpg_pid"
  local rc=$?
  log_detailed "security_key_openpgp_key_to_card: gpg exited with $rc"
  if [ -z "$failure" ] && [ $next -lt ${#cmds[@]} ]; then
    failure="gpg stopped before the subkeys were moved (exit code $rc)"
  fi
  if [ -n "$failure" ]; then
    local done_slots=() s
    for s in "${written[@]}"; do done_slots+=("${slot_names[$s],,}"); done
    error "security_key_openpgp_key to_card: $failure. the changes were not "\
"saved, so the subkeys are still on this machine. card slots already written: "\
"${done_slots[*]:-none}. fix the cause and rerun (with --force, if a slot was "\
"written), or move them by hand (docs/gpg-yubikey.md section 3.4)." 1
  fi

  # 8: the subkeys must now be stubs pointing to the card
  local listing stubs=0
  listing=$(gpg --batch --list-secret-keys --with-colons "$fingerprint" 2>/dev/null)
  for slot in 1 2 3; do
    printf '%s\n' "$listing" | awk -F: -v fpr="${sub_fpr[$slot]}" '
      $1 == "ssb" { serial = $15 }
      $1 == "fpr" && $10 == fpr && serial != "+" && serial != "" { found = 1 }
      END { exit !found }' && stubs=$((stubs + 1))
  done
  [ $stubs = 3 ] || error "security_key_openpgp_key to_card: gpg saved, but "\
"only $stubs of the 3 subkeys now point to the card. check with 'gpg --card-status' "\
"and 'gpg --list-secret-keys $fingerprint', and restore the missing ones from "\
"the backup if needed." 1
  echo "the subkeys of $fingerprint are on the card $card_serial (ssb> below):"
  gpg --batch --list-secret-keys "$fingerprint"
  cat <<'TO_CARD_DONE'
the touch policy was not changed: to require a touch for each use, see
'ykman openpgp keys set-touch' (docs/gpg-yubikey.md section 4). then set up
SSH or Git with 'sca security_key openpgp_ssh' and 'sca security_key openpgp_git'.
TO_CARD_DONE
  log_detailed "security_key_openpgp_key_to_card: finished (fingerprint=$fingerprint)"
}
################################################################################
# finds the key to move and one movable subkey per card slot, or exits with
# what to do. sets security_key_openpgp_key_fpr, and the arrays (signature,
# encryption, authentication) security_key_openpgp_key_index (N in the gpg
# --edit-key "key N"), _sub_fpr, _grip and _attr (algorithm:size or curve, as
# in the keyattr lines of gpg --card-status --with-colons)
#
# parameters
#   fingerprint - the key to use, or empty for the only one that fits
security_key_openpgp_key_pick() {
  local wanted="$1"
  local listing
  listing=$(gpg --batch --list-secret-keys --with-colons --with-keygrip ${wanted:+"$wanted"} 2>/dev/null)
  if [ -n "$wanted" ] && [ -z "$listing" ]; then
    error "security_key_openpgp_key to_card: no secret key '$wanted' in this "\
"machine's keyring (gpg --list-secret-keys). check GNUPGHOME." 1
  fi
  # one line per key: <fpr>|<problems>|<signature>|<encryption>|<authentication>,
  # each subkey as "<n> <fpr> <grip> <attr>". a subkey is movable when it is
  # not expired or revoked and its secret is on disk (+), not a stub (#) or
  # on a card (a serial number). its own capabilities are the lower case ones.
  local keys
  keys=$(printf '%s\n' "$listing" | awk -F: '
    function end_sub(  u) {
      if (!insub) return
      insub = 0
      for (u in want)
        if (movable && index(caps, u)) { count[u]++; sel[u] = n " " sfpr " " sgrip " " attr }
    }
    function end_key(  u, problem) {
      end_sub()
      if (mfpr != "") {
        problem = (mcaps ~ /c/) ? "" : " no certify master key,"
        for (u in want) if (count[u] != 1) problem = problem " " count[u] + 0 " " want[u] ","
        if (problem == "" && (sel["s"] + 0 == sel["e"] + 0 || sel["s"] + 0 == sel["a"] + 0 || sel["e"] + 0 == sel["a"] + 0))
          problem = " one subkey for two uses,"
        sub(/,$/, "", problem)
        print mfpr "|" problem "|" sel["s"] "|" sel["e"] "|" sel["a"]
      }
      mfpr = ""; n = 0; split("", count); split("", sel)
    }
    BEGIN { want["s"] = "sign"; want["e"] = "encrypt"; want["a"] = "authenticate" }
    $1 == "sec" { end_key(); mcaps = $12; state = "sec"; next }
    $1 == "ssb" { end_sub(); insub = 1; n++; caps = $12; state = "ssb"
                  movable = ($15 == "+" && $2 !~ /[erid]/)
                  attr = ($4 == 1) ? "1:" $3 : $4 ":" $17; sfpr = ""; sgrip = ""; next }
    $1 == "fpr" && state == "sec" { mfpr = toupper($10); state = "" ; next }
    $1 == "fpr" && state == "ssb" && sfpr == "" { sfpr = toupper($10); next }
    $1 == "grp" && state == "ssb" && sgrip == "" { sgrip = $10; next }
    END { end_key() }')
  log_detailed "security_key_openpgp_key_pick: ${keys//$'\n'/; }"
  local line key problem s e a candidates=() chosen=''
  while IFS='|' read -r key problem s e a; do
    [ -z "$key" ] && continue
    if [ -n "$wanted" ]; then
      [ -n "$chosen" ] && error "security_key_openpgp_key to_card: '$wanted' "\
"matches more than one key. give the full fingerprint." 1
      [ -z "$problem" ] || error "security_key_openpgp_key to_card: the key "\
"$key needs exactly one subkey on disk, not expired or revoked, to sign, to "\
"encrypt and to authenticate. it has:$problem. move its subkeys by hand "\
"(docs/gpg-yubikey.md section 3.4)." 1
      chosen="$key|$s|$e|$a"
    elif [ -z "$problem" ]; then
      candidates+=("$key")
      chosen="$key|$s|$e|$a"
    fi
  done <<< "$keys"
  if [ -z "$wanted" ] && [ ${#candidates[@]} != 1 ]; then
    {
      if [ ${#candidates[@]} = 0 ]; then
        echo "no key in this keyring has a certify-only master key and exactly one"
        echo "[S], [E] and [A] subkey on disk."
      else
        echo "more than one key could be moved:"
        printf '  %s\n' "${candidates[@]}"
      fi
    } >&2
    error "security_key_openpgp_key to_card: choose the key with --fingerprint "\
"FPR, create one with 'sca security_key openpgp_key create', or move its "\
"subkeys by hand (docs/gpg-yubikey.md section 3.4)." 1
  fi
  IFS='|' read -r security_key_openpgp_key_fpr s e a <<< "$chosen"
  security_key_openpgp_key_index=() security_key_openpgp_key_sub_fpr=()
  security_key_openpgp_key_grip=() security_key_openpgp_key_attr=()
  local n fpr grip attr
  for line in "$s" "$e" "$a"; do
    read -r n fpr grip attr <<< "$line"
    security_key_openpgp_key_index+=("$n")
    security_key_openpgp_key_sub_fpr+=("$fpr")
    security_key_openpgp_key_grip+=("$grip")
    security_key_openpgp_key_attr+=("$attr")
  done
}
################################################################################
# reads a secret file into a variable, or exits: the file must be readable,
# not empty, and one line (one trailing newline is dropped, as gpg does)
#
# parameters
#   variable - the name of the variable to set, or empty to only check
#   file     - the file
#   option   - the option it came from, for the error message
security_key_openpgp_key_read_secret() {
  local __content=''
  [ -f "$2" ] && [ -r "$2" ] || error "security_key_openpgp_key: $3 '$2' "\
"is not a readable file." 1
  IFS= read -r -d '' __content < "$2"
  __content=${__content%$'\n'}
  [ -n "$__content" ] || error "security_key_openpgp_key: $3 '$2' is empty." 1
  [[ "$__content" == *$'\n'* ]] && error "security_key_openpgp_key: $3 '$2' "\
"has more than one line. put only the secret in it." 1
  [ -z "$1" ] || printf -v "$1" '%s' "$__content"
}
################################################################################
# creates a folder (and its parents) only the user can read, or exits
#
# parameters
#   dir - the folder
security_key_openpgp_key_make_dir() {
  [ -d "$1" ] || (umask 077; mkdir -p "$1") || \
    error "security_key_openpgp_key create: could not create the folder '$1'." 1
  [ -w "$1" ] || error "security_key_openpgp_key create: the folder '$1' is "\
"not writable." 1
}
################################################################################
# writes the output of a command to a new file with mode 600, through a
# temporary file in the same folder. an existing file is never overwritten.
# returns 1 if the command fails or prints nothing, or the file exists.
#
# parameters
#   file       - the file to write
#   command... - the command whose output goes into it
security_key_openpgp_key_write_backup() {
  local file="$1"
  shift
  local tmp
  if [ -e "$file" ]; then
    >&2 echo "error: '$file' already exists and is never overwritten."
    return 1
  fi
  tmp=$(mktemp "$(dirname "$file")/.sca-openpgp-key.XXXXXX") || return 1
  chmod 600 "$tmp"
  if ! "$@" > "$tmp" || [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    return 1
  fi
  # -n: a file that appeared meanwhile is still not overwritten
  if ! mv -n "$tmp" "$file" || [ -e "$tmp" ]; then
    rm -f "$tmp"
    return 1
  fi
  log_detailed "security_key_openpgp_key_write_backup: wrote '$file'"
}
################################################################################
# exits, naming the first missing one, unless all the given tools are found
#
# parameters
#   tool... - gpg, gpgconf, gpg-connect-agent
security_key_openpgp_key_need_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || \
      error "security_key_openpgp_key: $tool not found. install the OpenPGP "\
"packages with sca install --openpgp." 1
  done
}
security_key_openpgp_key_help() {
  cat <<'SCA_HELP'

@@@HELP@@@

SCA_HELP
}
