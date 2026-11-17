**Examples:**

```bash
# Export PKCS#12 bundle for mobile VPN client
sca export p12 user

# Export p12 with a password on the command line and a friendly name
# (fine for tests; for a real password leave out -p and type it at the prompt)
sca export p12 -p mypassword -n My-VPN-Certificate user

# Export p12 with legacy encryption for older software
sca export p12 --legacy service
```

To use a p12 as a browser client certificate for mTLS (importing it into
Chrome/Firefox/Safari and configuring NGINX), see
[Browser Client Certificates (mTLS)](../procedures.md#browser-client-certificates-mtls).
