**Examples:**

```bash
# Display PKCS#12 bundle contents
sca display p12 ~/.sca/transfer/aharon.p12

# Display p12 with the password on the command line
# (fine for tests; for a real password leave out -p and type it at the prompt)
sca display p12 -p mypassword certificate.p12
```
