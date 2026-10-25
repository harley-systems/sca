# GPG with a YubiKey: Signing, Encryption and Commit Signing

[← Back to README](../README.md)

A YubiKey's OpenPGP applet can hold three GnuPG subkeys: one for signing, one
for encryption and one for authentication (SSH). This page takes you through
one complete path: set up the card, keep the master key offline, move the
subkeys to the card, and use it every day for files and Git. It also covers a
backup YubiKey and what to do when something goes wrong.

SCA does not automate any of this. SCA uses the **PIV** applet; OpenPGP is a
separate applet on the same YubiKey, with its own keys and PINs. Using one does
not change the other.

> **Testing status.** The commands on this page were checked against the
> GnuPG and `ykman` documentation. They have **not yet been run on hardware**
> for this page. See [Tested on](#tested-on) at the bottom.

**Contents**

1. [Install](#1-install)
2. [Set up the card](#2-set-up-the-card)
3. [Keys](#3-keys)
4. [Touch policies](#4-touch-policies)
5. [Daily use](#5-daily-use)
6. [Backup YubiKey](#6-backup-yubikey)
7. [Recovery](#7-recovery)
8. [Coexistence with PIV and SCA](#8-coexistence-with-piv-and-sca)

## 1. Install

| Ubuntu/Debian | Fedora | macOS (Homebrew) |
|---------------|--------|------------------|
| `sudo apt install gnupg scdaemon yubikey-manager` | `sudo dnf install gnupg2 pcsc-lite yubikey-manager` | `brew install gnupg pinentry-mac ykman` |

`sca install` installs the PIV packages only. Installing the OpenPGP packages
is **not yet automated**.

On macOS, tell `gpg-agent` to use the graphical PIN prompt:

```bash
echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

The `ykman` commands on this page use the **ykman 5.x** syntax
(`ykman openpgp access ...`, `ykman openpgp keys ...`). Older releases, such as
the one in Ubuntu 18.04, use different subcommand names; check
`ykman --version` and `ykman openpgp --help`.

Check that GnuPG can see the card:

```bash
ykman info            # model and firmware version
gpg --card-status     # "Reader", "Application ID", "Version", ...
```

If `gpg --card-status` fails while `ykman` works, see
[Coexistence with PIV and SCA](#8-coexistence-with-piv-and-sca).

## 2. Set up the card

The OpenPGP applet has three secrets. They are separate from the PIV PIN, PUK
and management key that SCA uses.

| Secret | Default | Used for |
|--------|---------|----------|
| **User PIN** | `123456` | Every signature, decryption and authentication |
| **Admin PIN** | `12345678` | Changing card settings, loading keys, touch policies, unblocking the user PIN |
| **Reset code** | not set | Unblocking the user PIN *without* the admin PIN (optional) |

Each has a retry counter (3 by default). When the user PIN counter reaches 0
the user PIN is blocked; when the admin PIN counter reaches 0 the only way out
is to [reset the applet](#reset-the-openpgp-applet).

### Retries

Set the retry counters **first**: on firmware before 4.0, changing them puts
all three PINs back to their defaults (ykman warns about this). The order of the arguments is user PIN,
reset code, admin PIN:

```bash
ykman openpgp access set-retries 5 5 5     # asks for the admin PIN
```

### PINs

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> passwd
#   1 - change PIN            (user PIN, at least 6 characters)
#   3 - change Admin PIN      (at least 8 characters)
#   4 - set the Reset Code    (optional, at least 8 characters)
#   Q - quit
# gpg/card> quit
```

`ykman openpgp access change-pin`, `change-admin-pin` and `change-reset-code`
do the same thing. Write the admin PIN and reset code down and keep them with
your offline backup.

### Key algorithm

Ed25519 (signing, authentication) and Cv25519 (encryption) need firmware
**5.2.3** or later (`ykman info` shows the version). On older YubiKeys use RSA
(2048, or 4096 on YubiKey 4 and 5).

Recent GnuPG releases change the card's key attributes for you during
`keytocard`. To set them yourself (for example before generating keys on the
card):

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> key-attr       # choose (2) ECC, then (1) Curve 25519, for each of the three keys
```

### Optional card details

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> name           # cardholder name
# gpg/card> url            # where your public key can be downloaded, used by "fetch" (see 5.1)
```

## 3. Keys

There are two ways to get keys onto the card.

| | Generate on the card | Offline master key, then `keytocard` (**recommended**) |
|---|---|---|
| **Backup** | None. The private keys can never leave the card | The master key and subkeys are backed up offline |
| **Lost or broken card** | All signatures and encrypted files tied to those keys are lost; start again with a new identity | Load the same subkeys onto a new card, or revoke and replace them |
| **Second YubiKey** | Not possible with the same keys | Same subkeys on both cards ([section 6](#6-backup-yubikey)) |
| **Effort** | A few minutes | Needs an offline machine |

### Option A: generate on the card

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> generate       # answer "n" to "Make off-card backup of encryption key?"
```

This creates a master key with the signing, encryption and authentication keys
on the card. Skip to [Touch policies](#4-touch-policies).

### Option B: offline master key (recommended)

Do this on a machine that is not connected to a network, ideally the SCA
air-gapped USB stick (see
[Creating the SCA USB Stick](air-gapped-operations.md#creating-the-sca-usb-stick)
and [Using the Air-Gapped Environment](air-gapped-operations.md#using-the-air-gapped-environment)).
The stick runs from RAM, so nothing is left behind after shutdown unless you
copy it to a USB drive. Check that `gpg --card-status` works there; if
`scdaemon` is missing, copy its package to the stick with your other offline
packages.

#### 3.1 Create the master key

The master key only certifies (signs other keys and your own subkeys). It never
goes on the card.

```bash
export GNUPGHOME="$(mktemp -d)"

gpg --quick-generate-key "Alice Example <alice@example.com>" ed25519 cert never
```

Note the fingerprint it prints (40 hex characters) and use it for `<FPR>`
below. `gpg --list-keys` shows it again.

#### 3.2 Add the subkeys

```bash
gpg --quick-add-key <FPR> ed25519 sign 2y     # [S] signing
gpg --quick-add-key <FPR> cv25519 encr 2y     # [E] encryption
gpg --quick-add-key <FPR> ed25519 auth 2y     # [A] authentication (SSH)
```

Use `rsa4096` (or `rsa2048`) in place of `ed25519`/`cv25519` on firmware
before 5.2.3. An expiry date on the subkeys (here 2 years) means a lost key
stops being valid by itself; you can extend it from the master key at any time
(see [Rotate or extend subkeys](#rotate-or-extend-subkeys)).

```bash
gpg --list-secret-keys --keyid-format long
# sec   ed25519/... [C]
# ssb   ed25519/... [S]
# ssb   cv25519/... [E]
# ssb   ed25519/... [A]
```

#### 3.3 Back up

Do this **before** `keytocard`. After `save`, the subkeys are no longer on
disk.

```bash
gpg --armor --export-secret-keys <FPR>    > master-and-subkeys.asc
gpg --armor --export-secret-subkeys <FPR> > subkeys.asc
gpg --armor --export <FPR>                > public.asc
cp "$GNUPGHOME/openpgp-revocs.d/<FPR>.rev" revoke.asc
```

GnuPG creates the revocation certificate (`openpgp-revocs.d/<FPR>.rev`) when
the master key is made. Copy these files, together with the admin PIN and reset
code, to an encrypted USB drive (or two) that stays offline. Only `public.asc`
leaves the offline machine.

Keep a copy of the whole `$GNUPGHOME` too: you will need it to load a backup
YubiKey, rotate subkeys or extend expiry dates.

#### 3.4 Move the subkeys to the card

```bash
gpg --edit-key <FPR>
# gpg> key 1          # select the [S] subkey (marked with *)
# gpg> keytocard      # choose (1) Signature key
# gpg> key 1          # deselect it
# gpg> key 2          # select the [E] subkey
# gpg> keytocard      # choose (2) Encryption key
# gpg> key 2
# gpg> key 3          # select the [A] subkey
# gpg> keytocard      # choose (3) Authentication key
# gpg> save
```

`keytocard` asks for the passphrase of the key and then the **admin PIN**.

**What `save` deletes.** `keytocard` writes the subkey to the card straight
away. `save` then replaces each moved subkey in your local keyring with a
*stub*: a pointer saying "this key is on the card with serial number N". The
secret subkey material is gone from `$GNUPGHOME`; the master key is not
touched. If you `quit` without saving instead, the keys are on the card *and*
still on disk. That is how the [backup YubiKey](#6-backup-yubikey) is loaded.

Check the result:

```bash
gpg --card-status
# Signature key ....: <fingerprint>
# Encryption key....: <fingerprint>
# Authentication key: <fingerprint>

gpg --list-secret-keys
# ssb>  ed25519 ...    (the ">" means the key is on a card)
```

Shut down the offline machine, or remove `$GNUPGHOME` if you made it on a
normal one, once the backup is stored.

## 4. Touch policies

With a touch policy set, the YubiKey only signs, decrypts or authenticates
after you touch it, so malware that knows your PIN still can't use the key
without you noticing.

```bash
ykman openpgp keys set-touch sig on     # asks for the admin PIN
ykman openpgp keys set-touch dec on     # the encryption key is called dec
ykman openpgp keys set-touch aut on
ykman openpgp info                      # shows the touch policy of each key
```

| Policy | Meaning |
|--------|---------|
| `off` | No touch needed (default) |
| `on` | Touch for every operation |
| `fixed` | Like `on`, but can't be turned off again without [resetting the OpenPGP applet](#reset-the-openpgp-applet), which deletes the keys on the card |
| `cached` | Touch once, then no touch needed for 15 seconds |
| `cached-fixed` | `cached`, and can't be changed without a reset |

`fixed` protects against someone who learns your admin PIN and switches touch
off. The price is that changing your mind means resetting the applet and
loading the keys again.

`cached` is handy for `dec` (the encryption key) if you decrypt many files at once, and for `sig`
during a `git rebase` that re-signs many commits.

## 5. Daily use

### 5.1 Set up a new machine

The card holds the private keys, but GnuPG on each machine also needs your
public key and the stubs that point at the card.

```bash
gpg --import public.asc      # or: gpg --card-edit, then "fetch" if you set "url"
gpg --card-status            # creates the stubs for the keys on the card
```

Tell GnuPG that it is your own key:

```bash
gpg --edit-key <FPR>
# gpg> trust          # choose 5 (ultimate)
# gpg> quit
```

### 5.2 Sign and verify files

```bash
gpg --armor --detach-sign report.pdf       # writes report.pdf.asc
gpg --verify report.pdf.asc report.pdf
```

### 5.3 Encrypt and decrypt files

```bash
gpg --encrypt --recipient alice@example.com secrets.txt     # writes secrets.txt.gpg
gpg --encrypt --sign --recipient bob@example.com secrets.txt   # encrypt to Bob and sign
gpg --output secrets.txt --decrypt secrets.txt.gpg          # needs the card
```

Add `--recipient` once per person, and include yourself if you want to be able
to read the file later.

### 5.4 Git commit and tag signing

```bash
gpg --list-secret-keys --keyid-format long     # find the ID of the [S] subkey

git config --global user.signingkey <SIGNING-SUBKEY-ID>!
git config --global commit.gpgsign true
git config --global tag.gpgSign true
```

The `!` tells GnuPG to use exactly that subkey. You can also give the master
key's fingerprint; GnuPG then picks the newest usable signing subkey. If `git`
can't find `gpg`, set `git config --global gpg.program gpg`.

Check it:

```bash
git commit -m "test"           # asks for the user PIN (and touch, if set)
git log --show-signature -1
git tag -s v1.0 -m "v1.0"
git verify-tag v1.0
```

Add the output of `gpg --armor --export <FPR>` to your account on the Git host
(GitHub: *Settings → SSH and GPG keys*; GitLab: *Preferences → GPG Keys*) so
commits show as verified.

If the PIN prompt does not appear, set `GPG_TTY` in your shell profile:

```bash
export GPG_TTY="$(tty)"
```

### 5.5 SSH

The authentication subkey can also be used for SSH through `gpg-agent`. See
[OpenPGP (gpg-agent) SSH](ssh-yubikey-options.md#openpgp-gpg-agent-ssh); you
can skip its step 1, since the `[A]` subkey is already on the card.

## 6. Backup YubiKey

Loading the same subkeys onto a second YubiKey means either card can sign and
decrypt. Do this on the offline machine, with the copy of `$GNUPGHOME` from
[section 3.3](#33-back-up). Set up the second card's PINs and retries first
([section 2](#2-set-up-the-card)).

```bash
export GNUPGHOME=/path/to/copy/of/gnupghome   # still has the secret subkeys

# Insert the second YubiKey
gpg --edit-key <FPR>
# gpg> key 1
# gpg> keytocard      # (1) Signature key
# gpg> key 1
# gpg> key 2
# gpg> keytocard      # (2) Encryption key
# gpg> key 2
# gpg> key 3
# gpg> keytocard      # (3) Authentication key
# gpg> quit           # do NOT save: keep the subkeys on disk for next time
```

If you already ran `save` on this copy, re-import the backup first:
`gpg --import subkeys.asc` (or `master-and-subkeys.asc`).

**The stub-switching caveat.** Each stub records the serial number of the card
it was made for. When you plug in the other YubiKey, GnuPG asks you to
"insert the card with serial number ..." and fails. Tell it to point the stubs
at the card that is plugged in now:

```bash
gpg-connect-agent "scd serialno" "learn --force" /bye
```

Run it each time you swap cards. If that doesn't help, delete the stubs and let
`gpg --card-status` create them again:

```bash
gpg --with-keygrip --list-secret-keys <FPR>    # note the keygrips of the ssb> lines
rm ~/.gnupg/private-keys-v1.d/<KEYGRIP>.key    # for each of those keygrips
gpg --card-status
```

Only remove keygrips of `ssb>` lines (keys on a card). A keygrip of a key that
is *not* on a card is a real secret key.

## 7. Recovery

### Blocked user PIN

`gpg --card-status` shows the remaining tries under "PIN retry counter" (user
PIN, reset code, admin PIN).

With the **admin PIN**:

```bash
gpg --card-edit
# gpg/card> admin
# gpg/card> passwd
#   2 - unblock PIN       # asks for the admin PIN, then a new user PIN
```

With the **reset code** (no admin PIN needed):

```bash
gpg --card-edit
# gpg/card> unblock       # asks for the reset code, then a new user PIN
```

`ykman openpgp access unblock-pin` does the same with either one.

### Blocked admin PIN

The admin PIN can't be unblocked. [Reset the applet](#reset-the-openpgp-applet)
and load the subkeys again from your offline backup (as in
[section 6](#6-backup-yubikey)). With keys generated on the card (option A),
they are lost.

### Lost or stolen card

The card's PIN protects the keys, but treat them as exposed. On the offline
machine:

1. **Revoke the subkeys** that were on the card:

   ```bash
   gpg --edit-key <FPR>
   # gpg> key 1
   # gpg> key 2
   # gpg> key 3
   # gpg> revkey          # choose a reason, e.g. "Key has been compromised"
   # gpg> save
   ```

2. **Add new subkeys** ([section 3.2](#32-add-the-subkeys)), back them up and
   move them to a new card ([section 3.4](#34-move-the-subkeys-to-the-card)).
3. **Publish the updated public key** (`gpg --armor --export <FPR>`): to your
   Git host, to keyservers or URL you use, and to the people who encrypt to you.
   Old signatures stay valid; files encrypted to the old `[E]` subkey can still
   be decrypted from the backup.

If you have a backup YubiKey with the same subkeys, it holds keys you have
just revoked: load the new subkeys onto it as well.

If the **master key** itself is lost or exposed, publish the revocation
certificate from [section 3.3](#33-back-up) and start again with a new key.
GnuPG puts a `:` in front of the certificate so that it can't be imported by
accident; remove that character first, then:

```bash
gpg --import revoke.asc
gpg --armor --export <FPR>    # publish this
```

### Rotate or extend subkeys

To extend all subkeys by another two years (on the offline machine, with the
master key):

```bash
gpg --quick-set-expire <FPR> 2y '*'
gpg --armor --export <FPR> > public.asc     # publish the updated key
```

The keys on the card don't change, so there is no need to run `keytocard`
again. Import the new `public.asc` on each machine you use.

### Reset the OpenPGP applet

The last resort, when the admin PIN is blocked or the card is in an unknown
state:

```bash
ykman openpgp reset
```

This deletes **all** OpenPGP keys on the card and puts the PINs, reset code,
retries and touch policies back to their defaults. It is the only way to clear
a `fixed` or `cached-fixed` touch policy. It does
**not** touch the PIV applet, so your SCA keys and certificates stay. Do not
confuse it with `ykman piv reset`, which deletes the SCA keys.

## 8. Coexistence with PIV and SCA

SCA and the PIV tools (`ykman`, OpenSC, `ykcs11`) reach the YubiKey through
`pcscd`. GnuPG's `scdaemon` talks to it directly over CCID by default, and only
one of them can hold the device at a time. Symptoms are `gpg --card-status`
saying "No such device", or `sca security_key` commands failing after you used
GnuPG.

The fix (`disable-ccid` and `pcsc-shared` in `~/.gnupg/scdaemon.conf`, or
`gpgconf --kill scdaemon` to release the card) is described in
[OpenPGP Troubleshooting](ssh-yubikey-options.md#troubleshooting).

Other things to keep in mind:

- The OpenPGP PINs and the PIV PIN are separate. Blocking one does not block
  the other.
- `ykman openpgp reset` and `ykman piv reset` each reset only their own applet.
- Touch policies are set separately: `ykman openpgp keys set-touch` for
  OpenPGP, the slot's policy for PIV (see
  [YubiKey Setup](yubikey.md)).

## Tested On

| Step | YubiKey model / firmware | OS | GnuPG / ykman | Tested by |
|------|--------------------------|----|---------------|-----------|
| Card setup (PINs, retries) | _to be filled in_ | | | |
| Offline master key + `keytocard` | _to be filled in_ | | | |
| Touch policies | _to be filled in_ | | | |
| File sign/encrypt, Git signing | _to be filled in_ | | | |
| Backup YubiKey, stub switching | _to be filled in_ | | | |
| Recovery (unblock, revoke, reset) | _to be filled in_ | | | |

None of these steps has been run on hardware yet.

## References

- [GnuPG manual: OpenPGP key management (`--quick-generate-key`, `--quick-add-key`, `--quick-set-expire`, `--edit-key`: `keytocard`, `revkey`, `trust`)](https://www.gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html)
- [GnuPG manual: Scdaemon options](https://www.gnupg.org/documentation/manuals/gnupg/Scdaemon-Options.html)
- [GnuPG: Smartcard HOWTO (`--card-edit`, `passwd`, `unblock`)](https://www.gnupg.org/howtos/card-howto/en/smartcard-howto-single.html)
- [Yubico: Using your YubiKey with OpenPGP](https://support.yubico.com/hc/en-us/articles/360013790259-Using-Your-YubiKey-with-OpenPGP)
- [`ykman openpgp` documentation](https://docs.yubico.com/software/yubikey/tools/ykman/OpenPGP_Commands.html)
- [Git: Signing your work](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)

---

## See Also

- [SSH with a YubiKey: Choosing a Method](ssh-yubikey-options.md) - PIV vs OpenPGP vs FIDO2 for SSH
- [YubiKey Setup](yubikey.md) - PIV setup for SCA
- [Air-Gapped Operations](air-gapped-operations.md) - The offline environment for the master key
