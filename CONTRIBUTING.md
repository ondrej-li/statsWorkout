# Contributing

## Prerequisites

```bash
brew install xcodegen
```

## Workflow

`main` is protected. Direct pushes are rejected, so every change goes through a pull request:

1. Branch from `main` using a descriptive name:
   - `feat/chart-zoom`
   - `fix/quarter-bucket-count`
   - `chore/ci-cache`
   - `docs/architecture-notes`
2. Make the change. If you added or removed files, run `make generate` and commit the regenerated
   `StatsWorkout.xcodeproj` — CI builds from the committed project.
3. Run the tests locally: `make test`.
4. Open a pull request. CI (`Build & test`) must be green before merging; the branch must be up to
   date with `main`.
5. Squash-merge. The branch is deleted automatically.

## Conventions

- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`,
  `chore:`, `docs:`, `test:`, `refactor:`.
- **Keep the domain pure.** `Sources/Domain` must not import HealthKit or SwiftUI; put platform code
  in `Sources/Data` or `Sources/Features`.
- **Test behaviour, not SwiftUI.** Add Swift Testing cases for period maths, aggregation and
  formatting rather than UI snapshots.
- **Style:** 4 spaces, no trailing whitespace (`.editorconfig`), one type per file, small views.
- **Accessibility:** every interactive chart/control needs a label; charts expose a summary value.

## Local checks

```bash
make generate   # project.yml → StatsWorkout.xcodeproj
make build
make test
```
