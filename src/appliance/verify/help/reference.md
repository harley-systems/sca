```bash
$ sca appliance verify
  boot      2026.04                                  ok
  root      /dev/mmcblk1p1 (no transport), not usb   FAIL
  rtc       rtc-ds1307 is rtc0, hctosys=1            ok
  clock     not synchronised by NTP                  ok
  hwclock   3 unit(s) masked or absent               ok
  power cut clock kept through power-off             ok
appliance verify: 1 check(s) failed
```

The example is a ROCK64 whose root is still on a microSD card: `root` fails because the appliance does not boot from a USB stick yet, which is what it should report. When `rtc` fails, its row lists every RTC with its name and `hctosys`, which shows a PMIC clock holding `rtc0`. `sca appliance info` shows the raw values behind every row.

On a board whose journal does not remember the previous boot, the `power cut` row has nothing to compare and reads `skipped`, which is neither a pass nor a failure:

```bash
$ sudo sca appliance verify
  ...
  power cut journal is volatile: kept in /run/log/journal skipped
```

[Persistent journal](../air-gapped-appliance.md#46-persistent-journal) makes the journal keep earlier boots, so that the row really compares two boots.
