# CLAUDE.md — StatsWorkout

The map, not the manual. The [README](README.md) documents the features and the
architecture in detail, [`CONTRIBUTING.md`](CONTRIBUTING.md) the branch rules,
[`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) the shipping secrets, and
[`docs/app-store.md`](docs/app-store.md) the review process.

## What this is

An iOS app that turns Apple Health activity into statistics: periods, two data
scopes (all data vs. activities), charts, workout detail with routes, widgets,
ten languages. SwiftUI + Swift Charts, HealthKit, pure-Swift domain layer.

## Layout

```
Sources/
  App/            entry point, dependency container, settings, screenshot routes, localisation
  Domain/         models, period calendar, aggregation, route geometry, naming, formatters
  Data/           HealthKit + mock sources, workout mapping, sync coordinator, cache, places
  Features/       Dashboard, ActivityLog (list/detail/map), Share, Settings
  Shared/         App Group, shared preferences, widget filters/data/views
  Widgets/        the widget extension
  DesignSystem/   theme, cards, pills, tiles
Tests/            Swift Testing suites
Supporting/       generated Info.plist, entitlements, ExportOptions.plist
Website/          support and privacy pages → stats-workout.ondralinek.cz
screenshots/      App Store artwork captured from the simulator
tools/            PNG flatten/strip helpers, icon generator
project.yml       XcodeGen specification — the source of truth
```

`StatsWorkout.xcodeproj` is generated **and committed**, because that is what CI
builds. Change `project.yml`, run `make generate`, commit the regenerated project
in the same commit.

## Building and testing

**There is no local build any more.** `macos-26` runners compile and test it:

```sh
gh workflow run ci.yml       # or just push to a branch / open a PR
gh run list --limit 3        # what CI last said
```

Required status check on `main`: **Build & test**. Locally, with a full Xcode
(`make select-xcode` helps when `xcode-select` points at the Command Line Tools):

```sh
make build        # simulator build
make test         # unit tests
make shots        # App Store screenshots, both devices
```

The code is iOS-only with HealthKit and App Group entitlements; there is nothing
that builds on Linux. Do not try to compile it on the VPS.

## Shipping

**Publishing is manual; CI does not upload anything** and no Apple credential is
stored in this repository. On a machine with Xcode signed into the team's Apple ID:

```sh
make testflight                    # build number defaults to a timestamp
make testflight BUILD_NUMBER=42    # or pass an explicit build number
```

`MARKETING_VERSION` lives in `project.yml` — bump it before a new version.
[`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) has the prerequisites.

The support/privacy site is published with `make deploy-site` (rsync of
`Website/` to the VPS).

## Conventions

- `main` is protected: branch, PR, required check green, squash-merge. Direct
  pushes are rejected.
- Domain logic is pure Swift and belongs in `Sources/Domain` with tests next to
  it; HealthKit stays behind the `Data` protocols so tests never touch the store.
- Metric definitions, naming rules, splits and widget filters are specified in the
  README — read the relevant section before changing behaviour there.
- Localisation: every user-visible string goes through the catalog; the language
  tests fail on a missing placeholder or plural form.
- Do not commit `screenshots/` regenerations unless the artwork actually changed.
