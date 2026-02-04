# SCA Command Reference

[← Back to README](../README.md)

Complete reference for all SCA commands.

## Installation

```bash
# Build and install to ~/bin with bash completion
make deploy

# Reload completion in current shell
. ~/.local/share/bash-completion/completions/sca

# Install prerequisites
sca install --yubikey-support
```

For system-wide installation:

```bash
sudo make deploy INSTALL_DIR=/usr/local/bin COMPLETION_DIR=/etc/bash_completion.d
```

## Command Overview

```
sca [options] <command> [subcommand] [arguments]
```

### Global Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Print help |
| `-v, --verbose` | Verbose output |
| `-d, --detailed-verbose` | Debug-level output |
| `-c, --config-file` | Use alternate config file |

---

## Commands

### create

Create security documents (keys, certificates, requests).

```bash
sca create <document_type> <entity>
```

| Document Type | Description |
|---------------|-------------|
| `key` | Private key |
| `csr` | Certificate signing request |
| `crt` | Certificate |
| `pub` | Public key (extracted from cert) |
| `pub_ssh` | Public key in OpenSSH format |
| `crl` | Certificate revocation list |
| `crt_pub_ssh` | Batch: certificate + public keys |

| Entity | Description |
|--------|-------------|
| `ca` | Certificate authority |
| `subca` | Sub-ordinate CA |
| `service` | Service certificate |
| `host` | Host certificate |
| `user` | User certificate |

**Examples:**

```bash
# Create a new service private key
sca create key service

# Create certificate signing request
sca create csr service

# Create certificate (after CSR is approved)
sca create crt service

# Batch create cert + public keys
sca create crt_pub_ssh service

# Generate CRL for sub-CA
sca create crl subca

# Generate CRL for root CA
sca create crl ca
```

---

### revoke

Revoke a certificate and regenerate the CRL.

```bash
sca revoke <entity>
```

| Option | Description |
|--------|-------------|
| `-h, --help` | Print help |
| `-s, --sign-by` | Entity that signed the certificate (`ca` or `subca`) |

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

---

### request

Create a request for signing (when CA is remote/offline).

```bash
sca request csr <entity>
```

Creates a CSR that can be transferred to another system for signing.

---

### approve

Approve a certificate signing request (requires CA/sub-CA access).

```bash
sca approve <entity> [<entity_id>]
```

When using a YubiKey, this will prompt for the PIN.

---

### display

Display security documents in human-readable format.

```bash
sca display <document_type> <entity>
```

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

# Display certificate signing request
sca display csr service

# Display PKCS#12 bundle contents
sca display p12 ~/.sca/transfer/aharon.p12

# Display p12 with password
sca display p12 -p mypassword certificate.p12
```

---

### export

Export certificates and keys as archive bundles.

```bash
sca export <bundle_type> <entity>
```

| Bundle Type | Contents |
|-------------|----------|
| `crt_pub_ssh` | Certificate + public key + SSH public key |
| `csr` | Certificate signing request |
| `p12` | PKCS#12 bundle with certificate, private key, and CA chain |

**Examples:**

```bash
# Export service certificate bundle
sca export crt_pub_ssh service

# Export CSR for remote signing
sca export csr service

# Export PKCS#12 bundle for mobile VPN client
sca export p12 user

# Export p12 with custom password and friendly name
sca export p12 -p mypassword -n "My VPN Certificate" user

# Export p12 with legacy encryption for older software
sca export p12 --legacy service
```

**p12 Options:**

| Option | Description |
|--------|-------------|
| `-p, --password` | Password to protect the p12 file (prompted if not provided) |
| `-n, --friendly-name` | Friendly name for the certificate in the bundle |
| `-l, --legacy` | Use legacy encryption for compatibility with older software |
| `-o, --output` | Custom output file path |

---

### import

Import security documents from external sources.

```bash
sca import <document_type> <entity> <file>
```

---

### list

List existing entities and configurations.

```bash
sca list [options] <entity_type>
```

| Entity Type | Description |
|-------------|-------------|
| `cas` | Certificate authorities |
| `subcas` | Sub-ordinate CAs |
| `users` | User certificates |
| `hosts` | Host certificates |
| `services` | Service certificates |
| `configs` | Configuration files |

**Options:**

| Option | Description |
|--------|-------------|
| `-o, --output-format` | `ids` (default) or `wide` |

**Examples:**

```bash
# List all CAs
sca list cas

# List services with details
sca list -o wide services
```

---

### config

Manage SCA configuration.

```bash
sca config <subcommand> [arguments]
```

| Subcommand | Description |
|------------|-------------|
| `get [key]` | Get configuration value (all if no key) |
| `set <key> <value>` | Set configuration value |
| `create` | Generate initial configuration files |
| `resolve` | Resolve derived settings from base config |
| `load <file>` | Load configuration from file |
| `save <file>` | Save current configuration to file |
| `reset` | Reset to default values |

#### Configuration Keys

| Key | Description | Example |
|-----|-------------|---------|
| `ca` | CA name (organization) | `mycompany` |
| `subca` | Sub-CA name (administrator) | `admin` |
| `service` | Current service name | `gitlab` |
| `host` | Current host name | `server1` |
| `user` | Current user name | `john` |
| `domain` | Domain suffix | `.mycompany.com` |

**Additional keys:**

| Key | Description | Default |
|-----|-------------|---------|
| `ca_bits` | CA key size | `4096` |
| `subca_bits` | Sub-CA key size | `4096` |
| `service_bits` | Service key size | `2048` |
| `host_bits` | Host key size | `2048` |
| `user_bits` | User key size | `2048` |

#### config get

```bash
# Get all configuration
sca config get

# Get specific value
sca config get ca
sca config get domain
```

#### config set

```bash
# Set CA name
sca config set ca mycompany

# Set domain
sca config set domain .mycompany.com

# Set current service
sca config set service webapp
```

#### config create

Generate initial configuration files in `~/.sca/config/`.

```bash
sca config create [options] <target>
```

| Target | Description |
|--------|-------------|
| `all` | Create all configuration files |
| `openssl` | Create OpenSSL configuration template |
| `conventions` | Create naming conventions file |

**Options:**

| Option | Description |
|--------|-------------|
| `--recreate` | Overwrite existing configuration |

#### config resolve

Resolve derived settings (file paths, full names) from base configuration. Used internally and in scripted scenarios.

```bash
sca config resolve
```

#### config load / save

```bash
# Save current configuration
sca config save ~/my-sca-config.sh

# Load configuration from file
sca config load ~/my-sca-config.sh
```

The configuration file format is a bash script with exported variables.

#### config reset

Reset all configuration values to defaults.

```bash
sca config reset
```

---

### security_key

Manage YubiKey and hardware security tokens.

```bash
sca security_key <subcommand> [arguments]
```

| Subcommand | Description |
|------------|-------------|
| `info` | Display all PIV slots and certificates |
| `verify <entity>` | Verify private key is present and working |
| `init` | Initialize security key (first-time setup) |
| `id` | Display security key identifier/serial |
| `upload <entity>` | Upload key and certificate to security key |
| `get_crt <entity>` | Retrieve certificate from security key |
| `wait_for <serial>` | Wait for specific key to be inserted |

#### security_key info

Display the status of all PIV slots on the YubiKey, including certificates and expiry dates.

```bash
sca security_key info
```

**Example output:**
```
YubiKey PIV Slot Information
============================

Slot 9c (Digital Signature):
  Subject:   MyCompany SubCA - admin
  Expires:   Jan 21 19:16:13 2036 GMT
  Algorithm: rsaEncryption

Slot 82 (Retired Key 1 (CA)):
  Subject:   MyCompany CA
  Expires:   Jan 21 19:44:49 2036 GMT
  Algorithm: rsaEncryption
```

#### security_key verify

Verify that a private key is present and functional by performing a test signing operation.

```bash
sca security_key verify <entity>
```

**Example:**
```bash
# Verify sub-CA private key on YubiKey
sca security_key verify subca

# Verify CA private key (if stored on YubiKey)
sca security_key verify ca
```

This is the most reliable way to confirm a key exists, as tools like `ykman piv info` may incorrectly report "Private key: Not present" even when keys are working.

#### security_key init

Initialize a new YubiKey for use with sca. This sets up new PIN, PUK, and management key.

```bash
sca security_key init
```

**What it does:**
- Generates new random management key
- Prompts for new PIN (default: 123456)
- Prompts for new PUK (default: 12345678)
- Stores credentials securely

**Important:** Save the generated credentials! You'll need the PUK if you forget your PIN.

#### security_key id

Display the serial number of the currently inserted YubiKey.

```bash
sca security_key id
```

Useful for identifying which key is inserted when you have multiple YubiKeys.

#### security_key upload

Upload a private key and certificate to the YubiKey's PIV slot 9c (Digital Signature).

```bash
sca security_key upload <entity>
```

**Example:**
```bash
# Upload sub-CA to YubiKey
sca security_key upload subca
```

After upload, the private key on disk can be securely deleted - all signing operations will use the YubiKey.

#### security_key get_crt

Retrieve a certificate from the YubiKey.

```bash
sca security_key get_crt <entity>
```

**Example:**
```bash
# Get sub-CA certificate from YubiKey
sca security_key get_crt subca
```

#### security_key wait_for

Wait for a specific YubiKey (by serial number) to be inserted. Useful in scripts.

```bash
sca security_key wait_for <serial>
```

**Example:**
```bash
# Wait for YubiKey with serial 12345678
sca security_key wait_for 12345678
```

---

### init

Initialize SCA environment, demo data, or bootable USB images.

```bash
sca init <target> [options]
```

| Target | Description |
|--------|-------------|
| `demo` | Create demo CA structure for testing |
| `sca_usb_stick` | Create bootable USB for air-gapped CA operations |
| `openssl_ca_db` | Initialize OpenSSL CA database for an entity |
| `yubikey` | Initialize YubiKey for use with sca |

#### demo

Create a complete demo CA hierarchy for testing and learning.

```bash
sca init demo [demo_folder]
```

**What it creates:**
- Root CA (key + self-signed certificate)
- Sub-CA (key + certificate signed by root)
- Sample service certificate
- Sample user certificate

**Example:**
```bash
# Create demo in default location (~/.sca/demo/)
sca init demo

# Create demo in custom location
sca init demo /tmp/sca-demo
```

This is useful for:
- Learning how sca works
- Testing certificate workflows
- Development and debugging

#### openssl_ca_db

Initialize the OpenSSL CA database files for a certificate authority.

```bash
sca init openssl_ca_db <entity>
```

Creates the `index.txt` and `serial` files required by OpenSSL for tracking issued certificates.

#### yubikey

Initialize a YubiKey for use with sca (alias for `sca security_key init`).

```bash
sca init yubikey
```

#### sca_usb_stick

Creates a bootable Ubuntu live USB with sca pre-installed for air-gapped root CA operations.

```bash
sca init sca_usb_stick [options] [ubuntu_version_id]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-y, --yubikey-support` | Include YubiKey/Yubico packages |
| `-i, --include-apt-mirror` | Mirror apt repositories for fully offline use |
| `-x, --exclude-pkcs11-support` | Skip PKCS#11 packages |
| `-t, --test-image` | Create test variant for automated testing |
| `-s, --skip-cleanup` | Keep intermediate files after build |
| `-q, --no-cache-squashfs` | Do not cache squashfs file |
| `-p, --no-cache-iso` | Do not cache ISO file |
| `-n, --no-cache` | Disable all caching |

**Ubuntu versions:** `18.04.1-bionic` (default), `16.04.x-xenial`, `14.04.x-trusty`

**Example:**

```bash
# Create USB image with YubiKey support
sca init sca_usb_stick --yubikey-support

# Write to USB (replace sdX with your device)
sudo dd bs=4M if=~/.sca/downloads/ubuntu-18.04.1-desktop-amd64.sca.iso of=/dev/sdX conv=fdatasync
```

See [Air-Gapped Operations](air-gapped-operations.md) for complete workflow documentation.

---

### install

Install SCA and prerequisites.

```bash
sca install [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-h, --help` | Display help |
| `-a, --air-gapped` | Install in offline mode (from USB stick packages) |
| `-f, --force` | Overwrite existing sca installation |
| `-y, --yubikey-support` | Install YubiKey/Yubico tools |
| `-x, --exclude-pkcs11-support` | Skip PKCS#11 package installation |

**Examples:**

```bash
# Online installation with YubiKey support
sca install --yubikey-support

# Offline installation (from SCA USB stick)
sca install --air-gapped

# Force reinstall
sca install --force
```

**Installed packages (online mode):**
- `openssl`, `openssh-client` - Core crypto tools
- `datefudge` - For backdating CA certificates
- `opensc`, `pcscd`, `libccid` - Smart card support
- `libengine-pkcs11-openssl` - PKCS#11 OpenSSL engine
- `yubico-piv-tool` - YubiKey management (with `-y`)
- `squashfs-tools`, `genisoimage`, `qemu-kvm` - USB image creation

---

### test

Run SCA tests, including air-gapped environment tests using QEMU.

```bash
sca test [options] [ubuntu_version_id]
```

**Options:**

| Option | Description |
|--------|-------------|
| `-h, --help` | Display help |
| `-a, --air-gapped` | Run tests in offline mode |
| `-s, --skip-air-gapped-tests` | Skip QEMU-based air-gapped tests |

**Examples:**

```bash
# Run all tests (including QEMU air-gapped tests)
sca test

# Run only online tests (faster, no QEMU)
sca test --skip-air-gapped-tests

# Run tests for specific Ubuntu version
sca test 18.04.1-bionic
```

The air-gapped tests:
1. Create a test USB image with `sca init sca_usb_stick --test-image`
2. Boot it in QEMU with no network
3. Run test suite inside the VM
4. Collect results via virtual disk

---

### completion

Generate shell completion scripts.

```bash
sca completion bash    # Bash completion
sca completion zsh     # Zsh completion
```

Add to `.bashrc`:

```bash
source <(sca completion bash)
```

---

## Common Workflows

### Issue New Service Certificate

```bash
# 1. Configure service name
sca config set service myservice

# 2. Create private key
sca create key service

# 3. Create CSR
sca create csr service

# 4. Approve CSR (requires YubiKey PIN)
sca approve service

# 5. Create certificate
sca create crt service

# 6. Export bundle for deployment
sca export crt_pub_ssh service
```

### Setup New Sub-CA on YubiKey

```bash
# 1. Initialize YubiKey
sca security_key init

# 2. Configure sub-CA name
sca config set subca newadmin

# 3. Create sub-CA key and CSR
sca create key subca
sca create csr subca

# 4. Sign with root CA (offline)
sca approve subca

# 5. Create certificate
sca create crt subca

# 6. Upload to YubiKey
sca security_key upload subca
```

---

## File Locations

| Path | Description |
|------|-------------|
| `~/.sca/config/` | Configuration files |
| `~/.sca/keys/<ca>/<subca>/` | Keys and certificates |
| `~/.sca/config/openssl_template.ini` | OpenSSL configuration template |

## See Also

- [Procedures](procedures.md) - Step-by-step guides
- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [SSH Integration](ssh-integration.md) - Certificate-based SSH
- [Air-Gapped Operations](air-gapped-operations.md) - Secure offline environment
- [Configuration Reference](configuration.md) - Config files and customization
