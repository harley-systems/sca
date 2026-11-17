# YubiKey Setup

[← Back to README](../README.md)

Guide for configuring YubiKey hardware security keys for PKI operations.

## Overview

YubiKey provides hardware-based protection for private keys:

- Private keys are generated and stored on the device
- Keys cannot be extracted - signing happens on the YubiKey
- PIN protection prevents unauthorized use
- Physical presence required for operations

## Supported YubiKeys

| Model | PIV Support | Recommended |
|-------|-------------|-------------|
| YubiKey 5 series | Yes | Yes |
| YubiKey 4 series | Yes | Yes |
| YubiKey NEO | Yes | Limited (older) |
| Security Key | No | No |

The PIV (Personal Identity Verification) feature is required for certificate operations.
Security Key series devices can still be used for SSH as FIDO2 keys; see
[SSH with a YubiKey: Choosing a Method](ssh-yubikey-options.md).

## Prerequisites

### Install Required Packages

**Ubuntu/Debian:**
```bash
sudo apt install opensc pcscd yubico-piv-tool yubikey-manager
sudo systemctl enable pcscd
sudo systemctl start pcscd
```

**Or via SCA** (also installs `ykcs11`):
```bash
sca install --yubikey-support
```

On the air-gapped SCA USB stick, use `sca install --air-gapped --yubikey-support` instead.

### Verify YubiKey Detection

```bash
# Using sca (recommended)
sca security_key info

# Or using ykman
ykman info
ykman piv info
```

## Initial Setup

### 1. Initialize YubiKey

First select the entity the YubiKey is for. Init writes the credentials to that entity's files, so it must come after `config set`:

```bash
sca config set subca admin
sca security_key init subca
```

Run `sca create key subca` after init, not before: `create key` uploads the new key with the management key init saves, so for an entity on a YubiKey it stops with a pointer to `sca security_key init <entity>` until init has run.

The `sca security_key init <entity>` command:
- Generates a random management key, PIN (6 digits) and PUK (8 digits). Nothing is prompted for.
- Replaces the factory defaults on the YubiKey with them
- Saves them to the entity's private folder (created if missing), e.g. for a sub-CA:
  ```
  ~/.sca/keys/<ca>/<subca>/private/<prefix>yubikey-pin.txt
  ~/.sca/keys/<ca>/<subca>/private/<prefix>yubikey-puk.txt
  ~/.sca/keys/<ca>/<subca>/private/<prefix>yubikey-key.txt   # management key
  ```

It refuses to run if those files already exist. To replace existing credentials, use `sca security_key init --roll-keys <entity>`; the old files are kept as `*.bak`. Run init in an air-gapped environment.

Init supports `security_key_type` `yubikey` only. For a `pkcs11` token it refuses and changes nothing: set the PIN, PUK and management key with the token's own tools and write them to these files yourself.

**Back up the generated files offline!** You'll need:
- **PIN** - For daily signing operations; SCA reads it from the PIN file
- **PUK** - To unblock the PIN if it gets blocked
- **Management Key** - For administrative operations

### 2. Manual Initialization (Alternative)

If you prefer manual control:

```bash
# Generate random management key
MGMT_KEY=$(openssl rand -hex 24)

# Set management key
yubico-piv-tool -a set-mgm-key -n $MGMT_KEY

# Change PIN (from default 123456)
yubico-piv-tool -a change-pin

# Change PUK (from default 12345678)
yubico-piv-tool -a change-puk
```

SCA does not see values set this way. Save them to the entity's
`<prefix>yubikey-{pin,puk,key}.txt` files listed above yourself, or `sca approve`
and `sca security_key verify` will fail.

## PIV Slots

YubiKey PIV has four standard slots plus 20 retired key slots:

| Slot | Name | Typical Use |
|------|------|-------------|
| 9a | Authentication | SSH, client auth |
| 9c | Digital Signature | Code signing, sub-CA |
| 9d | Key Management | Encryption |
| 9e | Card Authentication | Physical access |
| 82-95 | Retired Key Management | CA keys, key rotation |

For PKI sub-CA, we use slot **9c** (Digital Signature).
For root CA, we typically use slot **82** (Retired Key 1) to keep standard slots available.

View current slot status:
```bash
sca security_key info
```

## Upload Sub-CA to YubiKey

### Using SCA

```bash
# After creating sub-CA certificate
sca security_key upload subca crt
sca security_key upload subca key
```

### Manual Upload

```bash
# Import private key to slot 9c
yubico-piv-tool -a import-key -s 9c \
  -i ~/.sca/keys/sb/harley/harley-subca-key.pem

# Import certificate to slot 9c
yubico-piv-tool -a import-certificate -s 9c \
  -i ~/.sca/keys/sb/harley/harley-subca-crt.pem
```

## Using YubiKey for Signing

### OpenSSL with PKCS#11 ENGINE

The YubiKey appears as a PKCS#11 token. SCA uses the OpenSSL ENGINE API
(`engine_pkcs11.so` from libp11) to access keys stored on the YubiKey:

```bash
# Sign a CSR using YubiKey via PKCS#11 engine
openssl x509 -req -in service.csr \
  -engine pkcs11 -keyform engine \
  -keyfile "pkcs11:id=%02;type=private" \
  -out service.crt
```

The PKCS#11 engine is configured via the `[engine_section]` in the OpenSSL
configuration file generated by `sca config create`.

### SCA Handles This Automatically

When you run `sca approve service`, it:
1. Detects the YubiKey
2. Uses the PKCS#11 engine with PIN from file
3. Prompts for touch (if touch policy is set)
4. Signs the CSR

## View YubiKey Certificates

```bash
# View all slots and certificates (recommended)
sca security_key info

# Display certificate details directly from YubiKey
sca display crt --from-security-key subca
sca display crt --from-security-key ca

# Extract certificate to disk
sca security_key get_crt subca

# Using yubico-piv-tool (low-level)
yubico-piv-tool -a read-certificate -s 9c
```

## Verify Private Key Presence

To confirm a private key is present and working on the YubiKey:

```bash
sca security_key verify subca
sca security_key verify ca
```

This performs a test signing operation to verify the key is functional.
Note: Tools like `ykman piv info` may incorrectly report "Private key: Not present"
even when keys exist - use `sca security_key verify` for reliable detection.

`verify` loads the YubiKey PKCS#11 module from the `ykcs11_module` setting in
`~/.sca/config/sca.config`. `sca config create` sets its default to the
libykcs11 found on this host, or to `/usr/lib/<triplet>/libykcs11.so` for this
host's architecture (see [Library Paths](configuration.md#library-paths)).
If that file is missing, `verify` searches the same folders: `/usr/lib/<triplet>`,
`/usr/lib64`, `/usr/lib`, `/usr/local/lib`, Homebrew and Nix profiles.
If your libykcs11 is somewhere else, set `ykcs11_module` to its full path.
Run with `-d` to see which module was used.

## PIN Management

> **Warning:** SCA reads the PIN from the entity's PIN file
> (`<prefix>yubikey-pin.txt`, see [Initialize YubiKey](#1-initialize-yubikey)).
> Changing or unblocking the PIN with `yubico-piv-tool` or `ykman` does not update
> that file. Afterwards `sca approve` and `sca security_key verify` present the old
> PIN, fail, and use up PIN retries until the PIN is blocked. Prefer
> `sca security_key init --roll-keys <entity>`; if you do change the PIN by hand,
> write the new PIN into the PIN file straight away (no trailing newline:
> `printf '%s' <new-pin> > <pin-file>`).

### Change PIN

```bash
yubico-piv-tool -a change-pin
# or
ykman piv access change-pin
```

### Unblock PIN (using PUK)

After 3 wrong PIN attempts, the PIN is blocked. `sca` unblocks it with the PUK
stored by `sca security_key init`, and writes the new PIN to the PIN file:

```bash
sca security_key unblock_pin subca             # sets a new random PIN
sca security_key unblock_pin --keep-pin subca  # sets the PIN in the PIN file again
```

The PUK is tried once. If it is refused, the command stops, leaves the PIN file
as it was and says how many PUK retries remain (`ykman piv info` shows them
too). After 3 wrong PUK attempts the PUK is blocked as well, and only a reset
of the PIV application is left (below).

### Reset PIV (Emergency)

**WARNING:** This destroys all keys and certificates!

```bash
yubico-piv-tool -a reset
```

## Multiple YubiKeys

For backup or multiple administrators:

### Identify Keys

```bash
# Get serial number
sca security_key id
# or
ykman info | grep Serial
```

### Wait for Specific Key

```bash
# Wait for the sub-CA's key, or a specific one by serial
sca security_key wait_for subca
sca security_key wait_for --device 12345678 subca

# In scripts: stdin is not a terminal, so it gives up after 10 s by default.
# Set the limit with --timeout (or security_key_wait_timeout); 0 waits forever.
sca security_key wait_for --timeout 30 subca
```

## Challenge-response

A YubiKey's OTP application can answer an HMAC-SHA1 challenge with a secret it keeps. [KeePassXC](https://keepassxc.org/docs/) uses it to unlock a database, [pam_yubico](https://developers.yubico.com/yubico-pam/Authentication_Using_Challenge-Response.html) for local login, and some disk unlock scripts use it too. This has nothing to do with PIV or the sca configuration.

By convention challenge-response goes in **slot 2**: slot 1 holds Yubico OTP from the factory (the code a short touch types). `sca security_key otp_chalresp` programs slot 2 only.

```bash
# program a new random secret into slot 2, and keep it in a file
sca security_key otp_chalresp setup --device 12345678
# program the same secret into the backup key
sca security_key otp_chalresp backup --device 87654321 \
  --secret-file ~/.sca/private/yubikey-12345678-chalresp.txt
# both keys must give the same response
sca security_key otp_chalresp test --device 12345678
sca security_key otp_chalresp test --device 87654321
```

- **Touch:** no touch is required by default. `--touch` requires one for every response, so malware on the computer can't query the key unnoticed. Pass the same choice to `backup` as to `setup`.
- **Backup:** program a second key before relying on the first. The secret can't be read back from a key, so `setup` writes it to `~/.sca/private/yubikey-<serial>-chalresp.txt` (mode 600). Run `backup` with it, then delete the file or move it to the air-gapped stick. Without a backup key, losing the key means losing whatever it unlocks.
- **Replacing:** `setup` and `backup` refuse a slot 2 that is already programmed. `-f` replaces it, and the old secret is gone for good: a database or login that used it stops working.
- The secret is handed to `ykman` on stdin: it never appears on a command line, in `~/.sca/log` or in the output. A slot protected by an OTP access code is not supported.

## Troubleshooting

### YubiKey Not Detected

```bash
# Check pcscd is running
sudo systemctl status pcscd

# Restart pcscd
sudo systemctl restart pcscd

# Check USB device
lsusb | grep Yubico
```

### Wrong PIN Entered

After 3 failures, PIN is locked. Unblock it with the stored PUK; see
[Unblock PIN](#unblock-pin-using-puk):

```bash
sca security_key unblock_pin subca
```

### PKCS#11 Module Not Found

Find the correct path:

```bash
find /usr -name "opensc-pkcs11.so" 2>/dev/null
```

Common locations:
- `/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so` (Debian/Ubuntu)
- `/usr/lib64/opensc-pkcs11.so` (RHEL/CentOS)

### Permission Denied

Add user to required groups:

```bash
sudo usermod -aG plugdev $USER
# Log out and back in
```

## Security Best Practices

1. **Use strong PIN** - At least 6 digits, avoid patterns
2. **Store PUK securely** - Different location than YubiKey
3. **Store management key offline** - Only needed for administrative tasks
4. **Enable touch policy** - Require physical touch for each operation
5. **Keep backup YubiKey** - In case of loss or failure

### Enable Touch Policy

Require physical touch for signing:

```bash
yubico-piv-tool -a set-touch-policy -s 9c -T cached
```

Touch policies:
- `never` - No touch required
- `always` - Touch for every operation
- `cached` - Touch once, cached for 15 seconds

To test with a touch policy without someone at the desk, the [YubiKey touch fixture](../tools/yubikey-touch/README.md)
touches a test key on command. Never use it with a key that protects anything real.

## References

- [Yubico PIV Introduction](https://developers.yubico.com/yubico-piv-tool/YubiKey_PIV_introduction.html)
- [PIV Certificate Authority Guide](https://developers.yubico.com/PIV/Guides/Certificate_authority.html)
- [YubiKey Manager Documentation](https://docs.yubico.com/software/yubikey/tools/ykman/)

---

## See Also

- [Command Reference](commands.md) - Command reference
- [Procedures](procedures.md) - Step-by-step guides
- [SSH Integration](ssh-integration.md) - Use YubiKey for SSH
- [SSH with a YubiKey: Choosing a Method](ssh-yubikey-options.md) - PIV vs OpenPGP vs FIDO2 for SSH
- [GPG with a YubiKey](gpg-yubikey.md) - Signing, encryption and Git commit signing with the OpenPGP applet
- [YubiKey touch fixture](../tools/yubikey-touch/README.md) - Touch test keys on command, for unattended tests
