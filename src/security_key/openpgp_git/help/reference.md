**What it does:**
- `setup`: reads the signature key's fingerprint from `gpg --card-status --with-colons` and checks with `gpg --list-keys` that its public key is in the keyring
- `setup` then sets `user.signingkey <fingerprint>!`, `commit.gpgsign true` and `tag.gpgSign true` (not with `--no-tags`) with `git config --global`, which honours `GIT_CONFIG_GLOBAL`, or with `git config --local` given `--local`. Only that scope is read and written, and `gpg.program` is never set
- Settings already right are left alone (`yes`, `on` and `1` count as true; the key is compared ignoring case). If any setting has another value, or `gpg.format` is set to something other than `openpgp` (e.g. SSH signing), `setup` lists them all with the `git config` command that accepts each, writes nothing and exits 1. `-n`, `--dry-run` prints what would change and changes nothing
- `setup` warns when `user.email` is not a user ID of the key (the Git host would show commits as Unverified), prints the `export GPG_TTY="$(tty)"` line for the shell startup file, and edits no shell files
- `public_key`: runs `gpg --armor --export <fingerprint>`, the primary key with all its subkeys. `-o FILE` writes it to FILE instead of stdout, and never overwrites an existing file
- Neither mode needs `sca config`, and gpg runs with `--batch`, so sca never asks for or sees the OpenPGP PIN

**Example:**
```bash
sca install --openpgp                         # gnupg, scdaemon, ykman
sca security_key openpgp_git setup --dry-run
sca security_key openpgp_git setup
echo 'export GPG_TTY="$(tty)"' >> ~/.bashrc
sca security_key openpgp_git public_key -o ~/gpg-signing.asc   # for GitHub or GitLab
git commit --allow-empty -m test && git log --show-signature -1
```

See [GPG with a YubiKey](../gpg-yubikey.md#54-git-commit-and-tag-signing) for the manual steps, and [section 3](../gpg-yubikey.md#3-keys) to put a signature key on the card.
