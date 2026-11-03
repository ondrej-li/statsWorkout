# StatsWorkout

An iOS app that turns Apple Health activity into clear, good-looking statistics — for a week, a
month, a quarter, a year or any custom range.

The app reads steps and workouts from HealthKit, aggregates them in a pure Swift domain layer and
renders them with Swift Charts: zoomable bar charts, a cumulative progress comparison and
press-and-drag value inspection.

> **Status:** 1.0.0 — statistics, charts, scopes, settings and the App Store pages are done;
> widgets, goals and background delivery are not implemented yet.

<p align="center">
  <img src="docs/dashboard.png" alt="StatsWorkout dashboard showing November totals, metric tiles and a steps chart" width="320">
</p>

## Features

- **Periods** — rolling 24 hours, calendar day (hourly buckets), week, month (default), quarter,
  year and custom ranges, with back/forward navigation, "Today" and locale-aware week boundaries.
- **Two data scopes** — *All data* (continuous Health monitoring: all-day steps, walking/cycling/
  swimming distance, ascent from flights climbed) or *Activities* (only samples inside workouts),
  switchable on the dashboard and remembered between launches.
- **Metrics** — steps, distance, elevation gain, exercise duration and activity count.
- **Comparison** — every metric is compared with the previous period (or the same period last year),
  limited to the elapsed part of the period so partial months compare fairly.
- **Charts** — bar chart per period with pinch/button zoom, horizontal pan and tap/drag tooltips;
  cumulative "progress over time" chart with the comparison period overlaid.
- **Settings** — distance (km/mi) and elevation (m/ft) units, default period, comparison baseline.
- **Demo data** — a deterministic generator makes the app fully usable in the simulator without any
  Health data (enabled by default when built for the simulator).

## Requirements

| Tool | Version |
| --- | --- |
| Xcode | 26 or newer (iOS 26 SDK) |
| iOS deployment target | 26.0 |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.46+ (`brew install xcodegen`) |

## Quick start

```bash
brew install xcodegen
make generate     # regenerate StatsWorkout.xcodeproj from project.yml
make open         # or open StatsWorkout.xcodeproj manually
```

Then select an iPhone simulator and run. The app starts with demo data, so the dashboard is
populated immediately.

To run on a device, select your development team in *Signing & Capabilities*; the HealthKit
capability and `NSHealthShareUsageDescription` are already configured.

### Common commands

```bash
make build    # build for the simulator
make test     # run the unit tests on the simulator
make clean    # remove build products
```

If `xcodebuild` reports that it requires Xcode, point the toolchain at a full Xcode:
`make select-xcode` (or `sudo xcode-select -s /Applications/Xcode.app`).

## Switching from demo data to Apple Health

The first time the dashboard loads real data the app asks for Health access itself: the system
sheet lists the seven read types (steps, walking/running, cycling and swimming distance, flights
climbed, active energy and workouts). If you skip the sheet, turn off **Use demo data** in
*Settings → Data source* and use *Settings → Apple Health → Request read access*. HealthKit never reveals whether read
access was granted, so an empty dashboard means "no data" or "access denied" — the Health app
shows the current permission under *Sharing → Apps → StatsWorkout*.

## Architecture

```
Features (SwiftUI views + @Observable view models)
    ↓
Domain (pure Swift: periods, aggregation, formatting)
    ↑
Data (HealthDataProviding → HealthKitDataSource | MockHealthDataSource)
```

- **Domain** has no HealthKit or SwiftUI imports, so period maths and aggregation are unit-tested
  with a fixed `Calendar`, time zone and injected `now`.
- **`StatsAggregator`** turns samples into a `PeriodStats`: bucket totals, period totals, previous
  period totals for the elapsed window, and a bucket-aligned previous series for the cumulative chart.
- **Data** is behind a `Sendable` protocol: `HealthKitDataSource` uses the async
  `HKSampleQueryDescriptor` / `HKStatisticsCollectionQueryDescriptor` APIs; `MockHealthDataSource`
  produces stable pseudo-random data from a fixed seed.

### Metric definitions

| Metric | Source | Aggregation |
| --- | --- | --- |
| Steps | HealthKit `stepCount`, hourly or daily buckets | sum of all-day steps |
| Distance | HealthKit walking/running, cycling and swimming distance | sum |
| Elevation gain | Flights climbed × 3 m, or the workout's recorded ascent if larger | sum (may be absent) |
| Exercise duration | `HKWorkout` duration for curated workout types | sum |
| Activities | Curated workout types (run, walk, cycle, hike, swim, strength, yoga, other) | count |

The *Activities* scope reports only what happened inside a workout. HealthKit does **not** attach
step statistics to workouts (`HKWorkout.statistics(for: .stepCount)` returns `nil`), so steps and
distance for that scope come from statistics queries scoped to the workout time ranges; the
workout's own statistics are only used as a fallback when no samples are returned.

### Project layout

```
Sources/
  App/          app entry point, dependency container, settings
  Domain/       models, period calendar, aggregator, formatters
  Data/         HealthKit + mock data sources, workout mapping
  Features/     Dashboard, ActivityLog, Settings
  DesignSystem/ theme, cards, pills, tiles
Tests/          Swift Testing suites for the domain layer
Supporting/     generated Info.plist and entitlements
project.yml     XcodeGen specification (the source of truth for the project)
```

`StatsWorkout.xcodeproj` is generated and committed so the project opens without extra tooling.
Do not edit it by hand — change `project.yml` and run `make generate`. Run `make generate` after
adding or deleting source files.

## Testing

```bash
make test
```

The suites cover period boundaries (including DST and leap years), bucket generation, aggregation,
partial-period comparison and unit formatting. Chart cards ship with `#Preview`s backed by the mock
data source, so visual work does not need a device.

CI runs the same build and test on every pull request (see `.github/workflows/ci.yml`).

## Contributing

Workflow, branch naming and PR requirements are described in [CONTRIBUTING.md](CONTRIBUTING.md).
`main` is protected: changes land through pull requests with a green CI run.

## Roadmap

- Widgets and Live Activity summaries
- Goal setting and rings
- Workout detail screens with route maps
- Background HealthKit delivery and incremental caching
- Localisation (string catalog is already enabled)

## Screenshots and artwork

`make shots` captures the App Store screenshots from clean simulators
(6.1"/6.3" iPhone and 13" iPad) into [screenshots/](screenshots) — see
[screenshots/README.md](screenshots/README.md) for the frames and the debug-only
launch arguments behind them. Icon candidates live in [docs/icons/](docs/icons).

## Publishing to TestFlight

```bash
make testflight                    # build number defaults to a timestamp
make testflight BUILD_NUMBER=42    # or pass an explicit build number
```

The script archives in Release, signs with automatic provisioning for team
`B592D69P29` and uploads to App Store Connect. Prerequisites:

- Xcode is signed in with the team's Apple ID (*Xcode → Settings → Accounts*).
- An app record for `com.defik74.statsWorkout` exists in App Store Connect
  (*Apps → + → New App*). The App ID itself is created automatically by Xcode.


## App Store pages

The privacy policy and support pages required for App Store review live in [Website/](Website) and
are published at:

- https://stats-workout.ondralinek.cz/ — landing page (English, Czech under `/cs/`)
- https://stats-workout.ondralinek.cz/privacy.html
- https://stats-workout.ondralinek.cz/support.html

```bash
make deploy-site   # rsync Website/ to deploy@2.31.33.21:/var/www/stats-workout
```

The app links to the same pages from *Settings → About*. Submission metadata (description,
keywords, privacy answers, review notes) is drafted in [docs/app-store.md](docs/app-store.md).
