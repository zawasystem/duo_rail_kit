# Publication preparation

The [MIT License](../LICENSE) is approved: copyright 2026 ZAWA SYSTEM. Its text
follows the [OSI MIT License](https://opensource.org/license/mit). The owner made
the GitHub repository public on 2026-11-01. `publish_to: 'none'` remains in
`pubspec.yaml`; version 0.1.0 is available through Git but is not published on
pub.dev. Publishing there requires separate authorization.

## Compatibility to verify

| Area | Current contract | Before pub.dev release |
| --- | --- | --- |
| Development SDK | Flutter `>=3.47.8`, development pinned to 3.47.8 via FVM; Dart `^3.12.0` | Confirm a clean installation from publicly available SDK distributions. Test the advertised minimum and intended stable SDK. |
| iOS integration | Swift Package Manager; minimum deployment target 15.0 | Confirm dependency resolution and generated plugin registration in a clean host. CocoaPods is not provided. |
| Native compilation | iOS 27.1 SDK declares `verticalBarEdge` | Confirm that the build machine and CI runner supply the SDK. The deployment minimum is not the compilation SDK requirement. |
| Native behavior | Trait access is guarded for iOS 27.1 | Check supported Duo orientations, both Split View sides, rotation/folding, and status-bar visibility on a suitable simulator or device. |
| Other platforms | Flutter width-based placement; no Android native plugin | Run the Android example and verify ordinary phone/tablet layouts. No wider platform support is implied by Dart-only test success. |

The fixed 84-point column and 152-point status-band boundary come from simulator
measurements. Recheck those assumptions against the OS builds advertised as
supported. The first frame can use the width fallback before the native reply.
See [README limitations](../README.md#native-contract-and-limitations).

## Release-candidate checks

Run package and example formatting, analysis, and tests, then build the iOS
example and the disposable native host. Run the Android example build. Record
commands, SDKs, the tested revision, and results; do not substitute extraction
baseline results for a changed release candidate.

The publishing dry run must run in an isolated staging copy with
`publish_to: 'none'` removed only in that copy:

```sh
# From the staged package, using the selected Flutter SDK.
fvm flutter pub publish --dry-run
```

Review every warning and the proposed file list. This command must not publish
anything. Keep the real package's publication guard until authorization. After
the dry run, inspect the archive contents for example sources, the license,
required iOS files, and absent credentials, caches, local paths, and unrelated
application files. Validate the README links and images from that file set.

## Repository and CI review

- Review the entire public history, including compatibility tags, not only the
  current tree. Check source comments, commit metadata, example identifiers,
  generated platform files, and images for private application or personal
  information when adding or changing published refs.
- Review [third-party notices](../THIRD_PARTY_NOTICES.md) and the publish archive.
  MIT licensing of this package does not replace the Flutter template license or
  the rendered font/icon terms. Check other dependency notices as well.
- Verify the private reporting channel described in [SECURITY.md](../SECURITY.md).
  Repository visibility alone does not enable private vulnerability reporting.
- Use isolated hosted or ephemeral runners for public contributions. Confirm
  the SDK is available, set timeouts/concurrency and spending limits, and observe
  a successful CI run at the intended revision. A workflow file or local build
  is not proof that CI has run successfully.
- Use ordinary HTTPS dependency resolution in consumer CI and release jobs.
  Package-specific GitHub App authentication and Dependabot private access are
  no longer needed. Remove obsolete credentials only after retiring any branches
  that still use them; preserve unrelated signing credentials. See
  [Git dependency access](ci_authentication.md).

## Validation record: 2026-10-31

The checks below were run on 2026-10-31 on the publication-preparation working
tree based on `3734976a179448c2fda790a33ef5fe8a53a7b288`. Local tools were Flutter
3.47.8, Xcode 27.2, and iOS Simulator SDK 27.2. At that time, remote CI was blocked
by billing/spending configuration while the repository was private; no successful
CI run is claimed for that check. These are historical results, not evidence for
a later revision. Repeat release checks against the intended pub.dev revision.

| Check | Recorded result |
| --- | --- |
| Public availability of required Flutter/Xcode SDKs | Local SDKs verified. A clean download from public distributions remains a publication prerequisite; a local installation alone does not establish availability. |
| Package formatting, analysis, and tests | `fvm dart format --output=none --set-exit-if-changed lib test example/lib example/test example/tool` and `fvm flutter analyze --no-pub` passed; `fvm flutter test --no-pub` passed all 97 package tests. |
| Runnable example formatting, analysis, and tests | `fvm flutter pub get`, `fvm flutter analyze --no-pub`, and `fvm flutter test` passed; 10 widget tests, including state preservation and single-line navigation labels at enlarged text sizes. Four screenshot fixtures also rendered successfully. |
| iOS example/disposable host builds and plugin registration | `fvm flutter build ios --simulator --debug --no-codesign` passed in `example/`; `fvm exec bash tool/build_ios_host.sh` passed generated SPM/registrant and defined native symbol checks. |
| Android example build | `fvm flutter build apk --debug` passed in `example/`. Gradle emitted a JVM native-access warning; the build completed successfully. |
| Native runtime events and device layouts | Not established by simulated screenshots or compilation. |
| Staged pub.dev dry run and file-list review | `flutter pub publish --dry-run` with the selected SDK passed in an isolated copy: 475 KB, zero warnings. Required source/example/images/licenses are included; caches, signing data, credentials, and internal documentation are excluded. No upload or publication was performed. |
| Documentation links and third-party notices | Local links resolve; Flutter template license matches the SDK verbatim; renderer font copyrights and supplied licenses checked against the installed SDK artifacts. |
| Complete history/privacy review | Candidate source, file list, and images reviewed with no secrets, customer data, or local paths found. The complete history/provenance review was not established by that working-tree check. |
| Public-ready CI and spending configuration | Ubuntu package/example checks and a manual hosted macOS job were configured; execution was blocked by billing/spending configuration at that time. No CI success claimed. |
| Private vulnerability reporting | Not verified in the 2026-10-31 check; see the current status below. |

The README images are Flutter-rendered examples with simulated insets, not
native device captures. They illustrate layout only.

## Public Git access: 2026-11-01

GitHub reports this repository as `PUBLIC`. With Git system/global configuration,
credential helpers, and interactive prompting disabled, an HTTPS fetch resolved
`3734976a179448c2fda790a33ef5fe8a53a7b288`. A separate Flutter host with an empty
Pub cache also resolved that exact revision using the canonical HTTPS URL, and
its generated lockfile recorded the same SHA. The
`compat/initial-extraction` tag preserves that revision for existing consumers.

The five consumer migration branches now use ordinary `flutter pub get` in CI
and Android/iOS release workflows. Their fixed dependency and lockfiles are
unchanged. Package-only GitHub App steps and helpers are removed; authentication
for signing and delivery remains. This verification does not constitute an app
release, a pub.dev publication, or a successful remote consumer CI run.

Local checks after the documentation and CI-authentication updates passed:
package and example analysis reported no issues, all 97 package tests and all
10 example tests passed, and the package workflow passed actionlint. The ten
consumer CI/release workflows also passed actionlint, and all 65 existing CI
scope-detection tests passed. Runtime sources and consumer dependency pins were
not changed by this update.

GitHub private vulnerability reporting was checked separately and is disabled.
[SECURITY.md](../SECURITY.md) describes this limitation; repository visibility does
not establish a private reporting channel.
