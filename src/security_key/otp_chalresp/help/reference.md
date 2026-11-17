**What it does:**
- `setup`: generates a 20-byte secret with `openssl rand -hex 20`, writes it as 40 hex characters to the secret file (default `~/.sca/private/yubikey-<serial>-chalresp.txt`, mode 600, folder mode 700), then programs it into OTP slot 2 with `ykman otp chalresp`. An existing secret file is never overwritten, and the file is removed again if programming fails
- `backup`: programs the secret from `--secret-file` into another key's slot 2. It never writes or deletes the file, and warns if other users can read it
- `setup` and `backup` refuse a programmed slot 2 unless `-f` is given; `--touch` requires a touch for every response
- `test`: runs `ykman otp calculate 2` with a fixed challenge and prints the response, so two keys can be compared
- The secret reaches ykman on stdin only: never on a command line, in `~/.sca/log` (even with `-d`) or in the output. No mode needs `sca config`

**Example:**
```bash
sca install --yubikey-support
sca security_key otp_chalresp setup --device 12345678
sca security_key otp_chalresp backup --device 87654321 \
  --secret-file ~/.sca/private/yubikey-12345678-chalresp.txt
sca security_key otp_chalresp test --device 12345678
sca security_key otp_chalresp test --device 87654321   # same response
```

See [Challenge-response](../yubikey.md#challenge-response) for what it is used for.
