**What it does:**
- `setup`: appends `enable-ssh-support` to `gpg-agent.conf` in the GnuPG home folder (`gpgconf --list-dirs homedir`, so `GNUPGHOME` is honoured) unless it is already there, and then runs `gpgconf --kill gpg-agent`. When the option is already there the agent is left running, so its cached PIN is kept
- `setup` prints the shell lines to add (sh, bash and zsh syntax). `--shell-rc FILE` appends the ones FILE doesn't already have, after a `# added by sca security_key openpgp_ssh setup` comment
- `setup` prints the `~/.ssh/config` line `Match host * exec "gpg-connect-agent updatestartuptty /bye"` but never edits `~/.ssh/config`. `-n`, `--dry-run` prints what would change and changes nothing
- `public_key`: reads the authentication key's fingerprint from `gpg --card-status --with-colons` and runs `gpg --export-ssh-key <fingerprint>!`. `-o FILE` writes the key to FILE instead of stdout, and never overwrites an existing file
- Neither mode needs `sca config`, and gpg runs with `--batch`, so sca never asks for or sees the OpenPGP PIN

**Example:**
```bash
sca install --openpgp                         # gnupg, scdaemon, ykman
sca security_key openpgp_ssh setup --shell-rc ~/.bashrc
. ~/.bashrc
ssh-add -L                                    # cardno:... key
sca security_key openpgp_ssh public_key -o ~/.ssh/id_gpg.pub
```

See [SSH with a YubiKey](../ssh-yubikey-options.md#openpgp-gpg-agent-ssh) for when to choose OpenPGP, and [GPG with a YubiKey](../gpg-yubikey.md#3-keys) to put an authentication key on the card.
