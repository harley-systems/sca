# SCA Demo

Animated terminal demo showing SCA usage.

## Prerequisites

### VHS

[VHS](https://github.com/charmbracelet/vhs) is a terminal recording tool.

```bash
# Install Go 1.22+ first, then:
go install github.com/charmbracelet/vhs@latest
```

### ttyd

VHS requires [ttyd](https://github.com/tsl0922/ttyd) 1.7.2 or later.

```bash
# Download from GitHub releases (apt version is often too old)
curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd
```

### SCA with demo data

The demo requires sca to be installed with existing CA hierarchy and user certificates.

```bash
sca init demo
```

## Rendering

From the `docs/demo/` directory:

```bash
cd docs/demo
vhs demo.tape
```

This generates `demo.gif`.

## Demo content

The current demo shows:
1. Help overview
2. Listing users
3. Setting user context
4. Displaying user certificate
5. Exporting PKCS#12 bundle for mobile VPN
6. Verifying p12 contents
