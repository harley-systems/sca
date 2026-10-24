# SSH with a YubiKey: Choosing a Method

[← Back to README](../README.md)

A YubiKey can hold an SSH key in three different ways. SCA implements only the
first one (PIV); this page explains all three so you can pick the right one.

| Method | YubiKey applet | Agent | Covered by SCA |
|--------|----------------|-------|----------------|
| **PIV via PKCS#11** | PIV | `ssh-agent` with `ykcs11`/OpenSC | Yes, see [SSH Integration](ssh-integration.md) |
| **OpenPGP authentication subkey** | OpenPGP | `gpg-agent` | No, manual steps below |
| **FIDO2 security key (`-sk`)** | FIDO2 / U2F | `ssh-agent` (OpenSSH built in) | No, manual steps below |

> **Testing status.** The commands on this page were checked against the
> OpenSSH, GnuPG and `ykman` documentation. They have **not yet been run on
> hardware** for this page. See [Tested on](#tested-on) at the bottom.

## Choosing a Method

### Comparison

| | PIV (PKCS#11) | OpenPGP (gpg-agent) | FIDO2 (`ed25519-sk` / `ecdsa-sk`) |
|---|---|---|---|
| **YubiKey models** | YubiKey 4, 5 (incl. FIPS), NEO. **Not** the Security Key series | YubiKey 4, 5 (incl. FIPS), NEO. **Not** the Security Key series | `ecdsa-sk`: any FIDO U2F/FIDO2 key, including the Security Key series. `ed25519-sk`: firmware 5.2.3+. Resident keys need FIDO2 (YubiKey 5 or Security Key series) |
| **Key algorithms on the device** | RSA 2048, ECC P-256/P-384 (more on firmware 5.7+) | RSA 2048/4096; ed25519/cv25519 on firmware 5.2.3+ | ECDSA P-256, Ed25519 |
| **Private key stays on device** | Yes | Yes (if generated on card; `keytocard` moves it and removes the local copy on `save`) | Yes |
| **Portable to a new machine** | Yes: the public key is read from the card | Yes, but the new machine needs your OpenPGP public key imported and `gpg --card-status` run once | Resident: yes, `ssh-keygen -K`. Non-resident: no, you must copy the key-handle file (`id_*_sk`) |
| **PIN** | PIV PIN, asked by `ssh-add -s` or `ssh` and cached by the agent | OpenPGP user PIN, asked by `pinentry` and cached by `scdaemon` | FIDO2 PIN only with `-O verify-required` (and when creating or downloading resident keys) |
| **Touch** | Set by the slot's touch policy when the key is generated (`never`/`always`/`cached`) | Optional: `ykman openpgp keys set-touch aut on` | Required on every use by default (`-O no-touch-required` turns it off and the server has to allow it) |
| **OpenSSH certificates (SSH CA)** | Yes, with `CertificateFile` in `~/.ssh/config` | Not supported by gpg-agent's ssh-agent emulation, so plan on plain `authorized_keys` | Yes: `-sk` public keys can be signed with `ssh-keygen -s` |
| **Server requirements** | None beyond OpenSSH; RSA keys need `rsa-sha2-*` (any OpenSSH from the last decade) | None beyond OpenSSH | OpenSSH **≥ 8.2** on the server (`verify-required` needs ≥ 8.4). Many appliances and older distributions reject `sk-*` key types |
| **Client OS / agent** | Linux, macOS (Homebrew OpenSC or `ykcs11`), Windows (OpenSC); stock `ssh-agent` | Linux, macOS (GnuPG + `pinentry-mac`), Windows (Gpg4win); `gpg-agent` replaces `ssh-agent` | Linux with OpenSSH ≥ 8.2 and libfido2; macOS needs Homebrew OpenSSH (Apple's build has no security-key support); Windows OpenSSH 8.9+ |
| **Backup / recovery** | Generated on device: none, enrol a second YubiKey. Imported key: restore the backup to a new card | Keep the master key offline (e.g. on an air-gapped machine) and `keytocard` again to a replacement; or enrol a second card | None: enrol a second YubiKey and add both public keys. Resident keys are lost if the FIDO applet is reset |
| **Also useful for** | X.509 client certs, SCA signing | Git commit signing, email encryption | Git commit signing (`gpg.format ssh`), WebAuthn |

### Recommendation

| Use case | Recommendation | Why |
|----------|----------------|-----|
| **One developer laptop** | **FIDO2, non-resident `ed25519-sk`** (or `ecdsa-sk` on older firmware) with a second YubiKey enrolled as backup. If you already sign Git commits with GPG, the **OpenPGP** subkey is fine too | Simplest setup: no extra daemons or PKCS#11 modules, and touch is required by default |
| **Several machines** | **FIDO2 resident `ed25519-sk`** with `-O verify-required`, recovered with `ssh-keygen -K` on each machine. Fall back to **PIV** if a server runs OpenSSH older than 8.2 | The key comes with the YubiKey, and nothing has to be copied between machines |
| **Organisation with an SSH CA** | **PIV** if users already have a YubiKey set up with SCA, otherwise **FIDO2**. Do **not** use OpenPGP | Both PIV and `-sk` keys work with OpenSSH certificates; gpg-agent does not. **Not yet automated:** SCA does not sign OpenSSH certificates today (see [below](#openssh-certificates-not-yet-automated)) |
| **Security Key series (FIDO-only) device** | **FIDO2** | It is the only applet these devices have |

## Packages

| Path | Ubuntu/Debian | Fedora | macOS (Homebrew) |
|------|---------------|--------|------------------|
| All | `yubikey-manager` | `yubikey-manager` | `brew install ykman` |
| PIV | `pcscd opensc` (or `ykcs11`) | `pcsc-lite opensc` | `brew install opensc` (or `yubico-piv-tool` for `libykcs11`) |
| OpenPGP | `gnupg scdaemon` (+ `pcscd` if you use `disable-ccid`) | `gnupg2 pcsc-lite` | `brew install gnupg pinentry-mac` |
| FIDO2 | `openssh-client` ≥ 8.2 and `libfido2-1` | `openssh-clients libfido2` | `brew install openssh` |

`sca install` installs the PIV packages only. Installing the OpenPGP or FIDO2
packages is **not yet automated**.

## OpenPGP (gpg-agent) SSH

### 1. Put an authentication key on the card

Either generate the keys directly on the card (they can't be backed up):

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> generate
```

Or create an authentication subkey on your computer, back up the master key,
and move the subkey to the card:

```bash
# Add an authentication-only subkey (choose "ECC (set your own capabilities)",
# toggle it to Authenticate only, then Curve 25519)
gpg --expert --edit-key <KEYID>
# gpg> addkey
# gpg> save

# Move it to the card
gpg --edit-key <KEYID>
# gpg> key <N>          # select the [A] subkey
# gpg> keytocard        # choose (3) Authentication key
# gpg> save
```

Ed25519 on the card needs firmware 5.2.3 or later; use RSA on older keys.
`keytocard` followed by `save` deletes the local copy of the subkey, so back up
first (`gpg --export-secret-keys --armor <KEYID>`).

Check the result:

```bash
gpg --card-status     # "Authentication key" should be filled in
```

### 2. Require touch (optional)

```bash
ykman openpgp keys set-touch aut on
```

Policies are `off`, `on`, `fixed` (can't be changed without resetting the
OpenPGP applet), `cached` and `cached-fixed`.

### 3. Enable SSH support in gpg-agent

```bash
echo enable-ssh-support >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

Add to `~/.bashrc` (instead of starting `ssh-agent`):

```bash
export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
gpgconf --launch gpg-agent
```

Keys on the card are offered automatically; you don't need to add them to
`~/.gnupg/sshcontrol`.

```bash
ssh-add -L            # should list "cardno:..."
```

### 4. Get the public key

```bash
gpg --export-ssh-key <KEYID> > ~/.ssh/id_gpg.pub
```

Add the output to the server's `~/.ssh/authorized_keys`.

### Troubleshooting

**`gpg --card-status` says "No such device" or the card stops working after
using PIV tools.** `scdaemon` talks to the YubiKey directly over CCID by
default, while `ykman`, OpenSC and `ykcs11` use `pcscd`. Both can't own the
device at once. Tell `scdaemon` to go through `pcscd` instead:

```bash
cat >> ~/.gnupg/scdaemon.conf <<'EOF'
disable-ccid
pcsc-shared
EOF
gpgconf --kill scdaemon
```

`pcsc-shared` is only accepted by newer GnuPG releases; check `man scdaemon`
and leave it out if your version doesn't list it. If the card is still busy,
`gpgconf --kill scdaemon` releases it so other tools can use it.

**The PIN prompt appears in another terminal, or `ssh` fails with "agent
refused operation".** gpg-agent shows `pinentry` on the terminal it was started
from. Point it at the current one:

```bash
gpg-connect-agent updatestartuptty /bye
```

To do this automatically, add to `~/.ssh/config`:

```
Match host * exec "gpg-connect-agent updatestartuptty /bye"
```

## FIDO2 SSH (`-sk` keys)

### 1. Set a FIDO2 PIN

Required for resident keys and `verify-required`. If no PIN is set yet, this
sets one; otherwise it changes it:

```bash
ykman fido access change-pin
ykman fido info       # shows whether a PIN is set
```

The FIDO2 PIN is separate from the PIV and OpenPGP PINs.

### 2. Generate the key

```bash
# Non-resident: the private key file is a handle that only works with this YubiKey
ssh-keygen -t ed25519-sk -C "you@laptop"

# Resident: stored on the YubiKey, recoverable on any machine
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "you@yubikey"
```

- Use `-t ecdsa-sk` on firmware older than 5.2.3 or on U2F-only keys.
- `-O verify-required` asks for the FIDO2 PIN on every use, as well as touch.
  The server needs OpenSSH 8.4+ to enforce it.
- `-O application=ssh:<name>` keeps several resident keys apart on one device.

Add `~/.ssh/id_ed25519_sk.pub` to the server's `~/.ssh/authorized_keys`.

### 3. Use the key on a new machine (resident keys)

```bash
cd ~/.ssh
ssh-keygen -K         # writes id_ed25519_sk_rk (+ .pub) to the current directory
# or load them straight into the agent without writing files:
ssh-add -K
```

`ykman fido credentials list` shows the resident keys stored on the device.

## OpenSSH Certificates (Not Yet Automated)

The SCA "approve" workflow issues X.509 certificates. It does **not** issue
OpenSSH certificates (`ssh-keygen -s`), for any of the three methods. An
organisation that wants an SSH CA signs keys by hand today, for example:

```bash
# CA key in a file
ssh-keygen -s ssh_ca_key -I alice -n alice -V +52w id_ed25519_sk.pub

# CA key on a YubiKey (PIV), via PKCS#11
ssh-keygen -s ssh_ca.pub -D /usr/lib/x86_64-linux-gnu/libykcs11.so \
  -I alice -n alice -V +52w id_ed25519_sk.pub
```

This writes `id_ed25519_sk-cert.pub` next to the public key. `ssh` picks it up
automatically for file-based keys. For PIV keys in the agent, point at it with
`CertificateFile ~/.ssh/<name>-cert.pub` in `~/.ssh/config`.

Signing `-sk` and PIV SSH keys with an SCA-managed SSH CA is **not yet
automated**.

## Tested On

| Method | YubiKey model / firmware | OS | OpenSSH / GnuPG / ykman | Tested by |
|--------|--------------------------|----|-------------------------|-----------|
| PIV | _to be filled in_ | | | |
| OpenPGP | _to be filled in_ | | | |
| FIDO2 | _to be filled in_ | | | |

## References

- [OpenSSH 8.2 release notes (FIDO/U2F support)](https://www.openssh.com/txt/release-8.2)
- [`ssh-keygen(1)`](https://man.openbsd.org/ssh-keygen): `-t ed25519-sk`, `-O resident`, `-O verify-required`, `-K`, `-s`, `-D`
- [Yubico: Securing SSH with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html)
- [Yubico: Using PGP for SSH authentication](https://developers.yubico.com/PGP/SSH_authentication/)
- [`ykman` documentation](https://docs.yubico.com/software/yubikey/tools/ykman/)
- [GnuPG: Agent options (`enable-ssh-support`)](https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html)
- [GnuPG: Scdaemon options (`disable-ccid`, `pcsc-shared`)](https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html)

---

## See Also

- [SSH Integration](ssh-integration.md) - PIV-based SSH with SCA
- [YubiKey Setup](yubikey.md) - PIV setup for SCA
