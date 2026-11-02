# StatsWorkout

An iOS app that turns Apple Health activity into clear, good-looking statistics — for a week, a
month, a quarter, a year or any custom range.

The app reads steps and workouts from HealthKit, aggregates them in a pure Swift domain layer and
renders them with Swift Charts: zoomable bar charts, a cumulative progress comparison and
press-and-drag value inspection.

> **Status:** skeleton. The data pipeline, charts, settings and mock data source are functional;
> widgets, goals and background delivery are not implemented yet.

## Features

- **Periods** — calendar week, month (default), quarter, year and custom ranges, with back/forward
  navigation, "Today" and locale-aware week boundaries.
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

Open *Settings → Data source* and turn off **Use demo data**, then grant read access when asked
(or use *Settings → Apple Health → Request read access*). HealthKit never reveals whether read
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
| Steps | HealthKit `stepCount`, daily buckets | sum of all-day steps |
| Distance | Workout statistics for walking/running, cycling, swimming | sum |
| Elevation gain | `HKMetadataKeyElevationAscended`, else flights climbed × 3 m | sum (may be absent) |
| Exercise duration | `HKWorkout` duration for curated workout types | sum |
| Activities | Curated workout types (run, walk, cycle, hike, swim, strength, yoga, other) | count |

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
