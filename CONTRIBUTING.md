# Contributing

Read [README.md](README.md) for the API and its limitations, and
[CLAUDE.md](https://github.com/zawasystem/duo_rail_kit/blob/main/CLAUDE.md) for
the maintenance rules. Contributions are made under the [MIT License](LICENSE).

## Checks

Work in a Git checkout: `.fvmrc`, `tool/` and the workflows are not in the
pub.dev archive. `.fvmrc` pins the development SDK (Flutter 3.50.0); the
`pubspec.yaml` lower bound (3.47.8) is the advertised minimum. From the package
root:

```sh
fvm flutter pub get
fvm dart format lib test example/lib example/test example/tool  # 120 columns
fvm flutter analyze
fvm flutter test
```

Then run `fvm flutter pub get`, `fvm flutter analyze` and `fvm flutter test` in
`example/` (its [README](example/README.md) explains how to run the app).

## Native changes

Flutter tests do not compile Swift. After a change under `ios/`, run
`fvm exec bash tool/build_ios_host.sh` on macOS with Xcode 27.1 or newer and
its iOS Simulator SDK. It builds the example's `lib/` in a temporary unsigned
debug Simulator host, checks the generated SPM manifest, the plugin
registration and the plugin's symbols, and removes the host; it installs
nothing. It does not exercise runtime events: check rotation, folding, Split
View and the status display on a Simulator or device.

## CI

- [`ci.yml`](https://github.com/zawasystem/duo_rail_kit/blob/main/.github/workflows/ci.yml)
  checks the package and the example on Ubuntu with Flutter 3.47.8 and 3.50.0.
  Its `native_ios` job runs the host build on a GitHub-hosted macOS runner only
  when dispatched from `main` with `native_ios`; it fails without the iOS 27.1
  SDK.
- [`publish.yml`](https://github.com/zawasystem/duo_rail_kit/blob/main/.github/workflows/publish.yml)
  runs on stable version tags: `minimum_sdk` (3.47.8) and `validate` (3.50.0,
  with a publication dry run) run the checks without an OIDC token, then
  `publish` holds `id-token: write` and runs first-party steps only (checkout,
  tag check, the Flutter SDK at its reviewed commit, `dart-lang/setup-dart`,
  `flutter pub publish --force`). An optional pub.dev environment requirement
  is the owner's decision (see
  [docs/publication.md](https://github.com/zawasystem/duo_rail_kit/blob/main/docs/publication.md)).

## Pull requests

Keep changes focused, add a regression test when behaviour changes, and update
the README and CHANGELOG when the API or behaviour changes. Put the commands you
ran and their results in the pull request, including checks that could not run.
Do not include credentials, signing files, customer data, or build artefacts.
Use [SECURITY.md](SECURITY.md) for security reports.

From a file in the pub.dev archive, link files that `.pubignore` leaves out
(such as `CLAUDE.md`, `docs/`, `.github/`) by absolute GitHub URL
(`https://github.com/zawasystem/duo_rail_kit/blob/main/...`) and other files
relatively.

## Layer rule

`lib/src` has four one-way layers, `core/`, `edge/`, `layout/` and `toolbar/`;
each file is ranked by its path: `core/` 0, `edge/` 1, `layout/` 2, `toolbar/`
3, `toolbar/shared/` 4, and `toolbar/vertical_bar_toolbar.dart` with its parts
in `toolbar/page/` and `toolbar/shell/` 5. A file imports only `dart:`,
`package:flutter/` and files of its own or a lower rank, without cycles; parts
have no imports, and a `/// @docImport` is the only reference that may point
upwards. The page and the shell are parts of one library because they share a
private protocol in both directions. `lib/duo_rail_kit.dart` exports each file
with a `show` list. `test/source_layers_test.dart` enforces both rules.
