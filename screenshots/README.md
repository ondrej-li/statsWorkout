# App Store screenshots

Captured from a clean simulator rather than assembled by hand, the same way the
[vdv-live](https://github.com/ondrej-li/vdv-live) artwork is made:

| Folder | Size | Device |
| --- | --- | --- |
| `iphone/` | 1206 × 2622 | 6.1"/6.3" iPhone — the tab App Store Connect asks for |
| `ipad/` | 2064 × 2752 | 13" iPad |

Frames:

| File | Shows |
| --- | --- |
| `01-dashboard` | Month totals, the five metric tiles and the All data / Activities switch |
| `02-day` | A full day with hourly bars and a value callout, plus the progress chart |
| `03-progress` | Running total against the previous period |
| `04-activities-only` | The same month limited to samples recorded inside workouts (iPhone only) |
| `05-activity-log` / `04-activity-log` | Workouts grouped by day |
| `06-settings` | Units, period defaults, Health access |

Every frame carries a 9:41 status bar, no alpha channel and no metadata chunks —
Simulator screenshots have an alpha channel and ImageIO stamps an `eXIf` chunk,
and App Store Connect rejects both with a misleading "file dimensions are
invalid" error.

## Regenerating

```sh
make shots          # both devices
make shots-iphone   # iPhone tab only
make shots-ipad
```

The script builds the app for the simulator, boots the devices, installs a clean
copy, forces demo data (`-settings.useMockData YES`) and launches with
debug-only arguments handled by [ScreenshotRoute.swift](../Sources/App/ScreenshotRoute.swift):

| Argument | Effect |
| --- | --- |
| `-screenshotTab stats\|activities\|settings` | Opens that tab |
| `-screenshotPeriod month` | Selects a period chip |
| `-screenshotOffset -1` | Steps back one period, so a month is complete |
| `-screenshotScope all\|activities` | Picks the data scope |
| `-screenshotSection charts\|progress\|activities` | Scrolls to a card |
| `-screenshotSelect peak` | Selects the highest bucket, so the callout is never empty |
| `-screenshotNow 2026-11-02T23:30:00` | Freezes the clock, so a day shot shows a whole day |

All of these answer `nil` in a Release build, so nothing about them can reach the
archive shipped to the App Store.

Override the devices or timing when needed:

```sh
make shots SHOT_IPHONE="iPhone 17" SHOT_IPAD="iPad Pro 13-inch (M5)" SHOT_DELAY=8
```
