# Troubleshooting

[← Back to README](../README.md)

Common issues and solutions when using SCA.

## YubiKey Issues

### YubiKey Not Detected

**Symptom:** `sca security_key id` shows no output or error.

**Solutions:**

1. Check pcscd service:
   ```bash
   sudo systemctl status pcscd
   sudo systemctl restart pcscd
   ```

2. Verify YubiKey is recognized by system:
   ```bash
   lsusb | grep -i yubico
   ykman info
   ```

3. Check user permissions:
   ```bash
   # Add user to plugdev group
   sudo usermod -aG plugdev $USER
   # Log out and back in
   ```

4. Check udev rules:
   ```bash
   # Create if missing
   sudo tee /etc/udev/rules.d/69-yubikey.rules << 'EOF'
   ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", GROUP="plugdev"
   EOF
   sudo udevadm control --reload-rules
   ```

### Wrong PIN Entered (PIN Blocked)

**Symptom:** "PIN blocked" after 3 wrong attempts.

**Solution:** Use PUK to unblock:

```bash
yubico-piv-tool -a unblock-pin
# Enter PUK, then new PIN
```

If PUK is also blocked (3 wrong PUK attempts), the PIV applet must be reset:

```bash
# WARNING: This destroys all keys on the YubiKey!
yubico-piv-tool -a reset
```

### PKCS#11 Module Not Found

**Symptom:** Error about missing `opensc-pkcs11.so`.

**Solution:** Find and use correct path:

```bash
find /usr -name "opensc-pkcs11.so" 2>/dev/null
```

Common locations:
- Ubuntu/Debian: `/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so`
- RHEL/CentOS: `/usr/lib64/opensc-pkcs11.so`
- macOS: `/usr/local/lib/opensc-pkcs11.so`

### YubiKey Works But Signing Fails

**Symptom:** YubiKey detected but `sca approve` fails.

**Check:**

1. Verify certificate is on YubiKey:
   ```bash
   pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-objects
   ```

2. Check PIV slot 9c has key and cert:
   ```bash
   yubico-piv-tool -a status
   ```

3. Verify key matches certificate:
   ```bash
   sca security_key get_crt subca
   sca display crt subca
   ```

## Certificate Issues

### Certificate Chain Validation Fails

**Symptom:** "unable to get local issuer certificate" or chain errors.

**Solution:** Verify the chain:

```bash
# Check certificate chain
openssl verify -CAfile ca-crt.pem -untrusted subca-crt.pem service-crt.pem

# Display chain
openssl crl2pkcs7 -nocrl -certfile bundle.pem | openssl pkcs7 -print_certs -noout
```

Ensure you have the complete chain:
1. Root CA certificate
2. Sub-CA certificate (if applicable)
3. End-entity certificate

### Certificate Expired

**Symptom:** Services reject certificate as expired.

**Check expiry:**

```bash
sca display crt service | grep -A2 "Validity"
# or
openssl x509 -in cert.pem -noout -dates
```

**Solution:** Renew the certificate:

```bash
sca create csr service
sca approve csr service
sca create crt service
```

### Wrong Subject/SAN in Certificate

**Symptom:** Certificate doesn't match hostname.

**Check:**

```bash
openssl x509 -in cert.pem -noout -subject -ext subjectAltName
```

**Solution:** Recreate CSR with correct values, then sign again.

### CSR Already Exists Error

**Symptom:** "CSR file already exists" when creating CSR.

**Solution:** Remove old CSR or use different service name:

```bash
rm ~/.sca/keys/<ca>/<subca>/<service>/*-csr.pem
sca create csr service
```

## Configuration Issues

### Configuration Not Persisting

**Symptom:** `sca config set` doesn't save values.

**Check:** Verify config file is writable:

```bash
ls -la ~/.sca/config/sca.config
```

**Solution:** Fix permissions or recreate:

```bash
chmod 644 ~/.sca/config/sca.config
# or
sca config create --recreate all
```

### Wrong File Paths

**Symptom:** Commands can't find keys or certificates.

**Debug:**

```bash
sca -d config resolve 2>&1 | grep folder
```

**Check configuration:**

```bash
sca config get
```

### OpenSSL Config Syntax Error

**Symptom:** OpenSSL operations fail with parse errors.

**Check template:**

```bash
openssl asn1parse -genconf ~/.sca/config/openssl_template.ini
```

**Solution:** Reset OpenSSL config:

```bash
sca config create --recreate openssl
```

## Build Issues

### Make Fails

**Symptom:** `make` command fails.

**Common causes:**

1. Missing `sed`:
   ```bash
   which sed
   ```

2. Wrong shell:
   ```bash
   # Ensure using bash
   bash -c "make"
   ```

3. Permission issues:
   ```bash
   ls -la src/
   chmod -R u+r src/
   ```

### Built Script Has Syntax Errors

**Symptom:** `./build/sca.sh` fails with syntax error.

**Debug:**

```bash
bash -n ./build/sca.sh
```

**Common cause:** Unescaped quotes in heredocs. Check for apostrophes in comments within single-quoted strings.

## Air-Gapped USB Issues

### USB Won't Boot

**Solutions:**

1. Check BIOS/UEFI boot order
2. Disable Secure Boot
3. Try USB 2.0 port (more compatible)
4. Verify image was written correctly:
   ```bash
   # Compare checksums
   sha256sum image.iso
   sudo dd if=/dev/sdX bs=1M count=$(stat -c%s image.iso | awk '{print int($1/1048576)+1}') | sha256sum
   ```

### Packages Won't Install Offline

**Symptom:** apt fails in air-gapped environment.

**Solutions:**

1. Check packages exist:
   ```bash
   ls /opt/sca/packages/
   ```

2. Manual install:
   ```bash
   sudo dpkg -i /opt/sca/packages/*.deb
   sudo apt-get install -f
   ```

3. Recreate USB with apt-mirror:
   ```bash
   sca init sca_usb_stick --include-apt-mirror --yubikey-support
   ```

## OpenSSL Issues

### "unable to load Private Key"

**Symptom:** OpenSSL can't read key file.

**Check:**

1. File exists and is readable:
   ```bash
   ls -la ~/.sca/keys/<ca>/<subca>/*-key.pem
   ```

2. Key format is correct:
   ```bash
   openssl rsa -in key.pem -check -noout
   ```

3. Key is not encrypted (or provide password):
   ```bash
   # Check if encrypted
   head -1 key.pem
   # If "-----BEGIN ENCRYPTED PRIVATE KEY-----", it needs password
   ```

### "Certificate request does not match private key"

**Symptom:** CSR creation or signing fails.

**Solution:** Ensure you're using matching key and CSR:

```bash
# Compare modulus
openssl rsa -in key.pem -noout -modulus | md5sum
openssl req -in csr.pem -noout -modulus | md5sum
# Should match
```

## Getting Help

### Enable Verbose Output

```bash
# Verbose
sca -v create crt service

# Debug (very verbose)
sca -d create crt service
```

### Check Log File

```bash
cat ~/.sca/log
tail -f ~/.sca/log  # Watch in real-time
```

### Report Issues

Include the following when reporting issues:

1. SCA version: `sca --help | head -1`
2. OS version: `cat /etc/os-release`
3. OpenSSL version: `openssl version`
4. Command run (with `-d` flag)
5. Full error output
6. Relevant log entries from `~/.sca/log`

---

## See Also

- [Command Reference](commands.md) - All sca commands
- [Configuration Reference](configuration.md) - Config files
- [YubiKey Setup](yubikey.md) - Hardware key configuration
