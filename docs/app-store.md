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
| Subtitle (30) | `Apple Health stats, any period` |
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

Captured, not assembled: `make shots` writes them to [screenshots/](../screenshots)
(1206 × 2622 iPhone, 2064 × 2752 iPad), all with a 9:41 status bar, no alpha and
no metadata chunks.

| Slot | File |
| --- | --- |
| 1 | `iphone/01-dashboard.png` — month totals, five metrics, All data / Activities switch |
| 2 | `iphone/02-day.png` — hourly bars with a value callout + progress chart |
| 3 | `iphone/03-progress.png` — running total against the previous period |
| 4 | `iphone/04-activities-only.png` — workout-only numbers |
| 5 | `iphone/05-activity-log.png` — workouts by day |
| 6 | `iphone/06-settings.png` — units and defaults |

iPad: `ipad/01-dashboard.png`, `02-day.png`, `03-progress.png`, `04-activity-log.png`.

## App icon

Five candidates with a recommendation are in [icons/](icons/README.md). The
shipped icon must be 1024 × 1024 and opaque; the current `AppIcon.png` is a
placeholder.

## Localisation

The app ships ten languages: English (primary), Czech, German, Spanish, French, Italian, Portuguese,
Japanese, Korean and Simplified Chinese. `CFBundleLocalizations` is not used — the catalogs are JSON
files in `Resources/L10n/` read by the app's own `L10n` layer, and the language is chosen in
Settings (or follows the device, falling back to English).

App Store Connect only needs the primary language (English) for the listing; the additional app
languages are picked up from the binary once the localized metadata is uploaded. The website and the
listing copy remain English with a Czech translation.
