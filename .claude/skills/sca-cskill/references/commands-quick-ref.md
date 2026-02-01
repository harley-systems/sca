# SCA Commands Quick Reference

## Certificate Lifecycle

```
create key → create csr → approve (creates crt + pub + pub_ssh + exports)
```

## All Commands at a Glance

```bash
# Configuration (get/set REQUIRE entity: ca|subca|user|host|service)
sca config get <entity>          # Get entity config (NO "get all" exists!)
sca config set <entity> <value>  # Set entity name (positional mode)
sca config set <entity> <k> <v>  # Set entity setting (key-value mode)
sca config create                # Create default config
sca config load <file>           # Load config from file
sca config save <file>           # Save config to file
sca config reset                 # Reset to defaults
sca config resolve               # Show resolved file paths

# Create security documents
sca create key <entity>          # Generate private key
sca create csr <entity>          # Generate CSR
sca create crt <entity>          # Create certificate from CSR
sca create pub <entity>          # Extract public key
sca create pub_ssh <entity>      # Extract SSH public key
sca create crt_pub_ssh <entity>  # All-in-one: crt + pub + ssh

# Approve/sign
sca approve <entity> [entity_id]  # Sign CSR (NO "csr" subcommand! SubCA signs svc/host/user, CA signs subca)
sca approve <entity> -f           # Force (overwrite existing cert)
sca approve <entity> -s ca        # Override signing entity

# Display
sca display crt <entity>         # Show certificate details
sca display csr <entity>         # Show CSR details
sca display p12 <entity>         # Show PKCS#12 contents

# Export
sca export crt_pub_ssh <entity>  # Export cert bundle as archive
sca export csr <entity>          # Export CSR
sca export p12 <entity>          # Export PKCS#12

# Import
sca import <entity>              # Import from external source

# Request (for remote signing)
sca request <entity>             # Create signing request package

# List entities
sca list cas                     # List CAs
sca list subcas                  # List SubCAs
sca list services                # List services
sca list hosts                   # List hosts
sca list users                   # List users
sca list configs                 # List config files

# YubiKey / Security Key
sca security_key info            # Show all PIV slots
sca security_key id              # Get serial number
sca security_key init            # Initialize PIV (set PIN/PUK)
sca security_key upload <entity> # Upload key+cert to YubiKey
sca security_key get_crt <entity># Get cert from YubiKey
sca security_key verify <entity> # Test signing with key
sca security_key wait_for        # Wait for key insertion

# Initialize
sca init demo [path]             # Create demo CA structure
sca init openssl_ca_db           # Initialize OpenSSL database
sca init sca_usb_stick           # Create bootable USB
sca init yubikey                 # Initialize YubiKey PIV

# Other
sca install                      # Install prerequisites
sca test                         # Run tests
sca completion                   # Generate bash completion
```

## Entity Types

| Entity | Signed By | Default Key Storage |
|--------|-----------|-------------------|
| `ca` | Self-signed | Offline USB |
| `subca` | `ca` | YubiKey slot 9c |
| `service` | `subca` | Filesystem |
| `host` | `subca` | Filesystem |
| `user` | `subca` | Filesystem |

## Global Options

```bash
sca -v ...    # Verbose
sca -d ...    # Detailed debug
sca -h ...    # Help
sca -c <file> # Use alternate config
```
