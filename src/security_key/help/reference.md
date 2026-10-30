### Choosing a key: `--device SERIAL`

Every `security_key` subcommand accepts `--device SERIAL`, the YubiKey's hardware serial as printed by `sca security_key id` (or `ykman list --serials`). The serial is passed on to the tools: `yubico-piv-tool` is pointed at that key's reader, and `pkcs11-tool` at its `YubiKey PIV #<serial>` token.

- `info` and `verify`: with one key attached, `--device` is optional and nothing changes. With more than one attached and no `--device`, the command prints the attached serials and exits non-zero rather than pick one.
- `get_crt`, `init`, `unblock_pin`, `upload` and `wait_for`: these wait for the entity's configured key (`<entity>_security_key_id`). `--device` waits for the named key instead, which is how a second (backup) key of the same entity is reached. If no key is configured and more than one is attached, they refuse in the same way.
- `id`: lists only the named key, and fails if it is not attached.

```bash
sca security_key id                         # 12345678 0
                                            # 87654321 1
sca security_key info --device 87654321
sca security_key upload --device 87654321 subca crt
```

If one attached reader's name is contained in another's, `yubico-piv-tool` cannot tell those two keys apart. In that case `sca` refuses and asks you to attach only the key you want to use.
