**Examples:**

```bash
# the CA line for sshd's TrustedUserCAKeys and known_hosts' @cert-authority
sca create pub_ssh subca

# certify the current user's key, valid for the default 52 weeks
sca create ssh_crt user

# certify a host key for a week, under two names
sca create ssh_crt --validity +1w --principals black.harley.systems,black host

# certify a FIDO2 key made with ssh-keygen -t ed25519-sk
sca create ssh_crt --pub ~/.ssh/id_ed25519_sk.pub user
```

See [SSH integration](../ssh-integration.md#certificate-based-ssh-ca-trust).
