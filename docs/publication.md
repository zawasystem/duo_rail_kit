# Publication preparation

The GitHub repository is public and uses the [MIT License](../LICENSE),
copyright 2026 ZAWA SYSTEM. Version 0.1.0 is available through Git and is not
published on pub.dev. Keep `publish_to: 'none'` in `pubspec.yaml` until pub.dev
publication is separately authorized.

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
