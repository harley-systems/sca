Current versions of sca redact secrets before they are logged, but a log written by an older version can still hold the YubiKey PIN (as `pin-value=…`, `-passin pass:…` or `OPENSSL_PKCS11_PIN=…`) or the management key in cleartext. `scrub_log` replaces them with `<REDACTED>` in place, using the same patterns sca applies to new log lines, and leaves the file with mode `0600`. If the log is a symlink, the file it points to is scrubbed; a hard-linked log is rewritten in place so every link is redacted. Don't run it while other `sca` commands are running, or their new log lines may be lost.

**Examples:**

```bash
# Scrub the default log
sca scrub_log

# Scrub a copy of a log, e.g. one taken from the SCA USB stick
sca scrub_log ./log
```

Run it once after upgrading, and always before attaching a log to a bug report.
