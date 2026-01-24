# SSH Integration

[← Back to README](../README.md)

Using PKI certificates for SSH authentication, including YubiKey-based access.

## Overview

SSH can authenticate using:
1. **Password** - Least secure, disabled on production systems
2. **SSH keys** - Standard public/private key pairs
3. **Certificates** - CA-signed keys (most scalable)
4. **PKCS#11** - Hardware tokens like YubiKey

This guide covers using your PKI certificates for SSH access.

## YubiKey SSH Authentication

### Extract SSH Public Key from YubiKey

```bash
ssh-keygen -D /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so -e
```

Output:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA... PIV AUTH pubkey
```

### Add to Remote Host

Add the public key to the remote host's `~/.ssh/authorized_keys`:

```bash
# On the remote host
echo "ssh-rsa AAAAB3... harley@yubikey" >> ~/.ssh/authorized_keys
```

### Connect Using YubiKey

```bash
ssh -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so user@remotehost
```

You'll be prompted for the YubiKey PIN on first use.

## SSH Agent Integration

For convenience, add the YubiKey to ssh-agent:

```bash
# Start ssh-agent if not running
eval $(ssh-agent)

# Add YubiKey
ssh-add -s /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

# Verify
ssh-add -L
```

Now you can SSH normally:

```bash
ssh user@remotehost
```

### Persistent Configuration

Add to `~/.ssh/config`:

```
Host *
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
```

Or for specific hosts:

```
Host *.sb.com
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
    User admin
```

## Certificate-Based SSH (CA Trust)

Instead of adding individual keys to each host, configure hosts to trust the CA.

### Server Configuration

On each SSH server, edit `/etc/ssh/sshd_config`:

```
# Trust certificates signed by our CA
TrustedUserCAKeys /etc/ssh/trusted-ca.pub

# Disable password authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
```

Create the trusted CA file:

```bash
# Extract public key from CA certificate
openssl x509 -pubkey -noout \
  -in ~/.sca/keys/sb/sb-ca-crt.pem \
  > /tmp/ca-pub.pem

# Convert to SSH format
ssh-keygen -i -m PKCS8 -f /tmp/ca-pub.pem > /etc/ssh/trusted-ca.pub
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### User Certificates

Users with certificates signed by the trusted CA can now authenticate:

```bash
# Create SSH public key from user certificate
sca create pub_ssh user

# Or manually
openssl x509 -pubkey -noout -in user-crt.pem > user-pub.pem
ssh-keygen -i -m PKCS8 -f user-pub.pem > user.pub
```

## Agent Forwarding

Forward your YubiKey authentication to remote hosts:

```bash
# Enable agent forwarding
ssh -A user@jumphost

# On jumphost, you can now SSH to other hosts
ssh user@internalhost
```

### Security Warning

Only use agent forwarding to trusted hosts. A compromised jumphost could use your forwarded credentials.

Safer alternative - use ProxyJump:

```
Host internal
    HostName internalhost.sb.com
    User admin
    ProxyJump jumphost.sb.com
```

## Ansible Integration

Use YubiKey for Ansible SSH connections:

```bash
# Start ssh-agent with YubiKey
eval $(ssh-agent)
ssh-add -s /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

# Run Ansible
ansible-playbook -i development.yml playbook.yml
```

Or in `ansible.cfg`:

```ini
[defaults]
private_key_file = /path/to/key
transport = smart

[ssh_connection]
ssh_args = -o PKCS11Provider=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
```

## Git SSH with YubiKey

For Git operations over SSH:

```bash
# Add YubiKey to agent
ssh-add -s /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

# Configure Git to use SSH
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Clone repository
git clone git@github.com:user/repo.git
```

## Scripts and Automation

### Wrapper Script

Create `~/bin/sshpiv`:

```bash
#!/bin/bash
ssh -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so "$@"
```

```bash
chmod +x ~/bin/sshpiv
sshpiv user@host
```

### Environment Setup

Add to `~/.bashrc`:

```bash
# Start ssh-agent if not running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent)
fi

# Function to add YubiKey
add-yubikey() {
    ssh-add -s /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
}

# Alias for PIV SSH
alias sshpiv='ssh -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'
```

## Troubleshooting

### Agent Has No Identities

```bash
# Check agent status
ssh-add -l

# Add YubiKey
ssh-add -s /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
```

### Permission Denied

1. Check the public key is in `authorized_keys`
2. Check file permissions:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```
3. Check SSH server logs:
   ```bash
   sudo tail -f /var/log/auth.log
   ```

### PKCS#11 Module Not Found

Find the correct path:

```bash
find /usr -name "opensc-pkcs11.so" 2>/dev/null
```

### YubiKey Not Responding

```bash
# Restart pcscd
sudo systemctl restart pcscd

# Check YubiKey status
ykman info
```

### Debug Connection

```bash
ssh -vvv -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so user@host
```

Look for:
- `Offering public key: ... PIV AUTH pubkey`
- `Server accepts key: ...`

---

## See Also

- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [Procedures](procedures.md) - Certificate creation procedures
- [Command Reference](commands.md) - Command reference
