**What it does:**
- `create`: runs `ssh-keygen -t ed25519-sk` (firmware 5.2.3+) or `-t ecdsa-sk` with `-O application=ssh:sca -O resident -O verify-required`, then prints the public key and what to do with it
- `--non-resident` and `--no-verify` drop `-O resident` and `-O verify-required`; `--application NAME` sets `-O application=ssh:NAME`
- The key goes to `~/.ssh/id_<type>_rk_<NAME>` (resident) or `~/.ssh/id_<type>` (non-resident). If the file or its `.pub` exists, `create` stops before ssh-keygen runs
- `restore`: runs `ssh-keygen -K` and moves the keys to `--output-dir` (default `~/.ssh`); existing files are kept, and it then exits non-zero
- Checks first: OpenSSH 8.2+ (8.3+ for verify-required), exactly one YubiKey plugged in, and a FIDO2 PIN set when one is needed. sca never sets or stores the FIDO2 PIN: set it with `ykman fido access change-pin`
- `--device` is not supported: ssh-keygen can not choose between keys, so leave only one plugged in

**Example:**
```bash
ykman fido access change-pin           # once, if no FIDO2 PIN is set yet
sca security_key fido2_ssh create      # ~/.ssh/id_ed25519_sk_rk_sca
# on another machine:
sca security_key fido2_ssh restore     # ~/.ssh/id_ed25519_sk_rk_sca
ssh -i ~/.ssh/id_ed25519_sk_rk_sca user@server
```

See [SSH with a YubiKey](../ssh-yubikey-options.md#fido2-ssh--sk-keys) for when to choose FIDO2.
