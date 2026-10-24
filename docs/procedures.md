# SCA Procedures

[← Back to README](../README.md)

Step-by-step guides for common PKI operations using SCA.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Issue Service Certificate](#issue-service-certificate)
3. [Issue VPN Certificate](#issue-vpn-certificate)
4. [Issue User Certificate](#issue-user-certificate)
5. [Browser Client Certificates (mTLS)](#browser-client-certificates-mtls)
6. [Renew Certificate](#renew-certificate)
7. [Revoke Certificate](#revoke-certificate)
8. [Add New Administrator](#add-new-administrator)
9. [Deploy Certificates](#deploy-certificates)

---

## Initial Setup

### Prerequisites

- Linux system (Ubuntu/Debian recommended)
- YubiKey with PIV support (YubiKey 4 or newer)
- USB storage for offline root CA

### Install SCA Tool

```bash
cd sca
make
./build/sca.sh install prerequisites
sudo cp build/sca.sh /usr/local/bin/sca
source <(sca completion bash)
```

### Create Root CA (Offline)

> **Security:** This should be done on an air-gapped system.

```bash
# Boot from live USB, mount secret storage
sudo mount /dev/sdX1 /mnt/secret

# Configure CA parameters
sca config set ca mycompany
sca config set domain .mycompany.com

# Create root CA
sca create key ca
sca create crt ca

# Backup to second USB
cp -r ~/.sca/keys /mnt/secret/
```

### Create Sub-CA (on YubiKey)

```bash
# Initialize YubiKey (sets PIN, PUK, management key)
sca security_key init

# Configure sub-CA
sca config set subca admin1

# Create sub-CA key and certificate
sca create key subca
sca create csr subca

# Sign with root CA (requires root CA access)
sca approve subca
sca create crt subca

# Upload to YubiKey
sca security_key upload subca crt
sca security_key upload subca key
```

---

## Issue Service Certificate

For HTTPS services (GitLab, Kubernetes Dashboard, etc.).

### 1. Configure Service

```bash
sca config set service gitlab
sca config set host yellow
```

### 2. Create Key and CSR

```bash
sca create key service
sca create csr service
```

### 3. Sign Certificate

Insert YubiKey and approve:

```bash
sca approve service
sca create crt service
```

### 4. Export for Deployment

```bash
sca export crt_pub_ssh service
```

This creates a tarball containing:
- `*-crt.pem` - Certificate
- `*-key.pem` - Private key
- `*-pub.pem` - Public key
- `*-pub_ssh.pub` - SSH public key format

---

## Issue VPN Certificate

For StrongSwan IPSec authentication.

### Road Warrior Client

```bash
# Configure for VPN client
sca config set service vpn-client
sca config set user mobile1

# Create client certificate
sca create key user
sca create csr user
sca approve user
sca create crt user

# Export for client device
sca export crt_pub_ssh user
```

### VPN Server

```bash
sca config set service vpn-server
sca config set host router

sca create key host
sca create csr host
sca approve host
sca create crt host
```

### Deploy to Router

```bash
# Copy certificates to router
scp ~/.sca/keys/sb/harley/vpn-server/*-crt.pem root@router:/etc/ipsec.d/certs/
scp ~/.sca/keys/sb/harley/vpn-server/*-key.pem root@router:/etc/ipsec.d/private/
scp ~/.sca/keys/sb/sb-ca-crt.pem root@router:/etc/ipsec.d/cacerts/
```

Or use Ansible:

```bash
ansible-playbook -i development.yml configure-router.yml --tags install_ipsec
```

---

## Issue User Certificate

For SSH access, email signing, or client authentication.

```bash
sca config set user newuser

sca create key user
sca create csr user
sca approve user
sca create crt user

# Create SSH public key
sca create pub_ssh user
```

---

## Browser Client Certificates (mTLS)

Protect an internal web application so that only browsers holding a certificate
issued by your sub-CA can reach it. The browser presents a `user` certificate,
and NGINX checks it against the SCA root and sub-CA.

Paths below use the default layout: `<ca>` is the CA name, `<subca>` the sub-CA
name and `<user>` the user name, as set with `sca config set`.

### 1. Issue the Client Certificate

`user` certificates are issued with `extendedKeyUsage = clientAuth` already, so
the normal user flow is enough:

```bash
sca config set user alice

sca create key user
sca create csr user
sca approve user
```

### 2. Export as PKCS#12 (.p12)

```bash
sca export p12 user
# p12 file created: ~/.sca/transfer/alice.p12
```

The `.p12` holds the user certificate, its private key and the sub-CA + root CA
chain. You are prompted for an export password. Let SCA prompt for it rather than
passing `-p`, which leaves the password in your shell history and the process list.
Give the password to the user over a different channel than the file.

Use `-n alice-dashboards` to set the name the browser shows in its certificate
picker, and `-o <file>` to choose the output path. The name can't contain spaces
yet: `sca` splits it into separate arguments and the export fails.

**When to use `--legacy`:** by default OpenSSL 3 encrypts the bundle with
AES-256/PBKDF2. Current Chrome, Firefox and Windows import this fine. Older macOS
Keychain versions (and so Safari) can't read it and reject the import with a
misleading "incorrect password" error. If that happens, re-export with:

```bash
sca export p12 --legacy user
```

### 3. Import into the Browser

If the web application's server certificate is also issued by SCA, the browser
must trust the SCA root CA as well. See [Browser Trust](#browser-trust).

**Chrome / Edge:**
- *Windows:* double-click the `.p12`. In the Certificate Import Wizard choose
  "Current User", enter the password and let it place the certificate in the
  "Personal" store.
- *Linux:* open `chrome://settings/certificates`, go to "Your certificates" and
  click "Import". Select the `.p12` and enter the password. Chrome on Linux uses
  the NSS database at `~/.pki/nssdb`.
- *macOS:* Chrome uses the macOS Keychain. Follow the Safari steps below.

**Firefox** (its own certificate store on every OS):
1. Open `about:preferences#privacy`
2. Under "Certificates", click "View Certificates" → "Your Certificates" → "Import"
3. Select the `.p12` and enter the password

**Safari (macOS Keychain):**
1. Double-click the `.p12`, or run
   `security import alice.p12 -k ~/Library/Keychains/login.keychain-db`
2. Enter the export password. It is added to the "login" keychain.
3. If the import says the password is incorrect, re-export with `--legacy` (see above)

When you first visit the protected site, the browser asks which certificate to
present. Pick the one you imported.

### 4. Configure NGINX for mTLS

Build a chain file with the sub-CA and root CA certificates, which NGINX uses to
verify clients:

```bash
cat ~/.sca/keys/<ca>/<subca>/<ca>-<subca>-subca-crt.pem \
    ~/.sca/keys/<ca>/<ca>-ca-crt.pem > sca-client-ca-chain.pem
sudo cp sca-client-ca-chain.pem /etc/nginx/ssl/
```

```nginx
server {
    listen 443 ssl;
    server_name dashboards.mycompany.com;

    # server certificate (e.g. an SCA service certificate)
    ssl_certificate     /etc/nginx/ssl/dashboards-crt.pem;
    ssl_certificate_key /etc/nginx/ssl/dashboards-key.pem;

    # require a client certificate issued by the SCA sub-CA
    ssl_client_certificate /etc/nginx/ssl/sca-client-ca-chain.pem;
    ssl_verify_client      on;
    ssl_verify_depth       2;   # user cert -> sub-CA -> root CA

    # optional: reject revoked certificates (see below)
    # ssl_crl /etc/nginx/ssl/sca-crl.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;

        # optional: tell the application who the client is
        proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
        proxy_set_header X-SSL-Client-S-DN   $ssl_client_s_dn;
    }
}
```

Clients without a valid certificate get a `400 No required SSL certificate was
sent` error from NGINX. If you'd rather show a friendlier page, set
`ssl_verify_client optional;` and return an error yourself when
`$ssl_client_verify` is not `SUCCESS`.

**Revocation (`ssl_crl`):** NGINX checks CRLs for every certificate in the chain.
The file must therefore contain **both** the root CA and the sub-CA CRL. With only
the sub-CA CRL, every client is rejected:

```bash
sca create crl ca      # requires root CA access
sca create crl subca
cat ~/.sca/keys/<ca>/<ca>-ca-crl.pem \
    ~/.sca/keys/<ca>/<subca>/<ca>-<subca>-subca-crl.pem > sca-crl.pem
sudo cp sca-crl.pem /etc/nginx/ssl/ && sudo nginx -s reload
```

CRLs expire (`default_crl_days`, 10 days by default). Once one in `ssl_crl` has
expired, NGINX rejects **all** clients. Regenerate and redeploy the CRLs on a
schedule. After `sca revoke user`, rebuild `sca-crl.pem` and reload NGINX.

### 5. Test

```bash
# extract cert and key from the p12 for testing
openssl pkcs12 -in alice.p12 -nodes -out alice.pem      # add -legacy for --legacy bundles

curl --cert alice.pem https://dashboards.mycompany.com/  # succeeds
curl https://dashboards.mycompany.com/                   # 400, no client certificate
```

Delete `alice.pem` afterwards, because it holds the unencrypted private key.

---

## Renew Certificate

Before a certificate expires:

```bash
# Check expiry
sca display crt service | grep -A2 "Validity"

# Create new CSR with existing key
sca create csr service

# Sign new certificate
sca approve service
sca create crt service

# Deploy updated certificate
sca export crt_pub_ssh service
```

---

## Revoke Certificate

> **Note:** Certificate revocation requires CRL distribution.

### Revoke and Update CRL

```bash
# Configure the entity to revoke
sca config set service badservice

# Revoke the certificate (CRL is regenerated automatically)
sca revoke service

# If revoking a sub-CA certificate
sca revoke subca

# To regenerate CRL without revoking (e.g., after expiry update)
sca create crl subca

# Distribute CRL to services
scp ~/.sca/keys/<ca>/<subca>/<subca>-crl.pem root@router:/etc/ipsec.d/crls/
```

---

## Add New Administrator

Create a new sub-CA for another person.

### Prepare New YubiKey

```bash
# On new admin's machine
sca security_key init

# Create sub-CA request
sca config set subca newadmin
sca create key subca
sca create csr subca

# Export CSR for signing
sca export csr subca
```

### Sign Sub-CA (Root CA Required)

```bash
# On machine with root CA access
sca import csr subca newadmin-csr.tar.gz
sca approve subca
sca create crt subca
sca export crt_pub_ssh subca
```

### Complete Setup

```bash
# On new admin's machine
sca import crt subca signed-subca.tar.gz
sca security_key upload subca crt
sca security_key upload subca key
```

---

## Deploy Certificates

### Kubernetes Secrets

```bash
# Create TLS secret
kubectl create secret tls myservice-tls \
  --cert=myservice-crt.pem \
  --key=myservice-key.pem \
  -n myservice

# Create CA secret for client verification
kubectl create secret generic ca-cert \
  --from-file=ca.crt=sb-ca-crt.pem \
  -n myservice
```

### Ansible Deployment

Certificates for services managed by Ansible are deployed via roles:

```bash
# Deploy router certificates
ansible-playbook -i development.yml configure-router.yml

# Deploy node certificates
ansible-playbook -i development.yml configure-arm-kube-nodes.yml
```

### Browser Trust

To trust the internal CA in browsers:

**Firefox:**
1. Navigate to `about:preferences#privacy`
2. Click "View Certificates" → "Authorities" → "Import"
3. Select `sb-ca-crt.pem`
4. Check "Trust for websites"

**Chrome:**
1. Navigate to `chrome://settings/certificates`
2. Click "Authorities" → "Import"
3. Select `sb-ca-crt.pem`
4. Check "Trust for websites"

**System-wide (Ubuntu):**
```bash
sudo cp sb-ca-crt.pem /usr/local/share/ca-certificates/sb-ca.crt
sudo update-ca-certificates
```

---

## Troubleshooting

### Certificate Chain Issues

```bash
# Verify certificate chain
openssl verify -CAfile sb-ca-crt.pem -untrusted sb-subca-crt.pem service-crt.pem

# Display full chain
openssl crl2pkcs7 -nocrl -certfile bundle.pem | openssl pkcs7 -print_certs -noout
```

### YubiKey Issues

```bash
# Check YubiKey status
sca security_key id

# List certificates on YubiKey
pkcs11-tool --list-objects

# Reset YubiKey PIV (WARNING: destroys all data)
yubico-piv-tool -a reset
```

### View Certificate Details

```bash
# Display certificate
sca display crt service

# Check expiry
openssl x509 -in cert.pem -noout -dates

# Check subject/issuer
openssl x509 -in cert.pem -noout -subject -issuer
```

---

## See Also

- [Command Reference](commands.md) - Complete command reference
- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [SSH Integration](ssh-integration.md) - Certificate-based SSH
