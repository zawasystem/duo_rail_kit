# duo_rail_kit maintenance

This is an independent Flutter plugin. Read [README.md](README.md) for usage and
behavioral constraints, [MIGRATION.md](MIGRATION.md) for dependency migration, and
[docs/publication.md](docs/publication.md) for release preparation.

- Use FVM for Flutter and Dart commands; `.fvmrc` pins the development SDK.
- Keep runtime dependencies limited to Flutter. Do not import application code,
  assets, localization, analytics, credentials, or customer data.
- Write code comments in concise English. Keep API constraints and non-obvious
  implementation reasons; omit duplicate explanations and application history.
- Use English for test names, fixture labels, diagnostics, and documentation too.
- Preserve public APIs and the Dart/Swift method-channel contract unless a
  deliberately versioned change is requested. Keep event sequence ordering,
  physical left/right semantics, and stable widget-tree structure.
- iOS uses Swift Package Manager only. Do not add CocoaPods integration or edit
  generated plugin registration files. Preserve iOS 15.0 as the package minimum;
  the native trait API requires the iOS 27.1 SDK to compile.
- Run `fvm flutter pub get`, `fvm flutter analyze`, and `fvm flutter test` from
  the package root. Format changed Dart with `fvm dart format` (120 columns).
- Flutter unit/widget tests do not compile Swift. Native changes also require an
  iOS host build (`fvm exec bash tool/build_ios_host.sh`) and device/simulator
  checks for rotation, folding, and Split View. The script removes its temporary
  host on exit and checks compilation/linking, not runtime event delivery.
- Validate the runnable example separately: from `example/`, run
  `fvm flutter pub get`, `fvm flutter analyze`, and `fvm flutter test`. Keep its
  platform projects free of signing credentials and application configuration.
- Keep action dependencies pinned to reviewed commit SHAs. Treat the workflow
  file as the source of truth for runner selection. Never run untrusted PR code
  on a persistent self-hosted runner or expose private credentials to it. Verify
  required SDK availability and the selected runner's billing conditions.
- Update README and CHANGELOG when API or behavior changes. Use English
  Conventional Commits. The approved license is MIT, copyright 2026 ZAWA SYSTEM.
  The GitHub repository is public. Publish to pub.dev only as part of an
  explicitly authorized release. Before publishing, review the version,
  changelog, validation results, dry-run warnings, and archive contents.
  Published versions and tags stay fixed; use a new version for later changes.
  Keep the release tag and published archive tied to the reviewed source.
  Public Git hosting, a dry run, or MIT licensing alone does not authorize
  publication.
- Label simulated example renders clearly. They do not verify native trait
  events, rotation, folding, or Split View behavior on a device.
- Never claim CI, a publication dry run, or runtime checks passed without the
  corresponding result for the revision under review.
