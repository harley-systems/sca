**What it does:**
- `create`: checks `--name`, `--email`, `--algo` and `--expire`, and refuses before making anything if a backup file already exists in `--backup-dir`
- `create` then runs `gpg --quick-generate-key "NAME <EMAIL>" <algo> cert never`, reads the fingerprint from the `KEY_CREATED` status line, and adds the subkeys with `gpg --quick-add-key <FPR> <algo> sign|encr|auth <expire>` (ed25519: `ed25519`, `cv25519`, `ed25519`; rsa4096: `rsa4096` for all three)
- `create` writes `master-and-subkeys.asc` (`--export-secret-keys`), `subkeys.asc` (`--export-secret-subkeys`), `public.asc` (`--export`) and `revoke.asc` (a copy of `openpgp-revocs.d/<FPR>.rev` in the GnuPG home), each through a temporary file with mode 600 and `mv -n`, to `~/.sca/keys/openpgp/<FPR>/` or `--backup-dir`. Folders it creates have mode 700. If a file can't be written, it names the ones that were and weren't, and leaves the key in place
- `to_card`: picks the key (`--fingerprint`, or the only one with a `[C]` master and exactly one `[S]`, `[E]` and `[A]` subkey on disk, not expired or revoked), and reads `gpg --card-status --with-colons`
- `to_card` refuses, before writing anything, when: `--device` is not the serial of the card gpg sees; there is no `--device` and `ykman list --serials` shows more than one key (or ykman is missing); an ed25519 or cv25519 subkey meets firmware before 5.2.3 (`ykman info`); a target slot is filled and there is no `--force`; `master-and-subkeys.asc` in the backup folder is missing or holds another key and there is no `--no-backup-check`
- `to_card` then runs one `gpg --edit-key <FPR> --command-fd 0 --status-fd 1` session: `key N`, `keytocard` and the slot (1 signature, 2 encryption, 3 authentication) for each subkey, then `save`. Any unexpected prompt, failure or repeated secret request makes it `quit` without saving, and it reports which slots were already written. Afterwards each subkey must be a card stub (`ssb>`)
- Without `--passphrase-file` and `--admin-pin-file` sca never sees a secret: gpg's pinentry asks. With them, gpg runs with `--pinentry-mode loopback`; `create` passes the passphrase file to gpg, and `to_card` sends each secret through the `--command-fd` pipe only when gpg asks for it, never in argv, the environment of a command or `~/.sca/log`
- Neither mode needs `sca config`, and the touch policy is left alone

**Example:**
```bash
sca install --openpgp                            # gnupg, scdaemon, ykman
# on the offline machine
export GNUPGHOME="$(mktemp -d)"
sca security_key openpgp_key create --name "Alice Example" --email alice@example.com
# copy ~/.sca/keys/openpgp/<FPR>/ and $GNUPGHOME to an encrypted offline drive
sca security_key openpgp_key to_card --device 12345678
ykman openpgp keys set-touch sig on              # optional, see section 4
sca security_key openpgp_key create --name "CI Test" --email ci@example.com \
  --passphrase-file pass.txt --backup-dir ./backup
sca security_key openpgp_key to_card --device 12345678 --backup-dir ./backup \
  --passphrase-file pass.txt --admin-pin-file admin-pin.txt   # unattended
```

See [GPG with a YubiKey](../gpg-yubikey.md#option-b-offline-master-key-recommended) for what the commands do by hand, and [touch policies](../gpg-yubikey.md#4-touch-policies).
