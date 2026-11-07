# Appliance platform profiles

Each `<platform>.conf` here describes one platform for `sca appliance`: an ARM
board such as the ROCK64, or an x86 mini PC. The file name is the platform name
used with `--platform`. Adding a platform means adding one file: the build
embeds every profile into `build/sca.sh` and lists the platform names in the
help and in bash completion.

A profile is **data**: `sca` reads it key by key with `awk` and never sources
or evaluates it. One `key=value` per line; lines starting with `#` are
comments. Values that are regular expressions are POSIX EREs (`grep -E`).

| key | used by | meaning |
|-----|---------|---------|
| `name` | info | human-readable platform name |
| `compatible` | verify, info | ERE matched against each entry of `/proc/device-tree/compatible`, to detect the platform. Leave it out on a platform with no device tree (x86) |
| `arch` | verify, info | `amd64` or `arm64`. A profile without `compatible` is detected when its `arch` is the machine's (`uname -m`) and no other such profile has the same `arch` |
| `verified` | verify, info | what was verified on hardware, when and where it is recorded; `no` for a proposal (verify then says so first) |
| `irreversible` | info (init, later) | `yes` if the boot preparation cannot be undone (a Pi 3's OTP bit) |
| `base_image`, `base_image_check` | info (init, later) | the OS image and how its authenticity is checked. `base_image_check` names only a check somebody has actually performed; otherwise it says `none` or marks the route `(unverified)` |
| `boot_prep` | verify, info (init, later) | how the platform is made to boot from USB: `none` (boots USB out of the box; verify then shows the boot row as `n/a`), `uboot-spi`, `rpi-eeprom` or `rpi-otp` |
| `rtc` | info (init, later) | the battery-backed clock: `builtin` (a PC's CMOS clock) or `i2c-ds3231` |
| `rtc_method`, `i2c_bus` | info (init, later) | for `rtc=i2c-ds3231`: how the RTC is enabled, and the I2C bus of header pins 3/5 |
| `root_transports` | verify | space-separated `lsblk` TRAN values the root disk may have |
| `rtc_name` | verify | ERE for `/sys/class/rtc/rtc0/name` |
| `masked_units` | verify, info | space-separated systemd units that must be masked (or absent) |
| `probe_label` | verify, info | row label of the platform-specific check |
| `probe_file` or `probe_command` | verify, info | where the platform-specific value comes from: a file (NULs stripped), or a command split into words and run without a shell. Required unless `boot_prep=none` |
| `probe_expect` | verify | ERE the probe value must match |
| `probe_reject` | verify | optional ERE the probe value must not match |
