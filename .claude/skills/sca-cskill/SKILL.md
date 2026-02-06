---
name: sca-cskill
description: "SCA (Simple Certificate Authority) CLI assistant. Use when the user needs to manage PKI certificates, create keys, CSRs, or certificates, configure SCA, manage YubiKey hardware tokens, approve signing requests, export certificate bundles, or perform any certificate authority operations using the sca command-line tool."
user-invocable: true
argument-hint: "[command or question]"
---

# SCA (Simple Certificate Authority) - Claude Skill

This skill provides Claude with comprehensive knowledge of the SCA CLI tool to assist users with PKI (Public Key Infrastructure) operations. SCA wraps OpenSSL complexity into simple commands and supports YubiKey hardware security keys for protecting CA private keys.

## Tool Location

- **Source code**: https://github.com/harley-systems/sca
- **Installed executable**: `~/bin/sca` (after `make deploy` or download from releases)
- **Configuration**: `~/.sca/config/sca.config`
- **Keys/certs storage**: `~/.sca/keys/<ca>/<subca>/<entity>/`

## When to Use This Skill

Activate when the user:

- Asks about certificates, PKI, certificate authorities, or X.509
- Wants to create keys, CSRs, or certificates using SCA
- Needs to configure SCA settings (CA name, domain, entity names)
- Works with YubiKey or hardware security tokens for PKI
- Needs to approve/sign certificate signing requests
- Wants to export certificate bundles (crt, pub, ssh, p12)
- Needs to revoke certificates or manage certificate revocation lists (CRLs)
- Asks about SCA commands, options, or workflows
- Needs to list CAs, SubCAs, services, hosts, or users
- Wants to initialize a demo CA or set up a new environment
- Asks about PKCS#11, PIV slots, or ykcs11
- Needs to troubleshoot SCA or YubiKey issues
- Wants to modify the SCA source code

## Architecture Overview

```
Root CA (offline, air-gapped, USB storage)
    └── Sub-CA (on YubiKey hardware token, slot 9c)
            ├── Service certificates (TLS/HTTPS)
            ├── Host certificates
            └── User certificates (authentication)
```

**Security model**: Root CA key lives offline on USB. Sub-CA key lives on a YubiKey hardware token. The SubCA signs end-entity certificates (service, host, user).

## Entity Types

SCA manages 5 entity types:

| Entity | Purpose | Default Bits | Typical Storage |
|--------|---------|-------------|-----------------|
| `ca` | Root Certificate Authority | 4096 | Offline USB |
| `subca` | Subordinate CA (signs end-entity certs) | 4096 | YubiKey slot 9c |
| `service` | TLS/HTTPS certificates for web apps, VPN | 2048 | Filesystem |
| `host` | Host certificates for SSH authentication | 2048 | Filesystem |
| `user` | User certificates for SSH/client TLS auth | 2048 | Filesystem |

## Complete Command Reference

### Top-Level Syntax

```bash
sca [options] <command> [subcommand] [entity] [options]
```

**Global Options** (apply to all commands):
- `-v, --verbose` - Verbose output
- `-d, --detailed-verbose` - Debug-level output
- `-h, --help` - Display help text
- `-c, --config-file <file>` - Use alternate config file

### Commands and Subcommands

#### `sca create` - Create security documents

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `key` | `sca create key <entity> [-f\|--force]` | Generate RSA private key |
| `csr` | `sca create csr <entity> [-f\|--force]` | Create Certificate Signing Request |
| `crt` | `sca create crt <entity> [-f\|--force]` | Create signed certificate from CSR |
| `crl` | `sca create crl <entity>` | Generate certificate revocation list |
| `pub` | `sca create pub <entity>` | Extract public key from private key |
| `pub_ssh` | `sca create pub_ssh <entity>` | Extract SSH-format public key |
| `crt_pub_ssh` | `sca create crt_pub_ssh <entity>` | Create crt + pub + ssh in one step |

**Entity**: `ca`, `subca`, `service`, `host`, `user`

**Examples:**
```bash
sca create key service           # Create service private key
sca create csr service           # Create CSR for service
sca create crt service           # Sign CSR to create certificate
sca create crt_pub_ssh service   # All-in-one: crt + pub + ssh key
sca create key service --force   # Overwrite existing key
sca create crl subca             # Generate CRL for SubCA
sca create crl ca                # Generate CRL for root CA
```

#### `sca revoke` - Revoke certificates

```bash
sca revoke <entity> [-s|--sign-by <signing_entity>]
```

Revokes the entity's certificate and automatically regenerates the CRL. The signing entity is resolved automatically: SubCA for service/host/user; CA for SubCA. Override with `-s`.

**Options:**
- `-h, --help` - Show help
- `-s, --sign-by <entity>` - Override which entity's key was used to sign the certificate being revoked (`ca` or `subca`)

**Entity values:** `subca`, `service`, `host`, `user`

**Examples:**
```bash
sca revoke service               # Revoke service cert (signed by SubCA)
sca revoke subca                 # Revoke SubCA cert (signed by CA)
sca revoke -s subca host         # Revoke host cert, specifying signer
```

#### `sca approve` - Approve/sign CSRs and issue certificates

```bash
sca approve <entity> [entity_id] [-f|--force] [-s|--sign-by <signing_entity>]
```

**IMPORTANT: There is NO `csr` subcommand. The syntax is `sca approve <entity>`, NOT `sca approve csr <entity>`.**

Signs the entity's CSR, creates the certificate, public keys, and exports the bundle. The signing entity is resolved automatically: SubCA signs service/host/user; CA signs SubCA. Override with `-s`.

**Options:**
- `-f, --force` - Overwrite existing certificate/pub/ssh files (backs up old ones)
- `-s, --sign-by <entity>` - Override which entity signs (e.g., `-s ca`)
- `-h, --help` - Show help

**Entity values:** `subca`, `service`, `host`, `user` (ca is self-signed, approve is a no-op)

**Examples:**
```bash
sca approve service              # SubCA signs service CSR (YubiKey PIN needed)
sca approve subca                # CA signs SubCA CSR
sca approve service --force      # Overwrite existing cert
sca approve user alice           # Approve a specific user entity by ID
sca approve service -s ca        # Force CA to sign (instead of default SubCA)
```

#### `sca display` - Display certificates/keys/CSRs

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `crt` | `sca display crt <entity>` | Display certificate details |
| `csr` | `sca display csr <entity>` | Display CSR details |
| `p12` | `sca display p12 <entity>` | Display PKCS#12 bundle contents |

**Examples:**
```bash
sca display crt service          # Show service certificate
sca display csr user             # Show user's CSR
```

#### `sca export` - Export certificate bundles

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `crt_pub_ssh` | `sca export crt_pub_ssh <entity>` | Export cert + public key + SSH key |
| `csr` | `sca export csr <entity>` | Export CSR for remote signing |
| `p12` | `sca export p12 <entity>` | Export PKCS#12 bundle |

**Examples:**
```bash
sca export crt_pub_ssh service   # Export bundle as archive
sca export p12 user              # Export PKCS#12 for browser import
```

#### `sca import` - Import certificates

```bash
sca import <entity>
```

Imports certificates from external sources (e.g., after remote CA signing).

#### `sca request` - Create signing requests for remote signing

```bash
sca request <entity>
```

Creates a request package for signing by a remote/offline CA.

#### `sca config` - Configuration management

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `get` | `sca config get <entity>` | Get entity configuration (REQUIRED: ca\|subca\|user\|host\|service) |
| `set` | `sca config set <entity> <value>` | Set entity name (legacy positional mode) |
| `set` | `sca config set <entity> <key> <value>` | Set specific entity setting (key-value mode) |
| `create` | `sca config create` | Create default configuration |
| `load` | `sca config load <file>` | Load configuration from file |
| `save` | `sca config save <file>` | Save configuration to file |
| `reset` | `sca config reset` | Reset to defaults |
| `resolve` | `sca config resolve` | Resolve and display all paths |

**IMPORTANT: `config get` and `config set` always require an entity as the first argument.** The entity must be one of: `ca`, `subca`, `user`, `host`, `service`. There is NO way to get/set all config at once.

**`config get` return formats by entity:**
- `sca config get ca` → `"<ca_name>" "<caps_name>"`
- `sca config get subca` → `"<subca>" "<subca_name>" "<subca_surname>" "<subca_given_name>" "<subca_initials>"`
- `sca config get user` → `"<user>" "<user_name>" "<user_surname>" "<user_given_name>" "<user_initials>"`
- `sca config get host` → `"<host_name>"`
- `sca config get service` → `"<service_name>"`

**`config set` modes:**

Legacy positional mode (set entity name directly):
- `sca config set ca <name> [caps_name]`
- `sca config set subca <id> [name] [surname] [given_name] [initials]`
- `sca config set user <id> [name] [surname] [given_name] [initials]`
- `sca config set host <hostname>`
- `sca config set service <servicename>`

Key-value mode (set specific settings):
- `sca config set ca <key> <value>` - Keys: name, caps_name, domain, bits, use_security_key, security_key_type, security_key_id, pkcs11_id, yubikey_slot, yubikey_pin_policy, yubikey_touch_policy
- `sca config set subca <key> <value>` - Keys: subca, name, surname, given_name, initials, use_security_key, security_key_type, security_key_id, pkcs11_id, yubikey_slot, yubikey_pin_policy, yubikey_touch_policy
- `sca config set service <key> <value>` - Keys: service, use_security_key, security_key_type, security_key_id, pkcs11_id, yubikey_slot, yubikey_pin_policy, yubikey_touch_policy
- (same pattern for host, user)

**Examples:**
```bash
# Get config (entity is REQUIRED)
sca config get ca                # → "harley" "Harley Systems"
sca config get subca             # → "aharon" "Aharon" "Haravon" "Aharon" "A.H."
sca config get service           # → "vpn"
sca config get host              # → "myhost"
sca config get user              # → "alice" "Alice" ...

# To see all entities, run each separately:
sca config get ca && sca config get subca && sca config get service && sca config get host && sca config get user

# Set entity name (legacy positional mode)
sca config set service myapp
sca config set ca mycompany "My Company Inc"
sca config set subca admin "Admin" "Smith" "John" "J.S."

# Set specific settings (key-value mode)
sca config set ca domain .mycompany.com
sca config set ca pkcs11_id 05
sca config set subca pkcs11_id 02
sca config set service use_security_key false

# Other config operations
sca config save ~/backup.config
sca config load ~/backup.config
sca config create                # Create default config
sca config reset                 # Reset to defaults
sca config resolve               # Show all resolved file paths
```

#### `sca list` - List entities

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `cas` | `sca list cas` | List all CAs |
| `subcas` | `sca list subcas` | List all SubCAs |
| `services` | `sca list services` | List all service certificates |
| `hosts` | `sca list hosts` | List all host certificates |
| `users` | `sca list users` | List all user certificates |
| `configs` | `sca list configs` | List configuration files |

#### `sca security_key` - YubiKey management

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `info` | `sca security_key info` | Display all PIV slots on YubiKey |
| `id` | `sca security_key id` | Get YubiKey serial number |
| `init` | `sca security_key init` | Initialize YubiKey PIV (set PIN/PUK) |
| `upload` | `sca security_key upload <entity>` | Upload key+cert to YubiKey slot |
| `get_crt` | `sca security_key get_crt <entity>` | Retrieve cert from YubiKey |
| `verify` | `sca security_key verify <entity>` | Test signing with YubiKey key |
| `wait_for` | `sca security_key wait_for` | Wait for YubiKey insertion |

**Examples:**
```bash
sca security_key info            # Show all PIV slot contents
sca security_key verify ca       # Test CA key on YubiKey
sca security_key verify subca    # Test SubCA key
sca security_key id              # Get YubiKey serial number
sca security_key upload subca    # Upload SubCA key to YubiKey
```

#### `sca init` - Initialize environments

| Subcommand | Syntax | Purpose |
|-----------|--------|---------|
| `demo` | `sca init demo [path]` | Create complete demo CA structure |
| `openssl_ca_db` | `sca init openssl_ca_db` | Initialize OpenSSL database files |
| `sca_usb_stick` | `sca init sca_usb_stick` | Create bootable USB for air-gapped CA |
| `yubikey` | `sca init yubikey` | Initialize YubiKey PIV applet |

#### `sca install` - Install prerequisites

```bash
sca install
```

Installs required packages (openssl, yubico-piv-tool, ykcs11, etc.).

#### `sca test` - Run tests

```bash
sca test [-a|--air-gapped] [-s|--skip-air-gapped-tests] [ubuntu_version]
```

#### `sca completion` - Generate shell completion

```bash
sca completion
```

Generates bash completion script.

## YubiKey / PKCS#11 Integration

### PIV Slot Mapping

```
YubiKey Slot → Purpose                 → PKCS#11 ID (ykcs11)
9a           → PIV Authentication      → 01
9c           → Digital Signature       → 02 (SubCA default)
9d           → Key Management          → 03
9e           → Card Authentication     → 04
82           → Retired Key 1           → 05 (CA default)
83-95        → Retired Keys 2-20       → 06-24
```

### Default SCA Mappings

- **CA key**: YubiKey slot 82, PKCS#11 ID `05`
- **SubCA key**: YubiKey slot 9c, PKCS#11 ID `02`

### PIN File Locations

```
~/.sca/keys/<ca>/<subca>/private/<ca>-<subca>-<entity>-yubikey-pin.txt
~/.sca/keys/<ca>/<subca>/private/<ca>-<subca>-<entity>-yubikey-puk.txt
~/.sca/keys/<ca>/<subca>/private/<ca>-<subca>-<entity>-yubikey-key.txt
```

### PKCS#11 URI Format

```
pkcs11:id=%<pkcs11_id>;type=private;pin-value=<pin>
```

### Required Packages for YubiKey

- `yubico-piv-tool` - YubiKey PIV management
- `ykcs11` (or `libykcs11`) - PKCS#11 module for YubiKey
- `opensc` - Smart card tools
- `libengine-pkcs11-openssl` - OpenSSL PKCS#11 engine

## Common Workflows

### Workflow 1: Issue a Service Certificate (most common)

```bash
# 1. Set the service name
sca config set service myapp

# 2. Create private key
sca create key service

# 3. Create Certificate Signing Request
sca create csr service

# 4. Approve (signs CSR, creates crt + pub + pub_ssh, and exports bundle)
#    This is an all-in-one step - no separate create crt or export needed!
sca approve service              # Uses SubCA on YubiKey, prompts for PIN
```

**Note:** `sca approve` internally calls `create crt_pub_ssh` and `export crt_pub_ssh`, so you do NOT need separate `sca create crt` or `sca export` steps after approve.

### Workflow 2: Set Up a New Sub-CA on YubiKey

```bash
# 1. Initialize YubiKey PIV
sca security_key init

# 2. Configure the SubCA
sca config set subca newadmin

# 3. Create SubCA key and CSR
sca create key subca
sca create csr subca

# 4. Approve (signs CSR with Root CA, creates crt + pub + ssh, exports)
sca approve subca                # Requires CA key access

# 5. Upload to YubiKey
sca security_key upload subca

# 6. Verify
sca security_key verify subca
```

### Workflow 3: Quick Demo Setup

```bash
# Create complete demo CA hierarchy for testing
sca init demo

# This creates: Root CA + SubCA + sample service + sample user
```

### Workflow 4: Create User Certificate for SSH

```bash
sca config set user alice
sca create key user
sca create csr user
sca approve user             # Signs CSR, creates crt + pub + pub_ssh, exports bundle
```

### Workflow 5: Air-Gapped Root CA Signing

```bash
# On the requesting machine:
sca request subca          # Creates request package

# Transfer package to air-gapped CA machine via USB

# On the air-gapped CA machine:
sca approve subca      # Signs with offline root CA key

# Transfer signed cert back via USB

# On the requesting machine:
sca import subca           # Import signed certificate
```

### Workflow 6: Revoke a Certificate

```bash
# 1. Set the entity to revoke (if not already current)
sca config set service compromised-app

# 2. Revoke the certificate (CRL is regenerated automatically)
sca revoke service               # SubCA key needed (YubiKey PIN if on hardware)

# 3. Distribute updated CRL to relying parties
scp ~/.sca/keys/<ca>/<subca>/<subca>-crl.pem root@router:/etc/ipsec.d/crls/
```

**Note:** `sca revoke` internally calls `create_crl` after revocation, so the CRL is always up to date. To regenerate a CRL without revoking (e.g., to refresh expiry), use `sca create crl subca` directly.

### CRL Distribution Server

A Docker-based CRL distribution server is available at `docker/crl-server/`:

```bash
docker build -t sca-crl-server docker/crl-server/
docker run -d -p 80:80 -v ~/.sca/keys:/usr/share/nginx/html/crl:ro sca-crl-server
```

## Configuration Details

### Configuration File

Location: `~/.sca/config/sca.config`

This is a bash script that exports variables. Key settings:

```bash
# Identity
export name_default=harley              # CA name
export caps_name_default="Harley Systems"
export domain_default=.systems

# CA Settings
export ca_bits_default=2048
export ca_use_security_key_default=true
export ca_security_key_type_default=yubikey
export ca_security_key_id_default="5414483"
export ca_pkcs11_id_default="05"        # YubiKey slot 82
export ca_yubikey_pin_policy_default=always
export ca_yubikey_touch_policy_default=always

# SubCA Settings
export subca_default=aharon
export subca_bits_default=2048
export subca_use_security_key_default=true
export subca_pkcs11_id_default="02"     # YubiKey slot 9c
export subca_yubikey_pin_policy_default=once

# Service Settings
export service_default=vpn
export service_bits_default=2048
export service_use_security_key_default=false
```

### File Path Conventions

Keys and certificates are stored in:
```
~/.sca/keys/<ca_name>/<subca_name>/<entity_type>/
    ├── private/     # Private keys
    ├── public/      # Public keys
    ├── requests/    # CSRs
    └── signed/      # Signed certificates
```

### OpenSSL Configuration

Template: `~/.sca/config/openssl_template.ini` (auto-generated)

Contains X.509 extension profiles for each entity type, CA signing policies, and PKCS#11 engine settings.

## Source Code Structure (for development)

```
src/
├── sca.sh                    # Main entry point
├── run.sh                    # Command dispatcher
├── <command>/                # Command implementations
│   ├── <command>.sh          # Command dispatcher
│   ├── complete_bash.sh      # Bash completion
│   ├── help/                 # Help text files
│   └── <subcommand>/
│       ├── <command>_<subcommand>.sh
│       └── help/
│           ├── command_title.txt
│           ├── abstract.txt
│           ├── syntax.txt
│           ├── options.txt
│           └── further_read.txt
├── scripts/build-help.sh         # Help text build script
├── Makefile                      # Build system (GNU Make macros)
├── build/                        # Generated files (gitignored)
└── docs/                         # Documentation
```

### Build System

```bash
make              # Build to build/sca.sh
make clean        # Remove build artifacts
make deploy       # Install to ~/bin with bash completion
make deploy INSTALL_DIR=/usr/local/bin  # Custom install location
```

### Code Conventions

- Functions: `<command>_<subcommand>()` (e.g., `create_key()`)
- Help functions: `<command>_<subcommand>_help()`
- Logging: `log_detailed` for debug, `log_verbose` for verbose
- Errors: `error "message" exit_code`
- Entity variables: `${entity}_crt_file`, `${entity}_key_file`, etc.

### Adding a New Subcommand

1. Create `src/<command>/<subcommand>/` with implementation and help files
2. Add to `*_SUBCMDS` list in Makefile
3. Update dispatcher in `src/<command>/<command>.sh`
4. Update `src/<command>/complete_bash.sh`
5. Run `make deploy` to build and install

### Makefile Macro Pattern

```makefile
# Subcommand list - just add to this:
EXPORT_SUBCMDS := crt_pub_ssh csr p12

# Macros generate help and build rules automatically
$(eval $(call build_help,export,p12))
$(eval $(call build_subcmd,export,p12))
```

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| `error: key file not found` | Run `sca create key <entity>` first |
| `error: csr file not found` | Run `sca create csr <entity>` first |
| YubiKey PIN prompt fails | Check PIN file at `~/.sca/keys/.../private/...-yubikey-pin.txt` |
| `PKCS#11 engine not found` | Install `libengine-pkcs11-openssl` |
| `ykcs11 not found` | Install `ykcs11` or `yubico-piv-tool` |
| YubiKey not detected | Run `sca security_key wait_for`, then retry |
| Config not loading | Check `~/.sca/config/sca.config` exists, run `sca config create` |

### Debugging

```bash
sca -v <command>    # Verbose output
sca -d <command>    # Detailed debug output
sca security_key info           # Check YubiKey slot contents
sca security_key verify <entity> # Test YubiKey signing
sca config get ca               # Check CA configuration
sca config get subca            # Check SubCA configuration
sca config get service          # Check service configuration
sca config resolve              # Check resolved file paths
```

## Important Notes for Claude

1. **Always check current config** before suggesting commands - query each entity separately: `sca config get ca`, `sca config get subca`, `sca config get service`, etc. There is NO single command to dump all config.
2. **Entity order matters**: Create key -> Create CSR -> Approve (signs CSR + creates crt + pub + ssh + exports bundle)
3. **YubiKey operations require physical presence** - the user must have the YubiKey inserted
4. **PIN prompts are interactive** - warn the user they'll need to enter their PIN
5. **Root CA operations may require offline machine** - don't assume CA key is available
6. **The `--force` flag** overwrites existing files without confirmation
7. **After source changes**, remind user to run `make deploy`
8. **Config is bash** - `sca.config` is sourced as a bash script, variables are exported

## Keywords for Detection

SCA, Simple Certificate Authority, PKI, certificate authority, X.509, SSL, TLS, CSR, certificate signing request, private key, public key, YubiKey, PKCS#11, PIV, security key, hardware token, OpenSSL, SubCA, root CA, service certificate, host certificate, user certificate, approve CSR, sign certificate, export certificate, p12, PKCS#12, SSH key, air-gapped, offline CA, certificate chain, trust chain, ykcs11, piv-tool, CRL, certificate revocation list, revoke certificate, revocation

