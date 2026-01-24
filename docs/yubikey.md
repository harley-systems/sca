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

## Prerequisites

### Install Required Packages

**Ubuntu/Debian:**
```bash
sudo apt install opensc pcscd yubico-piv-tool yubikey-manager
sudo systemctl enable pcscd
sudo systemctl start pcscd
```

**Or via SCA:**
```bash
sca install prerequisites
```

### Verify YubiKey Detection

```bash
# Check if YubiKey is detected
ykman info

# Check PIV status
ykman piv info
```

## Initial Setup

### 1. Initialize YubiKey

The `sca security_key init` command:
- Generates new management key
- Sets new PIN (user password)
- Sets new PUK (PIN Unblock Key)
- Saves credentials securely

```bash
sca security_key init
```

**Store the generated credentials securely!** You'll need:
- **PIN** - For daily signing operations (default: 123456)
- **PUK** - To reset PIN if locked (default: 12345678)
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

## PIV Slots

YubiKey PIV has four certificate slots:

| Slot | Name | Typical Use |
|------|------|-------------|
| 9a | Authentication | SSH, client auth |
| 9c | Digital Signature | Code signing, sub-CA |
| 9d | Key Management | Encryption |
| 9e | Card Authentication | Physical access |

For PKI sub-CA, we use slot **9c** (Digital Signature).

## Upload Sub-CA to YubiKey

### Using SCA

```bash
# After creating sub-CA certificate
sca security_key upload subca
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

### OpenSSL with PKCS#11

The YubiKey appears as a PKCS#11 token:

```bash
# Sign a CSR using YubiKey
openssl x509 -req -in service.csr \
  -engine pkcs11 -keyform engine \
  -key "pkcs11:object=SIGN%20key" \
  -out service.crt
```

### SCA Handles This Automatically

When you run `sca approve csr service`, it:
1. Detects the YubiKey
2. Uses PKCS#11 engine
3. Prompts for PIN
4. Signs the CSR

## View YubiKey Certificates

```bash
# Using yubico-piv-tool
yubico-piv-tool -a read-certificate -s 9c

# Using pkcs11-tool
pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-objects

# Using sca
sca security_key get_crt subca
```

## PIN Management

### Change PIN

```bash
yubico-piv-tool -a change-pin
# or
ykman piv access change-pin
```

### Unblock PIN (using PUK)

After 3 wrong PIN attempts, the PIN is blocked:

```bash
yubico-piv-tool -a unblock-pin
# Enter PUK, then new PIN
```

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
# Useful in scripts
sca security_key wait_for 12345678
```

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

After 3 failures, PIN is locked. Use PUK to unblock:

```bash
yubico-piv-tool -a unblock-pin
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

## References

- [Yubico PIV Introduction](https://developers.yubico.com/yubico-piv-tool/YubiKey_PIV_introduction.html)
- [PIV Certificate Authority Guide](https://developers.yubico.com/PIV/Guides/Certificate_authority.html)
- [YubiKey Manager Documentation](https://docs.yubico.com/software/yubikey/tools/ykman/)

---

## See Also

- [Command Reference](commands.md) - Command reference
- [Procedures](procedures.md) - Step-by-step guides
- [SSH Integration](ssh-integration.md) - Use YubiKey for SSH
