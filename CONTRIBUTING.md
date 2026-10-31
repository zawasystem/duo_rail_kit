# Contributing

Read [README.md](README.md) for the API and its limitations, and
[CLAUDE.md](https://github.com/zawasystem/duo_rail_kit/blob/main/CLAUDE.md) for the shared maintenance instructions. Contributions are
made under the [MIT License](LICENSE).

Use the SDK selected by `.fvmrc`. From the package root:

```sh
fvm flutter pub get
fvm dart format lib test example/lib example/test
fvm flutter analyze
fvm flutter test
```

Validate the example from `example/` with `fvm flutter pub get`,
`fvm flutter analyze`, and `fvm flutter test`. See its
[README](example/README.md) for running the app.

Keep changes focused and include a regression test when behavior changes.
Preserve physical left/right semantics, event sequence ordering, stable widget
state, and the `VerticalBarEdge` → `SideStatusBarInsets` wrapper order. Keep
application navigation, styling, assets, and account integrations out of the
package. Update the README and changelog when the API or behavior changes.

Native changes need `fvm exec bash tool/build_ios_host.sh` with the iOS 27.1 SDK,
plus runtime checks on a suitable simulator or device. Dart tests and simulated
renders cannot validate native trait delivery. Include the commands and results
in the pull request, including any checks that could not run.

Do not include credentials, signing files, customer data, or generated build
artifacts. Use [SECURITY.md](SECURITY.md) for security reports and
[docs/publication.md](https://github.com/zawasystem/duo_rail_kit/blob/main/docs/publication.md) for release preparation.
