**What it does:**
- Generates a new random management key, PIN and PUK, and sets them on the key
  (replacing the factory defaults, or the current values with `--roll-keys`)
- Stores them in `~/.sca/keys/<ca>/<subca>/private/` (created if missing,
  mode 0700) as `<prefix>yubikey-{key,pin,puk}.txt`, mode 0600. With
  `--roll-keys` the previous files are kept as `*.bak`
- If setting a value fails, the files still match what is on the key: when
  nothing changed they are left as they were; when only part changed, they
  record the new values for what changed, and the error says which ones

**Important:** Save the generated credentials! You'll need the PUK if you forget your PIN.
