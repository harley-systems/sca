The key is identified by the serial configured in `<entity>_security_key_id`, or the one given with `--device`. Useful in scripts.

**Example:**
```bash
# Wait for the sub-CA's configured YubiKey
sca security_key wait_for subca

# Wait for the sub-CA's backup YubiKey, serial 12345678
sca security_key wait_for --device 12345678 subca
```
