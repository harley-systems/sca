### Board profiles

A board profile is a data file, `src/appliance/boards/<board>.conf`, embedded in `sca` at build time. Adding a board means adding one file; the command surface does not change. The `rock64` profile is verified on hardware (with the exception of booting the root from a USB stick); the `raspberrypi` profile is a proposal that nobody has run on a Pi. See [Checking the appliance](../air-gapped-appliance.md#5-checking-the-appliance-sca-appliance-verify) for what each check catches and what is verified.
