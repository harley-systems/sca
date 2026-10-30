**Examples:**

```bash
# Create a new service private key
sca create key service

# Create the key in PKCS#1 format (BEGIN RSA PRIVATE KEY), e.g. for StrongSwan on OpenWRT
sca create key --format pkcs1 service
```
