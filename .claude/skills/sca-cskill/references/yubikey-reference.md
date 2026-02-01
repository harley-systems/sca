# YubiKey / PKCS#11 Reference for SCA

## PIV Slot to PKCS#11 ID Mapping

| YubiKey Slot | Purpose | PKCS#11 ID (ykcs11) | SCA Default |
|-------------|---------|---------------------|-------------|
| 9a | PIV Authentication | 01 | - |
| 9c | Digital Signature | 02 | SubCA |
| 9d | Key Management | 03 | - |
| 9e | Card Authentication | 04 | - |
| 82 | Retired Key 1 | 05 | CA |
| 83 | Retired Key 2 | 06 | - |
| 84-95 | Retired Keys 3-20 | 07-24 | - |
| f9 | PIV Attestation | 19 | - |

## Configuration Variables

```bash
# CA YubiKey settings
ca_pkcs11_id_default="05"              # Maps to slot 82
ca_use_security_key_default=true
ca_security_key_type_default=yubikey
ca_security_key_id_default="5414483"   # YubiKey serial
ca_yubikey_pin_policy_default=always
ca_yubikey_touch_policy_default=always

# SubCA YubiKey settings
subca_pkcs11_id_default="02"           # Maps to slot 9c
subca_use_security_key_default=true
subca_yubikey_pin_policy_default=once
```

## PIN Policies

| Policy | Meaning |
|--------|---------|
| `never` | PIN never required for operations |
| `once` | PIN required once per session |
| `always` | PIN required for every operation |

## Touch Policies

| Policy | Meaning |
|--------|---------|
| `never` | No physical touch required |
| `always` | Touch required for every operation |
| `cached` | Touch cached for 15 seconds |

## PIN/PUK/Key File Locations

```
~/.sca/keys/<ca>/<subca>/private/
    <ca>-<subca>-<entity>-yubikey-pin.txt
    <ca>-<subca>-<entity>-yubikey-puk.txt
    <ca>-<subca>-<entity>-yubikey-key.txt   # Management key
```

## PKCS#11 URI Format

```
pkcs11:id=%<hex_id>;type=private;pin-value=<pin>

# Examples:
pkcs11:id=%02;type=private;pin-value=123456   # SubCA (slot 9c)
pkcs11:id=%05;type=private;pin-value=654321   # CA (slot 82)
```

## Required Packages

```bash
# Debian/Ubuntu
sudo apt install yubico-piv-tool ykcs11 opensc libengine-pkcs11-openssl

# Or install via SCA:
sca install
```

## Common YubiKey Operations

```bash
# Check what's on the YubiKey
sca security_key info

# Get YubiKey serial number
sca security_key id

# Initialize YubiKey PIV applet (sets PIN, PUK, management key)
sca security_key init

# Upload a key+cert to YubiKey
sca security_key upload subca

# Retrieve a cert from YubiKey
sca security_key get_crt subca

# Verify a key works (test signing)
sca security_key verify subca
sca security_key verify ca

# Wait for YubiKey to be inserted
sca security_key wait_for
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ykcs11 not found` | `sudo apt install ykcs11` or `sca install` |
| `PKCS#11 engine error` | `sudo apt install libengine-pkcs11-openssl` |
| `PIN incorrect` | Check PIN file or re-initialize with `sca security_key init` |
| `YubiKey not detected` | Unplug/replug, try `sca security_key wait_for` |
| `Slot empty` | Upload key first: `sca security_key upload <entity>` |
| `Touch timeout` | Touch the YubiKey when it blinks during signing |
| `Wrong slot` | Check `sca config get` for correct `pkcs11_id` mapping |
