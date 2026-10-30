**What it creates:**
- Root CA (key + self-signed certificate)
- Sub-CA (key + certificate signed by root)
- Sample service certificate
- Sample user certificate

**Example:**
```bash
# Create demo in default location (~/.sca/demo/)
sca init demo

# Create demo in custom location
sca init demo /tmp/sca-demo
```

This is useful for:
- Learning how sca works
- Testing certificate workflows
- Development and debugging
