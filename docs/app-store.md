# App Store submission notes

> The final copy for each App Store Connect field — name, subtitle, promotional text, description
> (EN + CS), keywords, What's New, review notes — lives in
> [app-store-listing.md](app-store-listing.md) with measured character counts. This file is the
> process around it.

Everything App Store Connect needs for a first submission, in the order the form asks for it.
The public pages live at [stats-workout.ondralinek.cz](https://stats-workout.ondralinek.cz/).

## App information

| Field | Value |
| --- | --- |
| Name (30) | `StatsWorkout` — see the listing file |
| Subtitle (30) | `Health stats for every period` |
| Bundle ID | `com.defik74.statsWorkout` |
| SKU | `statsworkout-001` |
| Primary language | English (U.S.) |
| Primary category | Health & Fitness |
| Secondary category | — |
| Age rating | 4+ (no user content, no ads, no web browsing) |
| Copyright | `2026 Ondřej Linek` |
| Price | Free |

## URLs

| Field | URL |
| --- | --- |
| Privacy Policy URL | https://stats-workout.ondralinek.cz/privacy.html |
| Support URL | https://stats-workout.ondralinek.cz/support.html |
| Marketing URL (optional) | https://stats-workout.ondralinek.cz/ |

Czech versions: `/cs/privacy.html`, `/cs/support.html`, `/cs/`.

## Copy

All fields are in [app-store-listing.md](app-store-listing.md): promotional text, EN and CS
descriptions, keywords, What's New and review notes.

## App Privacy

- **Data collection:** *Data Not Collected.* HealthKit data never leaves the device and the app has
  no backend, no analytics and no crash reporting.
- **Health & Fitness data:** used only for app functionality, on device, not linked to identity —
  and not collected in the App Privacy sense.
- **Tracking:** No.

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already set in `Supporting/Info.plist`, so App Store
Connect does not ask.

## Review notes

```
StatsWorkout reads steps and workouts from Apple Health; there is no login and no account.
On first launch the app shows the Health permission sheet. If access is declined, the dashboard
explains how to enable it in iOS Settings → Privacy & Security → Health → StatsWorkout.

No Health data leaves the device: there is no server component, no analytics and no third-party SDK.

To see the interface without any Health data, open Settings → Data source → Use demo data. The
sample activity is generated locally on the device and clearly labelled in the UI.
```

## Screenshots

Captured, not assembled: `make shots` and `make shots-cs` write them to
[screenshots/](../screenshots) in one folder per localisation (1206 × 2622 iPhone, 2064 × 2752
iPad), all with a 9:41 status bar, no alpha and no metadata chunks.

| Slot | File | Shows |
| --- | --- | --- |
| 1 | `en/iphone/01-dashboard.png` | month totals, five metrics, All data / Activities switch |
| 2 | `en/iphone/02-day.png` | hourly bars with a value callout + progress chart |
| 3 | `en/iphone/03-progress.png` | running total against the previous period |
| 4 | `en/iphone/04-workout-detail.png` | a workout with its route map, metrics and splits |
| 5 | `en/iphone/05-share.png` | the card that goes to Instagram, Facebook, Messenger or WhatsApp |
| 6 | `en/iphone/06-activity-log.png` | workouts by day, with their names |
| 7 | `en/iphone/07-activities-only.png` | workout-only numbers |
| 8 | `en/iphone/08-settings.png` | units, language, defaults and Health access |

iPad: `en/ipad/01-dashboard.png`, `02-day.png`, `03-progress.png`, `04-workout-detail.png`,
`05-share.png`, `06-activity-log.png`. The same eight/six frames exist under `cs/` for the Czech
listing.

## App icon

Five candidates with a recommendation are in [icons/](icons/README.md). The
shipped icon must be 1024 × 1024 and opaque; the current `AppIcon.png` is a
placeholder.

## Localisation

The app ships ten languages: English (primary), Czech, German, Spanish, French, Italian, Portuguese,
Japanese, Korean and Simplified Chinese. `CFBundleLocalizations` is not used — the catalogs are JSON
files in `Resources/L10n/` read by the app's own `L10n` layer, and the language is chosen in
Settings (or follows the device, falling back to English).

Only English and Czech have App Store metadata and screenshots; the other eight app languages work
in the binary without a listing of their own. Adding one later needs a subtitle, promotional text,
description, keywords and What's New in that language (the app's catalogs in `Resources/L10n/` are a
good source) plus a screenshot run. The website remains English with a Czech translation.
