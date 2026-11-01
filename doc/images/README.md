# Example images

These PNGs are screenshots of the runnable example's normal entry point
(`example/lib/main.dart`, which reads the native edge) on the iOS 27.2 Simulator
in Xcode 27.2. Each shows the example's `LIVE LAYOUT` badge. They show the
system edge as the Simulator delivers it, not behavior on physical hardware.
No customer data or external images are used.

| Image | Device and display | Window (points) | Placement shown |
| --- | --- | --- | --- |
| `overview.png` | iPhone Duo, inner display, landscape | 951 × 669 | Right rail in the system column |
| `duo-right.png` | iPhone Duo, outer display, portrait | 466 × 678 | Right rail in the system column |
| `split-left.png` | iPhone Duo, inner display, left app in Split View | 469 × 669 | Left rail on the system edge |
| `phone.png` | iPhone 17, portrait | 402 × 874 | Bottom bar (width fallback) |

The files are scaled to 2× the window size. `split-left.png` is cropped to the
left app's window; its rounded window corners are transparent.

## Reproducing

1. From `example/`, build the app with `fvm flutter pub get` and
   `fvm flutter build ios --simulator --debug`, then install and launch it with
   `xcrun simctl install <device> build/ios/iphonesimulator/Runner.app` and
   `xcrun simctl launch <device> dev.example.duoRailKitExample`.
2. Use the light appearance and a fixed status bar:
   `xcrun simctl ui <device> appearance light` and
   `xcrun simctl status_bar <device> override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi`.
3. Fold or unfold the iPhone Duo with Device Hub's Closed and Open controls. For
   Split View, long-press the app icon on the Home screen, choose the Split View
   action, and open a second app on the right.
4. Capture a display with `xcrun simctl io <device> screenshot --display=<port> <file>`.
   `xcrun simctl io <device> enumerate` lists the ports: the inner display's
   framebuffer is 2007 × 2853 pixels and the outer display's is 1398 × 2034.
   Scale each capture to 2× the window size.

`example/tool/render_screenshots.dart` renders the `DuoRailPreviewApp` fixture
with simulated geometry into `example/build/simulated_previews/` for local layout
checks. Those renders show `SIMULATED LAYOUT`, are not committed, and are not
used here.

The screenshots contain text drawn by iOS in its system font, Simulator
status-bar elements, and Material Icons glyphs from the font bundled into the
app. See [third-party notices](../../THIRD_PARTY_NOTICES.md). Example code and
these images otherwise use the package's [MIT License](../../LICENSE).
