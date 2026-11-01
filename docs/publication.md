# Publication checklist

The package uses the [MIT License](../LICENSE), copyright 2026 ZAWA SYSTEM.
These steps describe release preparation and verification, not evidence that a
release has completed. Publishing requires explicit authorization.

## Version and release contents

The initial pub.dev release is numbered 0.1.1. The existing Git-only
`0.1.0` tag stays fixed. Use a new version for later changes; do not replace a
published version or move a release tag.

Before each release, align `pubspec.yaml`, the changelog, and the README's
installation instructions. Check the intended publishing account and package
destination. For an authorized pub.dev release, omit `publish_to: 'none'` from
the root package; the example application keeps its publication guard. Match
the release tag to the source used for the reviewed archive.

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
commands, SDKs, the tested revision, and results; do not substitute results from
an older revision for a changed release candidate. The documentation images are
Simulator screenshots and the local Flutter previews are simulated; neither
replaces runtime checks on a device.

Run the publishing dry run from the prepared release source. If evaluating an
unapproved release whose manifest still contains `publish_to: 'none'`, remove
that guard only in an isolated staging copy:

```sh
# From the release source or staging copy, using the selected Flutter SDK.
fvm flutter pub publish --dry-run
```

Review every warning and the proposed file list. The dry run does not publish
anything. Inspect the archive contents for example sources, the license,
required iOS files, and absent credentials, caches, local paths, and unrelated
application files. Validate the README links and images from that file set.
Development commands that depend on excluded scripts or `.fvmrc` must direct
readers to a Git checkout.

## Publish and verify

After the release checks pass and publication is authorized, publish the same
reviewed source with `fvm flutter pub publish`. Complete the publishing account's
authentication if requested. Do not interpret a command starting or a browser
login succeeding as proof that the upload finished.

Verify the package version on pub.dev, download and inspect its archive, and
resolve that hosted version from a clean consumer with an empty Pub cache.
Check the published README, images, API documentation, and analysis results.
Record the matching release commit and immutable tag. Keep existing Git
consumers on their selected refs until their dependency source is deliberately
updated and validated.

## Automated publishing

Version [0.1.1](https://pub.dev/packages/duo_rail_kit/versions/0.1.1) was published
manually from [tag `0.1.1`](https://github.com/zawasystem/duo_rail_kit/releases/tag/0.1.1)
(commit `fc3b2e09ad693bee0c075d0f9f41c61df7d621f9`) on 2026-11-01 and is managed
by the `zawasystem.com` verified publisher. For later releases, the
[publishing workflow](../.github/workflows/publish.yml) runs on stable version
tags such as `0.1.2`. The tag must exactly match `pubspec.yaml`.

Enable GitHub Actions publishing in the package's pub.dev Admin page with
repository `zawasystem/duo_rail_kit` and tag pattern `{{version}}`. The workflow
uses GitHub OIDC with a short-lived token; no stored publishing secret is needed.
It runs package and example checks and a publication dry run before uploading.
Push a release tag only after reviewing the release contents and authorizing
publication. Do not move existing tags or push a test version to exercise CI.

This Ubuntu workflow does not compile or run the native iOS plugin. Complete
the applicable native checks above before creating a release tag, and verify
the workflow result and published archive afterward.

## Repository and CI review

- Review the entire public history, including published branches and tags, not
  only the current tree. Check source comments, commit metadata, example identifiers,
  generated platform files, and images for private application or personal
  information when adding or changing published refs.
- Review [third-party notices](../THIRD_PARTY_NOTICES.md) and the publish archive.
  MIT licensing of this package does not replace the Flutter template license or
  the font/icon terms for the documentation images. Check other dependency notices as well.
- Verify the private reporting channel described in [SECURITY.md](../SECURITY.md).
  Repository visibility alone does not enable private vulnerability reporting.
- Use isolated hosted or ephemeral runners for public contributions. Confirm
  the SDK is available, set timeouts and concurrency limits, and observe
  a successful CI run at the intended revision. A workflow file or local build
  is not proof that CI has run successfully.
- Verify ordinary HTTPS dependency resolution with a clean Pub cache. Review the
  application's selected tag or commit and resolved lockfile. See
  [Git dependency access](ci_authentication.md).
