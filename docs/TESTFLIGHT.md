# Publishing

**CI does not publish.** There is no workflow that uploads to App Store Connect,
and no Apple credential is stored in this repository. Publishing is a manual step
from a machine with Xcode and the developer account signed in; the commit-time
workflow (`ci.yml`) only builds and tests.

Why: an upload needs a distribution identity, and an identity is a private key
Apple hands out once per certificate. Every arrangement that puts one in CI
either stores a long-lived secret (which has to be exported out of a keychain) or
re-creates the certificate per run (which mails the account holder and
invalidates profiles built on it). Neither is worth it for a handful of releases
a year.

## How to ship

__SHIP__

```sh
make testflight                      # build number defaults to a timestamp
make testflight BUILD_NUMBER=42      # or pass an explicit one
```

`Scripts/publish-testflight.sh` archives in Release, signs with automatic
provisioning for team `B592D69P29` and uploads with the Apple ID signed into
Xcode (*Xcode → Settings → Accounts*). An app record for
`com.defik74.statsWorkout` must exist in App Store Connect.

Bump `MARKETING_VERSION` in `project.yml` before a new version.
