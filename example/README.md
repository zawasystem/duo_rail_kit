# Duo Rail Kit example

A runnable app with a navigation rail, bottom navigation, and a small
state-preservation lab. It uses the local package (`path: ../`), works offline,
and its entry point reads only the real window and native edge.

## Run

From a clone of the repository (the pinned SDK and the preview renderer are not
in the pub.dev archive):

```sh
cd example
fvm flutter pub get
fvm flutter devices
fvm flutter run -d <device-id>
```

The parent `.fvmrc` supplies the Flutter version, the iOS host follows the
package [requirements](../README.md#requirements), and this pubspec enables
Swift Package Manager. Signing is local to Xcode: the project holds no team,
certificates, or profiles. The app makes no network calls and needs no account
or runtime permissions; only the generated Android debug and profile manifests
keep the development Internet permission.

## Explore

Values in this README are logical pixels (iOS points).

- **Layout** shows the placement, rail width, top safe area, and the regions iOS
  reports; without a native edge, windows at least 600 wide get a left rail (an
  example choice).
- **Open detail** pushes a `VerticalBarPage`; where the
  [vertical bar column is used](../README.md#when-the-column-is-used), its back
  control and actions move into it. **More actions** adds seven, for ten; on Duo
  inner landscape the last three overflow.
- On the **tab screens**, where the
  [shell uses the column](../README.md#tab-shells), `VerticalBarShell` moves the
  reset and About actions into it above the system rail; **Rail tabs** in the
  State lab adds placeholder tabs (3, 5, 6, or 7 in all), and actions that no
  longer fit overflow.
- **State** keeps a counter and a text field across rotation, folding, Split
  View, and tab changes.
- In the **top band** (the band beside the status display, Duo inner portrait)
  each app bar's toolbar row moves into it.
- The **+** button uses `RailSideFab.locationOf` beside the system rail.

## Where the code is

`lib/main.dart` launches `DuoRailExampleApp`; `lib/app.dart` holds the
integration:

- `_DemoShell` reads `RailLayout.of` once, passes its `centredSafeArea`,
  through `VerticalBarShell.railPaddingOf`, to a scrollable `NavigationRail`
  ending with `VerticalBarRailEnd`, removes the rail's edge from the body with
  `removeRailEdge`, and gives the tab screens `contentRect` as their pane. The
  shell, `RailSideFab`, and the body `MediaQuery` always stay in the tree.
- `_DemoAppBar` moves its toolbar row into the `TopBarRegion.of` band, padded
  for its pane.
- `_DetailPage` builds its `Scaffold` in `VerticalBarPage` and reuses
  `_DemoAppBar` with the whole window as its pane.

## Tests and simulated renders

`fvm flutter test` covers live entry, the readouts, both column edges, width
fallbacks, state preservation, RTL, large text, the keyboard, the FAB, the top
band, and the column's cells, overflow menu, and fallbacks on the detail page
and above the rail; it does not replace device testing.

`DuoRailPreviewApp`, exported by `lib/main.dart`, is a test and preview harness:

```dart
DuoRailPreviewApp(
  size: const Size(951, 669),
  safeArea: const EdgeInsets.only(right: 84, bottom: 34),
  edge: HorizontalEdge.right,
  label: 'Duo landscape geometry',
)
```

Other inputs are `statusBarHidden`, `textScale`, `viewInsets`, `textDirection`,
`topBar`, and `verticalBar` (with an optional `topBarTop`). A region is used
only when its `viewSize` matches `size` (set the test view's logical size to
`size`) and a `topBar`'s `safeTop` matches the top safe area (`safeArea.top`,
or the 16 `SideStatusBarInsets` adds). Every preview shows **SIMULATED LAYOUT**:
it injects geometry without the native channel, so it proves nothing about
native rotation, folding, or Split View events.

`fvm flutter test tool/render_screenshots.dart` renders seven previews into
`build/simulated_previews/` (ignored by Git). The package's images are Simulator
screenshots instead ([details](../doc/images/README.md)).
