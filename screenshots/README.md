# App Store screenshots

Captured from a clean simulator rather than assembled by hand, the same way the
[vdv-live](https://github.com/ondrej-li/vdv-live) artwork is made. One folder per App Store
localisation:

| Folder | Size | Device |
| --- | --- | --- |
| `en/iphone/` | 1206 × 2622 | 6.1"/6.3" iPhone — the tab App Store Connect asks for |
| `en/ipad/` | 2064 × 2752 | 13" iPad |
| `cs/iphone/`, `cs/ipad/` | the same | the Czech listing |

Frames:

| File | Shows |
| --- | --- |
| `01-dashboard` | Month totals, the five metric tiles and the All data / Activities switch |
| `02-day` | A full day with hourly bars, a value callout and the progress chart |
| `03-progress` | Running total against the previous period |
| `04-workout-detail` | A workout with its route map, metrics and splits |
| `05-activity-log` | Workouts grouped by day, each with its name |
| `06-activities-only` | The same month limited to samples recorded inside workouts (iPhone only) |
| `07-settings` | Units, language, period defaults and Health access (iPhone only) |

Every frame carries a 9:41 status bar, no alpha channel and no metadata chunks — Simulator
screenshots have an alpha channel and ImageIO stamps an `eXIf` chunk, and App Store Connect rejects
both with a misleading "file dimensions are invalid" error.

## Regenerating

```sh
make shots          # English, iPhone + iPad
make shots-cs       # Czech, iPhone + iPad
make shots-iphone   # English iPhone only
make shots-ipad     # English iPad only
```

The script builds the app, boots the devices, installs a clean copy and launches it with debug-only
arguments handled by [ScreenshotRoute.swift](../Sources/App/ScreenshotRoute.swift):

| Argument | Effect |
| --- | --- |
| `-screenshotTab stats\|activities\|settings` | Opens that tab |
| `-screenshotPeriod month` | Selects a period chip |
| `-screenshotOffset -1` | Steps back one period, so a month or a day is complete |
| `-screenshotScope all\|activities` | Picks the data scope |
| `-screenshotSection charts\|progress\|activities` | Scrolls to a card |
| `-screenshotSelect peak` | Selects the highest bucket, so the callout is never empty |
| `-screenshotWorkout 0` | Opens the nth workout's detail screen |
| `-screenshotHideDemoLabels YES` | Hides the demo chip, banner and route caption |

All of these answer `nil` in a Release build, so nothing about them can reach the archive shipped to
the App Store. `-screenshotHideDemoLabels` only hides the labels — the numbers still come from the
demo generator — so the artwork shows the product rather than its scaffolding.

The script waits for real content instead of guessing at a delay: `ScreenshotRoute.markReady` drops
a marker into the app's `Documents` folder when a screen finishes loading, `markLoading` removes it
when a reload starts, and two frames a second apart must be identical before one is kept. It also
forces light appearance and sets the simulator's region (`en_US` or `cs_CZ`) so the status bar date
matches the language. A launch that hangs is retried once.

Override the devices or timing when needed:

```sh
make shots SHOT_IPHONE="iPhone 17" SHOT_IPAD="iPad Pro 13-inch (M5)" SHOT_DELAY=8
```
