# SCA Command Reference

[← Back to README](../README.md)

Complete reference for all SCA commands.

## Installation

```bash
make
./build/sca.sh install prerequisites
```

For system-wide installation:

```bash
sudo cp build/sca.sh /usr/local/bin/sca
```

Enable bash completion:

```bash
source <(sca completion bash)
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
```

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
sca approve csr <entity>
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

# Display certificate signing request
sca display csr service
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

**Examples:**

```bash
# Export service certificate bundle
sca export crt_pub_ssh service

# Export CSR for remote signing
sca export csr service
```

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
| `get <key>` | Get configuration value |
| `set <key> <value>` | Set configuration value |
| `create` | Generate initial configuration |
| `resolve` | Resolve derived settings |
| `load <file>` | Load configuration from file |
| `save <file>` | Save configuration to file |
| `reset` | Reset to defaults |

**Configuration Keys:**

| Key | Description | Example |
|-----|-------------|---------|
| `ca` | CA name | `sb` |
| `subca` | Sub-CA name | `harley` |
| `service` | Current service | `gitlab` |
| `host` | Current host | `yellow` |
| `user` | Current user | `harley` |
| `domain` | Domain suffix | `.sb.com` |

**Examples:**

```bash
# Get current CA
sca config get ca

# Set service name
sca config set service gitlab

# View all configuration
sca config get

# Reset to defaults
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
| `init` | Initialize security key (first-time setup) |
| `id` | Display security key identifier |
| `upload <entity>` | Upload key/cert to security key |
| `get_crt <entity>` | Retrieve certificate from key |
| `wait_for <key_id>` | Wait for specific key to be inserted |

**Examples:**

```bash
# Initialize new YubiKey
sca security_key init

# Get YubiKey serial/ID
sca security_key id

# Upload sub-CA to YubiKey
sca security_key upload subca

# Retrieve certificate from YubiKey
sca security_key get_crt subca
```

---

### init

Initialize SCA environment or demo data.

```bash
sca init <target>
```

| Target | Description |
|--------|-------------|
| `demo` | Create demo CA structure |
| `usb` | Prepare USB stick for offline CA |

---

### install

Install SCA and prerequisites.

```bash
sca install <component>
```

| Component | Description |
|-----------|-------------|
| `prerequisites` | OpenSSL, YubiKey tools, etc. |
| `sca` | Install sca to system |

---

### test

Run SCA unit tests.

```bash
sca test [test_name]
```

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
sca approve csr service

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
sca approve csr subca

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
