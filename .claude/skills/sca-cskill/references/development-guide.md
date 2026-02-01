# SCA Development Guide

## Build & Deploy

```bash
make              # Build to build/sca.sh
make clean        # Remove build artifacts
make deploy       # Install to ~/bin/sca with bash completion
```

## Project Structure

```
src/
├── sca.sh                    # Main entry point (parses global options, loads config)
├── run.sh                    # Command dispatcher (case statement)
├── common/                   # Shared utilities
│   └── help/help.txt         # Help template with placeholders
├── <command>/
│   ├── <command>.sh          # Command dispatcher
│   ├── complete_bash.sh      # Bash completion for this command
│   ├── help/                 # Command-level help files
│   └── <subcommand>/
│       ├── <command>_<subcommand>.sh   # Implementation
│       └── help/
│           ├── command_title.txt       # One-line title
│           ├── abstract.txt            # 2-3 sentence description
│           ├── syntax.txt              # Usage syntax
│           ├── options.txt             # Options (comma-separated)
│           └── further_read.txt        # Cross-references
```

## Adding a New Subcommand

### Step 1: Create directory and files

```bash
mkdir -p src/<command>/<newsubcmd>/help
```

### Step 2: Write implementation

File: `src/<command>/<newsubcmd>/<command>_<newsubcmd>.sh`

```bash
<command>_<newsubcmd>() {
  local OPTS=$(getopt -o hf --long help,force -n "sca <command> <newsubcmd>" -- "$@")
  if [ $? != 0 ]; then error "failed parsing options." 1; fi
  eval set -- "$OPTS"

  local force=false
  while true; do
    case "$1" in
      -h | --help) <command>_<newsubcmd>_help; return;;
      -f | --force) force=true; shift;;
      -- ) shift; break;;
      * ) break;;
    esac
  done

  # Implementation here
  log_detailed "start <command> <newsubcmd>"

  # ... your code ...

  log_detailed "finish"
}

<command>_<newsubcmd>_help() {
  echo "@@@HELP@@@"
}
```

### Step 3: Create help files

```bash
echo "One-line description" > src/<command>/<newsubcmd>/help/command_title.txt
echo "Two to three sentence abstract." > src/<command>/<newsubcmd>/help/abstract.txt
echo "sca <command> <newsubcmd> [options] <entity>" > src/<command>/<newsubcmd>/help/syntax.txt
echo "-h, --help, -f, --force" > src/<command>/<newsubcmd>/help/options.txt
touch src/<command>/<newsubcmd>/help/further_read.txt
```

### Step 4: Update Makefile

Add to the subcommand list:

```makefile
<COMMAND>_SUBCMDS := existing1 existing2 newsubcmd
```

The macros handle the rest automatically:
```makefile
$(foreach s,$(<COMMAND>_SUBCMDS),$(eval $(call build_help,<command>,$(s))))
$(foreach s,$(<COMMAND>_SUBCMDS),$(eval $(call build_subcmd,<command>,$(s))))
```

### Step 5: Update command dispatcher

In `src/<command>/<command>.sh`, add to the case statement:

```bash
case "$subcmd" in
  existing1|existing2|newsubcmd)
    eval <command>_$subcmd "$@"
    ;;
esac
```

### Step 6: Update bash completion

In `src/<command>/complete_bash.sh`, add the new subcommand to the completion list.

### Step 7: Build and test

```bash
make deploy
sca <command> <newsubcmd> --help
sca <command> <newsubcmd> <entity>
```

## Makefile Macros

### build_help macro

Generates help text by substituting placeholders in the help template:

```makefile
define build_help
$(if $(2),build/$(1)/$(2)/help/help.txt,build/$(1)/help/help.txt): build/common/help/help.txt
	@mkdir -p $$(dir $$@)
	./scripts/build-help.sh $$@ src/$(1)$(if $(2),/$(2))/help $(if $(2),$(1),)
endef
```

### build_subcmd macro

Builds subcommand scripts by inserting help text:

```makefile
define build_subcmd
build/$(1)/$(2)/$(1)_$(2).sh: src/$(1)/$(2)/$(1)_$(2).sh build/$(1)/$(2)/help/help.txt
	@mkdir -p $$(dir $$@)
	sed -e '/@@@HELP@@@/{r build/$(1)/$(2)/help/help.txt' -e 'd}' $$< > $$@
endef
```

### Help placeholders

The build system substitutes these in help templates:
- `@@@HELP@@@` - Full help text (in script files)
- `@@@COMMAND TITLE@@@` - From command_title.txt
- `@@@ABSTRACT@@@` - From abstract.txt
- `@@@SYNTAX@@@` - From syntax.txt
- `@@@OPTIONS@@@` - From options.txt
- `@@@FURTHER READ@@@` - From further_read.txt

## Code Conventions

- Functions: `<command>_<subcommand>()` (e.g., `create_key()`)
- Help: `<command>_<subcommand>_help()`
- Debug logging: `log_detailed "message"`
- Verbose logging: `log_verbose "message"`
- Errors: `error "message" exit_code`
- Entity paths: `${entity}_crt_file`, `${entity}_key_file`, `${entity}_csr_file`
- Option parsing: `getopt` with short and long options

## Key Source Files

| File | Lines | Purpose |
|------|-------|---------|
| `src/sca.sh` | 203 | Main entry, global options, config loading |
| `src/run.sh` | 2 | Command routing |
| `src/create/key/create_key.sh` | 216 | Key generation |
| `src/create/csr/create_csr.sh` | 150+ | CSR creation |
| `src/create/crt/create_crt.sh` | 200+ | Certificate creation |
| `src/approve/approve.sh` | 160 | CSR signing |
| `src/security_key/security_key.sh` | 260 | YubiKey dispatcher + helpers |
| `src/config/create/default_sca_config.sh` | 173 | Default config values |
| `src/config/create/default_conventions.sh` | 545 | File path conventions |
| `src/config/create/default_openssl_config.ini` | 1828 | OpenSSL template |
| `Makefile` | 304 | Build system |
| `scripts/build-help.sh` | 57 | Help text processor |
