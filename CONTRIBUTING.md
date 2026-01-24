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
3. Make your changes
4. Test your changes (`make && ./build/sca.sh test`)
5. Commit with a clear message
6. Push and open a Pull Request

### Code Style

- Shell scripts should pass `shellcheck`
- Use meaningful variable names
- Add comments for complex logic
- Follow existing patterns in the codebase

### Documentation

- Update docs if you change functionality
- Add examples for new features
- Keep the README.md current

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/sca.git
cd sca

# Build
make

# Run tests
./build/sca.sh test

# Test your changes
./build/sca.sh --help
```

## Areas for Contribution

- **PKCS#12 export** - Add `.p12` bundle export
- **Certificate revocation** - CRL generation and management
- **Shell completions** - Zsh, Fish support
- **Documentation** - Tutorials, examples, translations
- **Testing** - More test coverage

## Questions?

Open an issue for questions or discussion.
