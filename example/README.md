# Duo Rail Kit example

A runnable Flutter app with an actual navigation rail, bottom navigation, and a
small state-preservation lab. It uses the local package through `path: ../` and
works offline. The production entry point reads the real window and native edge;
it does not substitute simulated device values.

## Run

Clone the GitHub repository, then run from its root. The pinned SDK configuration
and optional preview renderer are development tools excluded from the pub.dev
archive.

```sh
cd example
fvm flutter pub get
fvm flutter devices
fvm flutter run -d <device-id>
```

The parent `.fvmrc` supplies the Flutter version. The iOS host requires Xcode 27.1
or later to compile the plugin's native trait API and supports iOS 15.0 or later
at runtime. Swift Package Manager is explicitly enabled in this app's pubspec;
CocoaPods is not used. Device signing is configured locally in Xcode when needed;
no team identifier, certificates, or provisioning profiles are included.

Android uses the standard Flutter Gradle toolchain. No application network calls,
Firebase configuration, account, analytics, or runtime permissions are needed.
The Flutter-generated **debug/profile** manifests retain the development-only
Internet permission for the VM service, hot reload, and debugging. The release
manifest declares no permissions. The launcher icons are the standard Flutter
example assets, not Duo Rail Kit branding; see the repository's third-party
notices.

## Explore

- **Layout** shows the current placement, occupied rail width, and top safe area.
  On supported iOS environments the native system edge takes precedence. Without
  an edge, a window at least 600 logical pixels wide uses a left rail; narrower
  windows use bottom navigation. The fallback width is an example-app choice.
- **State** has a tap counter and text field. Add taps, enter a note, and rotate,
  resize, fold, or change Split View. The values remain in the content widget's
  state across layout and destination changes. They are not persisted after the
  app closes.
- **About** explains the integration order and layout rules.
- The floating **+** adds a tap from any destination. Beside the system rail it
  uses `RailSideFab.locationOf` and sits 24 logical pixels above the content
  bottom, including when the keyboard is open. The scroll viewport stays inside
  the safe area, so caret and focus reveals stay clear of the status bar, but the
  content is painted past it and is not clipped at the status bar or home
  indicator. Scroll padding keeps the last controls reachable behind the
  floating action.

`lib/main.dart` launches `DuoRailExampleApp`; the integration is in `lib/app.dart`.
`VerticalBarEdge` wraps `SideStatusBarInsets` at the root. The shell uses
`RailPlacement.railSafeAreaOf` for both width and rail geometry, uses an 84-pixel
system column, and passes `centredRailSafeArea` to a scrollable `NavigationRail`.
It removes the occupied edge's safe-area padding from the body once.
`RailSideRow`, `RailSideFab`, and the body `MediaQuery` always stay in the tree.
The rail is inset above the keyboard while the inner content scaffold handles
its own keyboard resize, avoiding duplicate resizing of the body.

The native status-bar-hidden value refreshes on trait/geometry changes and app
resume, not continuously. The shared status-display exclusion band is a
conservative 152 logical pixels when the column contains a visible status bar.
These are existing package constraints; see the [package README](../README.md).

## Tests and simulated renders

```sh
fvm flutter analyze
fvm flutter test
```

The tests cover live entry, 84-pixel columns on either physical edge, width
fallbacks, state preservation when moving/removing the rail, RTL, enlarged text,
and keyboard/FAB geometry. They do not replace native device testing.

`DuoRailPreviewApp`, exported by `lib/main.dart`, is a test and local preview harness:

```dart
DuoRailPreviewApp(
  size: const Size(951, 669),
  safeArea: const EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  label: 'Duo landscape geometry',
)
```

Optional inputs include `statusBarHidden`, `textScale`, `viewInsets`, and
`textDirection`. Match the widget test view's logical size to `size`. Every
preview displays **SIMULATED LAYOUT** and its label. It injects geometry into the
same shell without querying the native channel; it is not an iOS emulator or
evidence that native rotation, folding, or Split View events work. No simulated
device switcher is exposed in the running app.

`tool/render_screenshots.dart` renders four such previews into
`build/simulated_previews/` (ignored by Git) for local layout checks:

```sh
fvm flutter test tool/render_screenshots.dart
```

The package README's images are Simulator screenshots of the normal entry point
instead; see [doc/images/README.md](../doc/images/README.md).
