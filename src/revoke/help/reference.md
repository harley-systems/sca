**Examples:**

```bash
# Revoke a service certificate (signed by subca)
sca revoke service

# Revoke a sub-CA certificate (signed by ca)
sca revoke subca

# Revoke a host certificate specifying the signer
sca revoke -s subca host
```

After revocation, the CRL is automatically regenerated. Distribute the updated CRL to relying parties.
