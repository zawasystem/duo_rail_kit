# Dependency migration

## Switching from a local copy

1. Replace the local path dependency with the public Git repository, pinned to a
   release tag such as `0.1.0` or a reviewed full commit SHA. See
   [Installation](README.md#installation) for the dependency declaration.
2. Run `fvm flutter pub get` and review the resolved dependency in
   `pubspec.lock`. Commit the manifest and lockfile together. Existing
   `package:duo_rail_kit/duo_rail_kit.dart` imports remain valid.
3. Remove the duplicate package sources and tests from the application once the
   dependency resolves. Keep application integration and layout tests. Flutter
   does not run a dependency's own tests when testing an application.
4. Preserve the root wrapper order, native SPM configuration, and application
   layout choices. Do not rename the native class, SPM product, or method channel
   during dependency migration. Let Flutter generate plugin registration files.
5. Follow [Git dependency access](docs/ci_authentication.md) for CI setup.
6. Run the validation checks below before merging the dependency change.

## Updating a Git dependency

Choose a release tag after reviewing [CHANGELOG.md](CHANGELOG.md). Update the
manifest, run `fvm flutter pub get`, and review the resolved SHA and dependency
changes in the lockfile. Published tags stay fixed; documentation updates on
`main` do not move them.

## Integration checks

- Run package and application analysis and tests.
- Build an iOS host with the [required SDK](README.md#requirements) and verify
  that the plugin is registered.
- Check Duo outer/inner orientations, both Split View sides, rotation, folding,
  keyboard and large-text layouts, and state preservation.
- Check ordinary phone, tablet, and Android layouts.

Application navigation, styling, breakpoints, grids, overlays, and content
spacing remain application responsibilities. Passing package tests alone does
not verify an application's integration or native runtime behavior.

To roll back, restore the previous manifest and lockfile, along with local
package files if they were removed. Switching the dependency source does not
require a persisted application data migration.
