# Contributing to SCA

Thank you for your interest in contributing to SCA!

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Include your OS, shell version, and SCA version
- Provide steps to reproduce the issue
- Include relevant error messages

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes following the patterns below
4. Test your changes (`make deploy && sca <your-command>`)
5. Commit with a clear message
6. Push and open a Pull Request

## Development Workflow

### Project Structure

```
sca/
├── src/                    # Source files
│   ├── sca.sh              # Main entry point
│   ├── common/             # Shared utilities
│   ├── <verb>/             # Top-level commands (create, export, etc.)
│   │   ├── <verb>.sh       # Command dispatcher
│   │   ├── complete_bash.sh # Bash completion for this command
│   │   ├── help/           # Help files for the command
│   │   └── <subcommand>/   # Subcommand implementation
│   │       ├── <verb>_<subcommand>.sh
│   │       └── help/       # Help files for subcommand
├── build/                  # Built artifacts (generated)
├── docs/                   # Documentation
└── Makefile                # Build system
```

### Adding a New Subcommand

For example, to add `sca export p12`:

#### 1. Create the directory structure

```bash
mkdir -p src/export/p12/help
```

#### 2. Create the implementation script

Create `src/export/p12/export_p12.sh`:

```bash
################################################################################
# Description of what this command does
#
# parameters
#   param1 - description
#
export_p12() {
  # Parse options with getopt
  local OPTS=`getopt -o hp: --long help,password: -n "export p12" -- "$@"`
  if [ $? != 0 ] ; then error "failed parsing options." 1; fi
  eval set -- "$OPTS"

  while true; do
    case "$1" in
      -h | --help )
        export_p12_help
        return
        ;;
      -p | --password )
        password="$2"
        shift 2
        ;;
      -- )
        shift
        break
        ;;
      * )
        break
        ;;
    esac
  done

  local entity=$1
  log_detailed "export_p12: start (entity=${entity})"

  # Implementation here...
  # Use variables like ${entity}_crt_file, ${entity}_key_file

  log_detailed "export_p12: finish"
}

export_p12_help() {
  echo "
@@@HELP@@@
  "
}
```

#### 3. Create help files

Create these files in `src/export/p12/help/`:

| File | Content |
|------|---------|
| `command_title.txt` | One-line description |
| `abstract.txt` | Detailed description paragraph |
| `syntax.txt` | Usage syntax and options |
| `options.txt` | Comma-separated list of options |
| `further_read.txt` | Additional references (see guidelines below) |

**Help file guidelines:**

- `command_title.txt` - Single line, no period at end (e.g., "Display PKCS#12 bundle contents")
- `abstract.txt` - 2-3 sentences explaining what the command does and when to use it
- `syntax.txt` - Include command syntax, arguments list, and options with descriptions
- `options.txt` - Comma-separated short and long options (e.g., "-p, --password, -h, --help")
- `further_read.txt` - Follow this pattern:
  - **Parent commands** (e.g., `display`, `config`, `export`): Add text pointing to subcommands
    - Example: "Run 'sca display <document_type> -h' for help on specific document types."
  - **Leaf commands** (e.g., `display crt`, `export p12`): Leave **empty** for consistency

#### 4. Update the parent command dispatcher

Edit `src/export/export.sh` to include the new subcommand in the case statement:

```bash
case "$document_type" in
  crt_pub_ssh|csr|p12)  # Add p12 here
    shift
    eval export_$document_type "$@"
    ;;
```

#### 5. Update bash completion

Edit `src/export/complete_bash.sh` to include the new subcommand in completions.

#### 6. Update the Makefile

The Makefile uses macros to generate build rules automatically. Simply add your new subcommand to the appropriate `*_SUBCMDS` list:

```makefile
# Find this line in the Makefile:
EXPORT_SUBCMDS := crt_pub_ssh csr

# Add your new subcommand:
EXPORT_SUBCMDS := crt_pub_ssh csr p12
```

That's it! The macros will automatically generate the help and build rules for your new subcommand.

#### 7. Update documentation

- Add the new command to `docs/commands.md`
- Update the Claude Code skill at `.claude/skills/sca-cskill/SKILL.md` and its quick reference at `.claude/skills/sca-cskill/references/commands-quick-ref.md`
- If publishing globally, also update the [claude-skills](https://github.com/harley-systems/claude-skills) marketplace repo

### Key Variables and Conventions

Entity file variables follow this pattern:
- `${entity}_crt_file` - Certificate file path
- `${entity}_key_file` - Private key file path
- `${entity}_csr_file` - CSR file path
- `${entity}_pub_file` - Public key file path
- `${entity}_transfer_files_folder` - Output folder for exports

Where `entity` is one of: `ca`, `subca`, `user`, `host`, `service`

### Build and Test

```bash
# Build and install to ~/bin (with bash completion)
make deploy

# Or specify a custom install location
make deploy INSTALL_DIR=/usr/local/bin COMPLETION_DIR=/etc/bash_completion.d

# Test your command
sca <verb> <subcommand> --help
sca <verb> <subcommand> <args>
```

## Code Style

- Shell scripts should pass `shellcheck`
- Use meaningful variable names
- Add comments for complex logic
- Use `log_detailed` for debug logging
- Use `error "message" exit_code` for errors
- Follow existing patterns in the codebase

## Documentation

- Update `docs/commands.md` if you change functionality
- Update the Claude Code skill (`.claude/skills/sca-cskill/`) to reflect command changes
- Add examples for new features
- Keep the README.md current

## Areas for Contribution

- **Certificate revocation** - CRL generation and management
- **Shell completions** - Zsh, Fish support
- **Documentation** - Tutorials, examples, translations
- **Testing** - More test coverage

## Questions?

Open an issue for questions or discussion.
