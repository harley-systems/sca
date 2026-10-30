**What it does:**
- Reads the PUK from `<prefix>yubikey-puk.txt` and runs `yubico-piv-tool -a unblock-pin` on the entity's key
- By default sets a new random PIN and, once the key has taken it, writes it to `<prefix>yubikey-pin.txt` (mode 0600)
- `-k`, `--keep-pin`: set the PIN already in the PIN file again; the file is not changed
- The PUK is tried once only. If the PUK file is missing, or the key refuses the PUK, it stops with the PIN file unchanged and says how many PUK retries remain. A blocked PUK leaves only a [PIV reset](../yubikey.md#reset-piv-emergency), which destroys the keys on it

**Example:**
```bash
sca security_key verify subca         # FAILED ... PIN error (wrong PIN or PIN blocked)
sca security_key unblock_pin subca
sca security_key verify subca         # SUCCESS
```
