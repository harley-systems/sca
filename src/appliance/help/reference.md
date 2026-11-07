### Platform profiles

A platform profile is a data file, `src/appliance/platforms/<platform>.conf`, embedded in `sca` at build time. Adding a platform means adding one file; the command surface does not change. The `rock64` profile is verified on hardware; the `raspberrypi` and `x86` profiles are proposals that nobody has run on that hardware. See [Checking the appliance](../air-gapped-appliance.md#5-checking-the-appliance-sca-appliance-verify) for what each check catches and what is verified.
