Each call uploads one document, so uploading both the certificate and the private key takes two calls.

The target slot is derived from the entity's `pkcs11_id` setting (e.g. `02` → slot 9c for the sub-CA default, `05` → slot 82 for the CA default). See [PIV Slots](../yubikey.md#piv-slots).

**Example:**
```bash
# Upload sub-CA certificate and private key to YubiKey
sca security_key upload subca crt
sca security_key upload subca key
```

After upload, the private key on disk can be securely deleted - all signing operations will use the YubiKey.
