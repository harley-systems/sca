**Example:**
```bash
# Verify sub-CA private key on YubiKey
sca security_key verify subca

# Verify CA private key (if stored on YubiKey)
sca security_key verify ca
```

This is the most reliable way to confirm a key exists, as tools like `ykman piv info` may incorrectly report "Private key: Not present" even when keys are working.

The ykcs11 module path comes from the `ykcs11_module` config setting. If that file doesn't exist, common install locations are searched before failing. See [YubiKey Setup](../yubikey.md#verify-private-key-presence).
