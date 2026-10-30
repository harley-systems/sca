**Examples:**

```bash
# Display CA certificate
sca display crt ca

# Display service certificate details
sca display crt service

# Display certificate directly from YubiKey (without extracting to disk)
sca display crt --from-security-key subca
sca display crt --from-security-key ca

# Force reading from disk (overrides config)
sca display crt --from-disk subca
```
