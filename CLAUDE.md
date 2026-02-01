# Claude Instructions for SCA

## Claude Skill

A comprehensive Claude Code skill is available at `.claude/skills/sca-cskill/` with detailed command reference, YubiKey integration docs, and development guides. The skill activates automatically when working with SCA commands and PKI operations.

## Project Overview

SCA (Simple Certificate Authority) is a bash-based CLI tool that simplifies PKI (Public Key Infrastructure) operations. It wraps OpenSSL complexity into simple commands and supports YubiKey hardware security keys for protecting CA private keys.

## Architecture

```
Root CA (offline, air-gapped)
    └── Sub-CA (on YubiKey hardware token)
            ├── Service certificates (TLS/HTTPS)
            ├── Host certificates
            └── User certificates (authentication)
```

## Key Concepts

- **Entities**: `ca`, `subca`, `user`, `host`, `service` - the types of certificates SCA manages
- **PKCS#11**: Interface for hardware security tokens (YubiKey uses ykcs11 library)
- **PIV Slots**: YubiKey storage locations (9a=auth, 9c=signing, 9d=key mgmt, 9e=card auth, 82-95=retired)

## Project Structure

```
sca/
├── src/                      # Source files
│   ├── sca.sh                # Main entry point with help
│   ├── run.sh                # Command dispatcher
│   ├── <command>/            # Command implementations
│   │   ├── <command>.sh      # Command dispatcher
│   │   ├── complete_bash.sh  # Bash completion
│   │   ├── help/             # Help text files
│   │   └── <subcommand>/     # Subcommand implementation
│   │       ├── <command>_<subcommand>.sh
│   │       └── help/
├── scripts/                  # Build helper scripts
│   └── build-help.sh         # Help text generator
├── build/                    # Generated files (gitignored)
├── docs/                     # Documentation
└── Makefile                  # Build system using macros
```

## Build System

The Makefile uses GNU Make macros to reduce repetition. Key patterns:

```makefile
# Adding a new subcommand - just add to the list:
EXPORT_SUBCMDS := crt_pub_ssh csr p12

# Macros automatically generate help and build rules
$(eval $(call build_help,export,p12))
$(eval $(call build_subcmd,export,p12))
```

### Build Commands

```bash
make              # Build sca to build/sca.sh
make clean        # Remove build artifacts
make deploy       # Install to ~/bin with bash completion
make deploy INSTALL_DIR=/usr/local/bin  # Custom install location
```

## Configuration

- User config: `~/.sca/config/sca.config`
- Keys/certs: `~/.sca/keys/<ca>/<subca>/<entity>/`
- OpenSSL templates: `~/.sca/config/openssl_template.ini`

### Important Config Variables

```bash
ca_pkcs11_id_default="05"      # ykcs11 ID for CA (maps to slot 82)
subca_pkcs11_id_default="02"   # ykcs11 ID for SubCA (maps to slot 9c)
```

### ykcs11 PKCS#11 ID to YubiKey Slot Mapping

```
01 → 9a (PIV Authentication)
02 → 9c (Digital Signature) ← SubCA default
03 → 9d (Key Management)
04 → 9e (Card Authentication)
05 → 82 (Retired Key 1) ← CA default
```

## Common Workflows

### Issue a certificate (user has YubiKey with SubCA)

```bash
sca config set service myapp
sca create key service
sca create csr service
sca approve service    # Signs CSR, creates crt + pub + pub_ssh, exports bundle
```

**Note:** `sca approve` internally calls `create crt_pub_ssh` and `export crt_pub_ssh`, so no separate create/export steps are needed.

### YubiKey operations

```bash
sca security_key info       # Show all PIV slots
sca security_key verify ca  # Test signing with CA key
sca security_key id         # Get YubiKey serial number
```

## Testing Changes

```bash
# After making changes:
make deploy
sca <command> --help        # Verify help text
sca <command> <args>        # Test functionality
```

## Adding New Features

### New Subcommand

1. Create `src/<parent>/<subcmd>/` directory with implementation and help files
2. Add to `*_SUBCMDS` list in Makefile
3. Update parent dispatcher in `src/<parent>/<parent>.sh`
4. Update `src/<parent>/complete_bash.sh` for tab completion
5. Document in `docs/commands.md`

See CONTRIBUTING.md for detailed instructions.

### Help File Placeholders

The build system substitutes these in help templates:
- `@@@HELP@@@` - Full help text (in script files)
- `@@@COMMAND TITLE@@@`, `@@@ABSTRACT@@@`, `@@@SYNTAX@@@`, etc.

## Code Conventions

- Functions named `<command>_<subcommand>()` (e.g., `create_key()`)
- Help functions named `<command>_<subcommand>_help()`
- Use `log_detailed` for debug output
- Use `error "message" exit_code` for errors
- Entity file paths: `${entity}_crt_file`, `${entity}_key_file`, etc.

## Documentation

- `docs/demo-walkthrough.md` - Complete tutorial with animated GIF
- `docs/commands.md` - Command reference
- `docs/yubikey.md` - YubiKey setup and troubleshooting
- `docs/procedures.md` - Step-by-step guides

## Debugging Tips

- Use `-v` (verbose) or `-d` (detailed) flags for debug output
- Check `~/.sca/config/sca.config` for configuration issues
- For YubiKey issues: `sca security_key info` and `sca security_key verify <entity>`
- PIN file location: `~/.sca/keys/<ca>/<subca>/private/<ca>-<subca>-<entity>-yubikey-pin.txt`
