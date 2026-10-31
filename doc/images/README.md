# Example images

These PNGs are rendered from the runnable Flutter example with simulated window
sizes, system edges, and safe-area insets. They are **not native device captures**
and do not demonstrate native trait delivery. Every image includes a visible
`SIMULATED LAYOUT` label. No customer data or external images are used.

| Image | Logical size | System edge | Simulated safe area (points) |
| --- | --- | --- | --- |
| `overview.png` | 951 × 669 | Right | Right 84, bottom 34 |
| `duo-right.png` | 466 × 678 | Right | Right 84, bottom 34 |
| `split-left.png` | 469 × 669 | Left | Bottom 34 |
| `phone.png` | 393 × 852 | None | Top 59, bottom 34 |

The files are exported at 2× pixel density. Reproduce them from the repository:

```sh
cd example
fvm flutter pub get
fvm flutter test tool/render_screenshots.dart
```

The renderer reads Roboto and Material Icons from the selected Flutter SDK's
cached material fonts. It does not download fonts or include their binaries in
the package. See [third-party notices](../../THIRD_PARTY_NOTICES.md) for their
source and licenses. Example code and these renders otherwise use the package's
[MIT License](../../LICENSE).

The capture tool is repository-only; a pub.dev archive includes the finished
images, not the tool. Use the repository checkout to regenerate them.
