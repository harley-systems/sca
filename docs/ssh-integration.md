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

This page covers the **PIV** (PKCS#11) method, which is the one SCA implements. A
YubiKey can also do SSH via its OpenPGP applet (gpg-agent) or as a FIDO2 security key
(`ed25519-sk`). See [SSH with a YubiKey: Choosing a Method](ssh-yubikey-options.md).

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

Instead of adding each user's key to every host's `authorized_keys`, configure
the hosts to trust the CA, and give each user an **OpenSSH certificate** signed
by it. sshd only accepts OpenSSH certificates (the kind `ssh-keygen -s` makes)
here: an X.509 certificate, or a public key taken out of one, does not
authenticate over SSH.

`sca create ssh_crt` signs the OpenSSH certificates with the sub-CA key (or the
CA key). When that key is on a YubiKey, sca signs through PKCS#11 (ykcs11), with
the PIN read from the PIN file, and you touch the key if its touch policy asks
for it.

### The CA Line

The public key servers and clients trust is the signing entity's `pub_ssh`
file:

```bash
sca create pub_ssh subca
# ~/.sca/keys/<ca>/<subca>/<ca>-<subca>-subca-pub.ssh
```

### Server Configuration

Copy that file to each SSH server as `/etc/ssh/trusted-ca.pub`, and edit
`/etc/ssh/sshd_config`:

```
# Trust user certificates signed by our CA
TrustedUserCAKeys /etc/ssh/trusted-ca.pub

# Disable password authentication
PasswordAuthentication no
KbdInteractiveAuthentication no
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### User Certificates

Sign the user's OpenSSH public key:

```bash
# the user's own key, from sca create pub_ssh user
sca create ssh_crt user

# or any OpenSSH public key: a FIDO2 key, a gpg-agent key, a YubiKey PIV key
sca create ssh_crt --pub ~/.ssh/id_ed25519_sk.pub user
```

The certificate is written to `<ca>-<subca>-<user>-pub-ssh-cert.pub` in the
user's folder. Its principal is the user's account id (the `user` setting),
which has to match the login name on the server; use `--principals a,b` to name
others. It is valid for `ssh_crt_validity` (52 weeks by default), or for
`--validity` (for example `+1w`).

`ssh-keygen -L -f <certificate>` shows the key ID, principals, validity and the
signing CA.

On the client, put the certificate next to the private key as
`<private key>-cert.pub` (for example `~/.ssh/id_ed25519_sk-cert.pub`), and ssh
picks it up. For a key held by an agent or a token, point to it in
`~/.ssh/config`:

```
Host *.example.com
    CertificateFile ~/.ssh/user-cert.pub
```

### Host Certificates

A host certificate lets clients trust the host without a `known_hosts` entry
per host:

```bash
sca create ssh_crt host
```

Its principal is the host's full DNS name (`<host>.<name><domain>`). Copy the
certificate to the host and add to its `sshd_config`:

```
HostCertificate /etc/ssh/<ca>-<subca>-<host>-pub-ssh-cert.pub
```

On each client, add the CA line to `~/.ssh/known_hosts`:

```
@cert-authority *.example.com <contents of the subca pub_ssh file>
```

`sca create ssh_crt` prints these lines, filled in, after signing.

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

- [SSH with a YubiKey: Choosing a Method](ssh-yubikey-options.md) - PIV vs OpenPGP vs FIDO2
- [YubiKey Setup](yubikey.md) - Hardware key configuration
- [Procedures](procedures.md) - Certificate creation procedures
- [Command Reference](commands.md) - Command reference
