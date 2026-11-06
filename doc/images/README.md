# Example images

Screenshots of the example's normal entry point (`example/lib/main.dart`, which
reads the native edge, with its `LIVE LAYOUT` badge) on the iOS 27.2 Simulator
in Xcode 27.2, taken on 2026-11-04 (`overview.png`, `duo-right.png`, and
`split-left.png` on 2026-11-06). What has been checked where is in the README's
[Verification status](../../README.md#verification-status). No customer data or
external images are used.

| Image | Device and display | Window (points) | Shown |
| --- | --- | --- | --- |
| `overview.png` | iPhone Duo, inner, landscape | 951 × 669 | Right rail; tab actions in the column above it |
| `top-band.png` | iPhone Duo, inner, portrait | 669 × 951 | App bar in the top band; left rail (width rule) |
| `duo-right.png` | iPhone Duo, outer, portrait | 466 × 678 | Right rail; tab actions in the column above it |
| `split-left.png` | iPhone Duo, inner, left Split View app | 469 × 669 | Left rail on the system edge |
| `phone.png` | iPhone 17, portrait | 402 × 874 | Bottom bar (width fallback) |
| `vertical-toolbar.png` | iPhone Duo, inner, landscape, detail page | 951 × 669 | Back control, seven actions, and overflow cell in the column |

Files are scaled to 2× the window size. `split-left.png` is cropped to the left
app's window, with transparent rounded corners.

## Reproducing

1. From `example/`: `fvm flutter pub get`,
   `fvm flutter build ios --simulator --debug`,
   `xcrun simctl install <device> build/ios/iphonesimulator/Runner.app`, and
   `xcrun simctl launch <device> dev.example.duoRailKitExample`.
2. `xcrun simctl ui <device> appearance light` and
   `xcrun simctl status_bar <device> override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi`.
3. Fold, unfold, and rotate with Device Hub's Closed, Open, Rotate Left, and
   Rotate Right controls. For Split View, in inner landscape, long-press the app
   icon, choose Split View, and open a second app (Files) on the right.
4. For `vertical-toolbar.png`, in inner landscape, tap **Open detail**, turn on
   More actions, and tap Share in the column.
5. `xcrun simctl io <device> screenshot --display=<port> <file>`; `enumerate`
   lists the ports. Scale to 2×.

Simulated renders from `example/tool/render_screenshots.dart` (labelled
`SIMULATED LAYOUT`) are not committed or used here.

They contain iOS system-font text, Simulator status-bar elements, and Material
Icons glyphs ([third-party notices](../../THIRD_PARTY_NOTICES.md)); otherwise
the package's [MIT License](../../LICENSE) applies.
