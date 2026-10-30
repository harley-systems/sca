### Configuration Keys

| Key | Description | Example |
|-----|-------------|---------|
| `ca` | CA name (organization) | `mycompany` |
| `subca` | Sub-CA name (administrator) | `admin` |
| `service` | Current service name | `gitlab` |
| `host` | Current host name | `server1` |
| `user` | Current user name | `john` |
| `domain` | Domain suffix | `.mycompany.com` |

**Additional keys:**

| Key | Description | Default |
|-----|-------------|---------|
| `ca_bits` | CA key size | `4096` |
| `subca_bits` | Sub-CA key size | `4096` |
| `service_bits` | Service key size | `2048` |
| `host_bits` | Host key size | `2048` |
| `user_bits` | User key size | `2048` |

See the [Configuration Reference](../configuration.md) for the configuration files.
