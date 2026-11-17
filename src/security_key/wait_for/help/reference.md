The key is identified by the serial configured in `<entity>_security_key_id`, or the one given with `--device`. Useful in scripts.

**Example:**
```bash
# Wait for the sub-CA's configured YubiKey
sca security_key wait_for subca

# Wait for the sub-CA's backup YubiKey, serial 12345678
sca security_key wait_for --device 12345678 subca

# Unattended (script, CI): fail after 30 s instead of the default 10 s
sca security_key wait_for --timeout 30 subca < /dev/null

# Or set the limit for every command that waits for a key (0 waits forever)
export security_key_wait_timeout=30
```
