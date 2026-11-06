# Appliance board profiles

Each `<board>.conf` here describes one board for `sca appliance`. The file name
is the board name used with `--board`. Adding a board means adding one file:
the build embeds every profile into `build/sca.sh` and lists the board names in
the help and in bash completion.

A profile is **data**: `sca` reads it key by key with `awk` and never sources
or evaluates it. One `key=value` per line; lines starting with `#` are
comments. Values that are regular expressions are POSIX EREs (`grep -E`).

| key | used by | meaning |
|-----|---------|---------|
| `name` | info | human-readable board name |
| `compatible` | verify, info | ERE matched against each entry of `/proc/device-tree/compatible`, to detect the board |
| `verified` | verify, info | what was verified on hardware, when and where it is recorded; `no` for a proposal (verify then says so first) |
| `irreversible` | info (init, later) | `yes` if enabling the boot method cannot be undone (a Pi 3's OTP bit) |
| `base_image`, `base_image_check` | info (init, later) | the OS image and how its authenticity is checked |
| `boot_enable_method` | info (init, later) | how the board is made to boot from USB |
| `rtc_method`, `i2c_bus` | info (init, later) | how the battery-backed RTC is enabled, and the I2C bus of header pins 3/5 |
| `root_transports` | verify | space-separated `lsblk` TRAN values the root disk may have |
| `rtc_name` | verify | ERE for `/sys/class/rtc/rtc0/name` |
| `masked_units` | verify, info | space-separated systemd units that must be masked (or absent) |
| `probe_label` | verify, info | row label of the board-specific check |
| `probe_file` or `probe_command` | verify, info | where the board-specific value comes from: a file (NULs stripped), or a command split into words and run without a shell |
| `probe_expect` | verify | ERE the probe value must match |
| `probe_reject` | verify | optional ERE the probe value must not match |
