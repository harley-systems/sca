# SCA Complete Demo Walkthrough

[← Back to README](../README.md)

![SCA Walkthrough Demo](demo/walkthrough.gif)

A comprehensive step-by-step guide from installation to issuing your first user certificate using YubiKey hardware security.

## Overview

This demo covers:
1. Installing SCA and prerequisites
2. Creating a Root CA
3. Setting up a Sub-CA on YubiKey
4. Issuing a user certificate

**Time required:** ~30 minutes

**Requirements:**
- Linux system (Ubuntu/Debian)
- YubiKey 4 or 5 series with PIV support
- Internet connection (for package installation)

---

## Part 1: Installation

### 1.1 Clone and Build SCA

```bash
# Clone the repository
git clone https://github.com/harley-systems/sca.git
cd sca

# Build
make

# Deploy to ~/bin with bash completion
make deploy
```

### 1.2 Reload Completion

```bash
# Reload bash completion in current shell
. ~/.local/share/bash-completion/completions/sca
```

### 1.3 Install Prerequisites

```bash
# Install required packages (openssl, opensc, pcscd, yubico-piv-tool, etc.)
sca install --yubikey-support
```

### 1.4 Verify Installation

```bash
# Check sca is available
sca --help

# Check YubiKey tools
ykman --version
yubico-piv-tool --version

# Check smart card daemon
sudo systemctl status pcscd
```

---

## Part 2: Initial Configuration

### 2.1 Create Configuration

```bash
# Create initial configuration files
sca config create all
```

### 2.2 Configure Your Organization

```bash
# Set your CA/organization name
sca config set ca mycompany

# Set domain suffix (used in certificate subjects)
sca config set domain .mycompany.com
```

### 2.3 Verify Configuration

```bash
# View current configuration
sca config get
```

---

## Part 3: Create Root CA

> **Security Note:** In production, create the root CA on an air-gapped system.
> For this demo, we'll create it on the local machine.

### 3.1 Create Root CA Private Key

```bash
sca create key ca
```

This creates: `~/.sca/keys/mycompany/mycompany-ca-key.pem`

### 3.2 Create Root CA Certificate

```bash
sca create crt ca
```

This creates a self-signed root CA certificate: `~/.sca/keys/mycompany/mycompany-ca-crt.pem`

### 3.3 Verify Root CA

```bash
# Display the root CA certificate
sca display crt ca
```

You should see:
- Issuer and Subject both showing your organization
- `CA:TRUE` in Basic Constraints
- Key Usage: Certificate Sign, CRL Sign

---

## Part 4: Setup YubiKey

### 4.1 Insert YubiKey

Insert your YubiKey and verify it's detected:

```bash
# Check YubiKey is detected
sca security_key info
```

### 4.2 Get YubiKey Serial Number

```bash
sca security_key id
```

Note the serial number (format: `XX-XX-XX-XX-XX-XX`).

### 4.3 Initialize YubiKey

> **Warning:** This will change the PIN, PUK, and management key on your YubiKey.
> Make sure this is the correct YubiKey!

```bash
sca security_key init
```

This will:
- Generate a new random management key
- Prompt you to set a new PIN (default: 123456)
- Prompt you to set a new PUK (default: 12345678)
- Save credentials to secure files

**Important:** Remember your PIN! You'll need it for signing operations.

---

## Part 5: Create Sub-CA on YubiKey

The Sub-CA will be stored on the YubiKey. This means:
- The private key never leaves the hardware
- All signing operations require the YubiKey + PIN
- Even if your computer is compromised, the Sub-CA key is safe

### 5.1 Configure Sub-CA

```bash
# Set sub-CA name (typically your name or role)
sca config set subca admin

# Configure your details for the certificate
sca config set subca name "Admin"
sca config set subca surname "User"
sca config set subca given_name "Admin"
sca config set subca initials "A.U."
```

### 5.2 Create Sub-CA Private Key

```bash
sca create key subca
```

### 5.3 Create Sub-CA Certificate Signing Request

```bash
sca create csr subca
```

### 5.4 Sign Sub-CA with Root CA

```bash
# Approve the CSR (signs with root CA)
sca approve subca
```

### 5.5 Create Sub-CA Certificate

```bash
sca create crt subca
```

### 5.6 Verify Sub-CA Certificate

```bash
sca display crt subca
```

You should see:
- Subject: Your sub-CA details
- Issuer: Your root CA
- `CA:TRUE` in Basic Constraints
- Key Usage: Certificate Sign, CRL Sign

### 5.7 Upload Sub-CA to YubiKey

```bash
sca security_key upload subca
```

This uploads both the private key and certificate to the YubiKey's slot 9c (Digital Signature).

### 5.8 Verify YubiKey Contents

```bash
# View all slots on YubiKey
sca security_key info

# Verify the private key is working
sca security_key verify subca
```

### 5.9 (Optional) Delete Local Private Key

Once uploaded to YubiKey, you can delete the local copy:

```bash
# Secure delete (optional - only after verifying YubiKey works)
# shred -u ~/.sca/keys/mycompany/admin/admin-subca-key.pem
```

---

## Part 6: Issue User Certificate

Now we'll issue a user certificate, signed by the Sub-CA on the YubiKey.

### 6.1 Configure User Details

```bash
# Set user identifier
sca config set user johndoe

# Set user details for certificate
sca config set user name "John"
sca config set user surname "Doe"
sca config set user given_name "John"
sca config set user initials "J.D."
```

### 6.2 Create User Private Key

```bash
sca create key user
```

### 6.3 Create User Certificate Signing Request

```bash
sca create csr user
```

### 6.4 Sign User Certificate with Sub-CA

This step uses the YubiKey - you'll be prompted for your PIN:

```bash
sca approve user
```

**Touch your YubiKey** if touch policy is enabled, and enter your PIN when prompted.

### 6.5 Create User Certificate

```bash
sca create crt user
```

### 6.6 Verify User Certificate

```bash
sca display crt user
```

You should see:
- Subject: User details (CN=MyCompany User - johndoe)
- Issuer: Your Sub-CA
- Extended Key Usage: Client Authentication, Email Protection
- `CA:FALSE` in Basic Constraints

### 6.7 Verify Certificate Chain

```bash
# The certificate should chain back to the root CA
openssl verify \
  -CAfile ~/.sca/keys/mycompany/mycompany-ca-crt.pem \
  -untrusted ~/.sca/keys/mycompany/admin/admin-subca-crt.pem \
  ~/.sca/keys/mycompany/admin/johndoe/johndoe-user-crt.pem
```

Expected output: `OK`

---

## Part 7: Export and Use

### 7.1 Export Certificate Bundle

```bash
sca export crt_pub_ssh user
```

This creates a tarball in `~/.sca/transfer/` containing:
- Certificate (`.crt.pem`)
- Private key (`.key.pem`)
- Public key (`.pub.pem`)
- SSH public key (`.pub_ssh.pub`)

### 7.2 Export PKCS#12 Bundle (for browsers/mobile)

```bash
sca export p12 user
```

You'll be prompted for a password to protect the P12 file.

### 7.3 List Created Certificates

```bash
sca list users
```

---

## Summary

You've successfully:

1. **Installed SCA** with YubiKey support
2. **Created a Root CA** (private key on disk)
3. **Created a Sub-CA** and stored it on YubiKey
4. **Issued a User Certificate** signed by the hardware-protected Sub-CA

### What's on disk vs YubiKey?

| Item | Location |
|------|----------|
| Root CA key | `~/.sca/keys/mycompany/mycompany-ca-key.pem` |
| Root CA cert | `~/.sca/keys/mycompany/mycompany-ca-crt.pem` |
| Sub-CA key | **YubiKey slot 9c** (not on disk after upload) |
| Sub-CA cert | YubiKey + `~/.sca/keys/mycompany/admin/admin-subca-crt.pem` |
| User key | `~/.sca/keys/mycompany/admin/johndoe/johndoe-user-key.pem` |
| User cert | `~/.sca/keys/mycompany/admin/johndoe/johndoe-user-crt.pem` |

### Security achieved:

- Root CA can be moved to offline storage
- Sub-CA private key never leaves YubiKey hardware
- All certificate signing requires physical YubiKey + PIN
- Certificate chain provides proper trust hierarchy

---

## Next Steps

- [Issue Service Certificate](procedures.md#issue-service-certificate) - For HTTPS/TLS
- [SSH Integration](ssh-integration.md) - Use certificates for SSH
- [Air-Gapped Operations](air-gapped-operations.md) - Secure root CA on offline USB
- [YubiKey Setup](yubikey.md) - Advanced YubiKey configuration

---

## Troubleshooting

### YubiKey not detected

```bash
# Restart smart card daemon
sudo systemctl restart pcscd

# Check USB device
lsusb | grep Yubico
```

### Wrong PIN

After 3 failed attempts, PIN is locked. Use PUK to unlock:

```bash
yubico-piv-tool -a unblock-pin
```

### Certificate verification fails

Check the certificate chain:

```bash
sca display crt user | grep -E "(Issuer|Subject):"
sca display crt subca | grep -E "(Issuer|Subject):"
sca display crt ca | grep -E "(Issuer|Subject):"
```

### View YubiKey private key status

```bash
sca security_key verify subca
sca security_key verify ca  # if CA is on YubiKey
```

---

## Quick Reference

```bash
# Configuration
sca config set ca <name>
sca config set subca <name>
sca config set user <name>
sca config get

# Create certificates
sca create key <entity>
sca create csr <entity>
sca approve <entity>
sca create crt <entity>

# YubiKey operations
sca security_key info
sca security_key verify <entity>
sca security_key upload <entity>

# Display and export
sca display crt <entity>
sca export crt_pub_ssh <entity>
sca export p12 <entity>
```

Where `<entity>` is one of: `ca`, `subca`, `user`, `host`, `service`
