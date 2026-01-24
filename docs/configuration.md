# Configuration Reference

[← Back to README](../README.md)

Detailed reference for SCA configuration files, directory structure, and customization options.

## Directory Structure

SCA stores all configuration and data in `~/.sca/`:

```
~/.sca/
├── config/                      # Configuration files
│   ├── sca.config               # Main configuration
│   ├── conventions.sh           # Naming conventions
│   └── openssl_template.ini     # OpenSSL config template
│
├── keys/                        # Certificates and keys
│   └── <ca>/                    # CA name (e.g., "mycompany")
│       ├── <ca>-ca-key.pem      # Root CA private key
│       ├── <ca>-ca-crt.pem      # Root CA certificate
│       └── <subca>/             # Sub-CA name (e.g., "admin")
│           ├── <subca>-subca-key.pem
│           ├── <subca>-subca-crt.pem
│           └── <service>/       # Service certificates
│               ├── <service>-key.pem
│               ├── <service>-crt.pem
│               └── <service>-csr.pem
│
├── transfer/                    # Export/import staging area
├── downloads/                   # Downloaded files (ISO images)
├── log                          # Operation log file
└── demo/                        # Demo CA (if created)
```

## Configuration File (sca.config)

The main configuration file is a bash script that exports default values.

### Location

```
~/.sca/config/sca.config
```

### Format

```bash
#################################################
# settings

# Verbosity level: none, v (verbose), vv (debug)
export verbosity_default=

# Organization/CA name
export name_default=mycompany

# Capitalized name (for certificate subjects)
export caps_name_default=MyCompany

# Domain suffix
export domain_default=.mycompany.com

# Key sizes (bits)
export ca_bits_default=4096
export subca_bits_default=4096
export service_bits_default=2048
export host_bits_default=2048
export user_bits_default=2048

# Current entity names
export subca_default=admin
export service_default=webapp
export host_default=server1
export user_default=john

# User certificate details
export user_name_default=
export user_surname_default=
export user_given_name_default=
export user_initials_default=

#################################################
# folder settings

export demo_folder_default=~/.sca/demo/
export key_folder_default=~/.sca/keys/
export transfer_folder_default=~/.sca/transfer/
export sca_folder_default=~/bin/
export sca_conf_folder_default=~/.sca/config/
```

### Modifying Configuration

Use `sca config set` to modify values:

```bash
sca config set ca mycompany
sca config set domain .mycompany.com
sca config set subca admin
```

Or edit the file directly:

```bash
vi ~/.sca/config/sca.config
```

## Naming Conventions (conventions.sh)

Controls how file paths are constructed from entity names.

### Location

```
~/.sca/config/conventions.sh
```

### Key Variables

```bash
# CA certificate path pattern
ca_crt_file=${key_folder}${name}/${name}-ca-crt.pem

# Sub-CA certificate path pattern
subca_crt_file=${key_folder}${name}/${subca}/${subca}-subca-crt.pem

# Service certificate path pattern
service_crt_file=${key_folder}${name}/${subca}/${service}/${service}-crt.pem
```

## OpenSSL Template (openssl_template.ini)

The OpenSSL configuration template used for all certificate operations.

### Location

```
~/.sca/config/openssl_template.ini
```

### Sections

| Section | Purpose |
|---------|---------|
| `[ca]` | CA configuration |
| `[req]` | Certificate request defaults |
| `[ca_ext]` | Root CA certificate extensions |
| `[subca_ext]` | Sub-CA certificate extensions |
| `[server_ext]` | Server/service certificate extensions |
| `[user_ext]` | User certificate extensions |

### Customization Examples

#### Change Default Key Size

Edit the `default_bits` in the `[req]` section:

```ini
[req]
default_bits            = 4096
```

#### Add Custom Extensions

Add to the appropriate extension section:

```ini
[server_ext]
# ... existing extensions ...
# Add custom OID
1.2.3.4.5.6.7.8.9 = ASN1:UTF8String:Custom Value
```

#### Modify Subject Fields

Adjust the `[req_distinguished_name]` section:

```ini
[req_distinguished_name]
countryName             = Country Name (2 letter code)
countryName_default     = US
stateOrProvinceName     = State
stateOrProvinceName_default = California
localityName            = City
localityName_default    = San Francisco
organizationName        = Organization
organizationName_default = My Company Inc
```

#### Change Certificate Validity

Modify `default_days` in the `[CA_default]` section:

```ini
[CA_default]
default_days    = 365      # 1 year for end-entity certs
```

For CA certificates, validity is set during creation.

## Environment Variables

SCA respects these environment variables:

| Variable | Description |
|----------|-------------|
| `SCA_CONFIG_FILE` | Override config file location |
| `SCA_KEY_FOLDER` | Override keys folder location |
| `SCA_LOG_FILE` | Override log file location |

## Certificate Extensions

### Root CA Extensions

```ini
[ca_ext]
basicConstraints        = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always, issuer:always
```

### Sub-CA Extensions

```ini
[subca_ext]
basicConstraints        = critical, CA:true, pathlen:1
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
extendedKeyUsage       = serverAuth, clientAuth
```

### Server Certificate Extensions

```ini
[server_ext]
basicConstraints        = CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectAltName         = @alt_names
```

### User Certificate Extensions

```ini
[user_ext]
basicConstraints        = CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = clientAuth, emailProtection
```

## Backup and Restore

### Backup Configuration

```bash
tar -czf sca-config-backup.tar.gz ~/.sca/config/
```

### Backup Everything (including keys)

```bash
tar -czf sca-full-backup.tar.gz ~/.sca/
```

**Security:** Encrypt backups containing private keys:

```bash
tar -cz ~/.sca/ | gpg --symmetric -o sca-backup.tar.gz.gpg
```

### Restore

```bash
# Restore configuration only
tar -xzf sca-config-backup.tar.gz -C ~/

# Restore from encrypted backup
gpg -d sca-backup.tar.gz.gpg | tar -xz -C ~/
```

## Multiple Configurations

Use different configurations for different CAs:

```bash
# Use alternate config file
sca -c ~/work-ca/sca.config config get

# Or set environment variable
export SCA_CONFIG_FILE=~/work-ca/sca.config
sca config get
```

## Troubleshooting

### Configuration Not Loading

Check file permissions:

```bash
ls -la ~/.sca/config/
# Files should be readable by your user
```

### Wrong Paths

Verify configuration:

```bash
sca config get
sca config resolve
```

### Reset to Defaults

```bash
# Reset values only
sca config reset

# Recreate all config files
sca config create --recreate all
```

---

## See Also

- [Command Reference](commands.md) - All sca commands
- [Procedures](procedures.md) - Step-by-step guides
- [YubiKey Setup](yubikey.md) - Hardware key configuration
