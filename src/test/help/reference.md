**Examples:**

```bash
# Run all tests (including QEMU air-gapped tests)
sca test

# Run only online tests (faster, no QEMU)
sca test --skip-air-gapped-tests

# Run tests for specific Ubuntu version
sca test 18.04.1-bionic
```

Each check prints `PASS <check>` or `FAIL <check>`:

1. `init demo` completes (in `~/.sca/test/demo/`, on a copy of your config, never using a security key)
2. a service key, CSR and certificate issued by the demo sub-CA pass `openssl verify` against the demo chain
3. `openssl version` is 3 or newer
4. the pkcs11 engine and OpenSC module files named in the config exist
5. `pcscd` is installed
6. `ykcs11` is installed (the `ykcs11_module` file exists)
7. `ykman` runs, if it is installed (otherwise reported as `SKIP`)

The air-gapped tests:
1. Rebuild the test USB image with `sca init sca_usb_stick --test-image`
2. Boot it in QEMU with no network
3. Run the same checks inside the VM
4. Collect `results.txt` via a virtual disk, print it, and remove the disk image

Exits with 0 when every check passed, and 1 when any check failed or the VM left
no results.
