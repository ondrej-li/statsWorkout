# TestFlight

[`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml)
archives the app, exports an `.ipa` and uploads it to TestFlight. It runs on a
GitHub `macos-26` runner, so no machine of yours needs Xcode, a certificate or an
Apple ID signed in.

## How it is triggered

| Trigger | What happens |
| --- | --- |
| Push a `v*` tag | archive, export and upload |
| *Actions → TestFlight → Run workflow* | the same, unless you untick **upload** — unticked it archives and exports without sending anything, which is the cheap way to check signing |

`CFBundleVersion` becomes the workflow run number, so TestFlight never sees the
same build number twice. `MARKETING_VERSION` is in `project.yml`; bump it there
for a new version.

## The four repository secrets

| Secret | Contents |
| --- | --- |
| `APPLE_TEAM_ID` | `B592D69P29` |
| `APP_CONNECT_KEY_ID` | the API key's 10-character ID |
| `APP_CONNECT_ISSUER_ID` | the issuer UUID shown above the key list |
| `APP_CONNECT_KEY_P8` | the whole `AuthKey_<id>.p8`, base64 encoded |

No certificate is stored anywhere. The runner signs with the API key alone
(`-allowProvisioningUpdates` plus `-authenticationKeyPath`), which is also why no
developer machine has to exist: the certificate and the provisioning profile are
resolved on the runner, per job.

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy     # paste into the secret
```

Until all four exist the workflow fails at *Check the signing secrets exist* and
names the missing ones. That is deliberate — a deploy that cannot deploy should
be red, not quietly skipped.

## What it needs on Apple's side

- An app record for `com.defik74.statsWorkout` in App Store Connect.
- The App Group and HealthKit entitlements already present in
  `Supporting/*.entitlements` must be enabled for that bundle ID; the API key
  creates or refreshes the provisioning profile but cannot enable a capability.

## Export options

`Supporting/ExportOptions.plist` is committed: `method: app-store-connect`,
`destination: export`, automatic signing for team `B592D69P29`, symbol upload on,
and `manageAppVersionAndBuildNumber` off so Xcode does not renumber builds behind
the workflow's back.

## After the upload

Processing takes a few minutes before testers see the build. The workflow keeps
`StatsWorkout-ipa` as an artifact for 14 days, so a failed upload can be retried
from the artifact instead of being rebuilt.

## The old local route

`make testflight` (`Scripts/publish-testflight.sh`) still works on a machine
where Xcode has the team's Apple ID signed in. It is kept for emergencies; the
workflow is the normal path and the only one the CI badge reflects.
