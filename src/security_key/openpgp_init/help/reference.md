**What it does:**
- Picks the YubiKey with `ykman list --serials` (`--device SERIAL` when more than one is attached), and checks that gpg's current OpenPGP card has that serial, switching to it if it can; otherwise it refuses, so the PINs of another key are never touched
- Asks for every PIN first (each new one twice), or reads it from the `--*-file` options, and checks them before touching the card: user PIN 6 to 127 characters, admin PIN and reset code 8 to 127, a single line, the user PIN not `123456`, the new admin PIN not the current one, and the user and admin PINs different
- Without `--roll`: `ykman openpgp access set-retries N N N` (N is 5, or `--retries N`), first, because on firmware before 4.0 it puts the PINs back to their defaults. It also tells whether the admin PIN is still `12345678`: if the card rejects it, nothing is changed, and one admin PIN try is spent
- Then, with `gpg --change-pin` under `--pinentry-mode loopback`, the PINs on its stdin: the user PIN (set with the admin PIN, so `--roll` doesn't need the current user PIN), the reset code (with `--reset-code` or `--reset-code-file`), and the admin PIN, last
- With `--roll`, the current admin PIN is asked for (or read from `--current-admin-pin-file`) and the retry counters are left alone; set them by hand with `ykman openpgp access set-retries`, which asks for the admin PIN
- With the admin PIN retry counter at 1 or 0, nothing is tried
- Prints the retry counters read back from the card. sca stores no PIN: write the admin PIN and reset code down

**Example:**
```bash
sca install --openpgp                          # gnupg, scdaemon, ykman
sca security_key openpgp_init --reset-code     # asks for the new PINs
gpg --card-status                              # "PIN retry counter : 5 5 5"
sca security_key openpgp_init --roll           # change them again later
```

Unattended, with the PINs in files:
```bash
sca security_key openpgp_init --device 12345678 --retries 5 \
  --user-pin-file user.pin --admin-pin-file admin.pin --reset-code-file reset.pin
```

See [GPG with a YubiKey](../gpg-yubikey.md#2-set-up-the-card) for the manual steps.
