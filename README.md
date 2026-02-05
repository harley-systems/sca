# SCA - Simple Certificate Authority

A command-line tool that makes PKI simple. Create and manage certificates with hardware security (YubiKey) support.

![SCA Demo](docs/demo/demo.gif)

## Why SCA?

OpenSSL is powerful but cryptic. Setting up a proper PKI usually means:
- Copy-pasting commands you don't understand
- Skipping security best practices because they're too complex
- Ending up with insecure self-signed certificates

SCA provides a simple interface to do PKI properly:

```bash
# Create a service certificate
sca config set service myapp
sca create key service
sca create csr service
sca approve service    # Signs with YubiKey
sca create crt service
```

## Features

- **Simple commands** - `create`, `approve`, `export`, `list`
- **YubiKey integration** - Hardware-protected private keys
- **Hierarchical CA** - Root CA → Sub-CA → Certificates
- **Offline root CA** - Keep root keys on air-gapped USB
- **SSH integration** - Use certificates for SSH authentication
- **Bash completion** - Tab completion for all commands
- **Claude Code skill** - AI-assisted PKI operations and guidance

## Installation

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install openssl opensc pcscd yubico-piv-tool

# Start smart card daemon
sudo systemctl enable --now pcscd
```

### Install SCA

#### From release (recommended)

```bash
# Download latest release
curl -L https://github.com/harley-systems/sca/releases/latest/download/sca -o ~/bin/sca
chmod +x ~/bin/sca

# Enable bash completion
curl -L https://github.com/harley-systems/sca/releases/latest/download/sca-completion.bash \
  -o ~/.local/share/bash-completion/completions/sca
```

#### From source

```bash
# Build
make

# Install system-wide
sudo cp build/sca.sh /usr/local/bin/sca

# Enable bash completion
echo 'source <(sca completion bash)' >> ~/.bashrc
```

## Quick Start

### 1. Initialize Your CA

```bash
# Set your organization name
sca config set ca mycompany
sca config set domain .mycompany.com

# Create root CA (do this offline for security)
sca create key ca
sca create crt ca
```

### 2. Setup Sub-CA on YubiKey

```bash
# Initialize YubiKey with new PIN/PUK
sca security_key init

# Create sub-CA
sca config set subca admin
sca create key subca
sca create csr subca
sca approve subca
sca create crt subca

# Upload to YubiKey
sca security_key upload subca
```

### 3. Issue Certificates

```bash
# Configure service
sca config set service webapp

# Create and sign certificate
sca create key service
sca create csr service
sca approve service    # Prompts for YubiKey PIN
sca create crt service

# Export for deployment
sca export crt_pub_ssh service
```

## Commands

| Command | Description |
|---------|-------------|
| `create` | Create keys, CSRs, certificates |
| `request` | Create signing request |
| `approve` | Approve/sign a CSR |
| `display` | Display certificate details |
| `export` | Export certificate bundles |
| `import` | Import certificates |
| `list` | List CAs, certificates, configs |
| `config` | Manage configuration |
| `security_key` | YubiKey management |
| `install` | Install prerequisites |
| `completion` | Shell completion scripts |

Run `sca <command> --help` for detailed usage.

## Documentation

- **[Demo Walkthrough](docs/demo-walkthrough.md)** - Complete tutorial from install to user certificate
- [Command Reference](docs/commands.md) - Detailed command documentation
- [YubiKey Setup](docs/yubikey.md) - Hardware security key configuration
- [Procedures](docs/procedures.md) - Step-by-step guides
- [SSH Integration](docs/ssh-integration.md) - Certificate-based SSH
- [Air-Gapped Operations](docs/air-gapped-operations.md) - Secure offline CA environment
- [Configuration Reference](docs/configuration.md) - Config files and customization
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

### Claude Code Integration

This repo includes a [Claude Code](https://claude.com/claude-code) skill that provides AI-assisted guidance for SCA operations.

**Automatic (project-level):** When you open this project in Claude Code, the skill activates automatically -- no installation needed.

**Manual install (global):** To use the skill outside this repo, install it from the [claude-skills](https://github.com/harley-systems/claude-skills) marketplace:

```
/plugin marketplace add harley-systems/claude-skills
```

Then install "sca-plugin" when prompted.

## Architecture

```
Root CA (offline, USB storage)
    │
    └── Sub-CA (on YubiKey)
            │
            ├── Service certificates
            ├── Host certificates
            └── User certificates
```

**Key storage:**
- Root CA private key → Offline USB (air-gapped)
- Sub-CA private key → YubiKey hardware token
- Service/host keys → Filesystem (Ansible-managed)

## Configuration

SCA stores configuration in `~/.sca/`:

```
~/.sca/
├── config/           # OpenSSL templates
└── keys/             # Certificates and keys
    └── <ca>/
        └── <subca>/
            └── <service>/
```

## Use Cases

### VPN Certificates
```bash
sca config set service vpn-server
sca create crt_pub_ssh service
# Deploy to StrongSwan
```

### HTTPS/TLS
```bash
sca config set service webapp
sca create crt_pub_ssh service
# Deploy to nginx/Apache
```

### SSH Authentication
```bash
sca config set user developer
sca create crt_pub_ssh user
sca create pub_ssh user
# Add to authorized_keys
```

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

Areas where help is appreciated:
- Certificate revocation (CRL generation)
- More shell completions (zsh, fish)
- Documentation improvements
- YubiKey diagnostics (see issues #9, #10, #11)

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

Built on:
- [OpenSSL](https://www.openssl.org/) - The cryptographic foundation
- [YubiKey](https://www.yubico.com/) - Hardware security
- [OpenSC](https://github.com/OpenSC/OpenSC) - Smart card tools
