# SCA Procedures

[← Back to README](../README.md)

Step-by-step guides for common PKI operations using SCA.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Issue Service Certificate](#issue-service-certificate)
3. [Issue VPN Certificate](#issue-vpn-certificate)
4. [Issue User Certificate](#issue-user-certificate)
5. [Renew Certificate](#renew-certificate)
6. [Revoke Certificate](#revoke-certificate)
7. [Add New Administrator](#add-new-administrator)
8. [Deploy Certificates](#deploy-certificates)

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
sca security_key upload subca
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
# Revoke the certificate (requires root CA)
openssl ca -revoke ~/.sca/keys/sb/harley/badservice/*-crt.pem \
  -config ~/.sca/config/ca.ini

# Generate updated CRL
openssl ca -gencrl -out ~/.sca/keys/sb/sb-crl.pem \
  -config ~/.sca/config/ca.ini

# Distribute CRL to services
scp ~/.sca/keys/sb/sb-crl.pem root@router:/etc/ipsec.d/crls/
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
sca security_key upload subca
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
