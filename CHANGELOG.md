# Changelog

## 0.2.0

- Add `TopBarRegion`, `VerticalBarRegion`, and `BarRegionScope`: the system's
  top bar region (the band beside the Duo inner portrait status display) and the
  vertical bar's item region (iOS 27.1+, phone idiom). They arrive as optional
  `topBar` and `verticalBar` payload keys; the channel, methods, existing keys,
  and ordering are unchanged, and screens without a region get the 0.1.1
  payload. The plugin also resends when the top bar layout guide moves, observed
  with one hidden, non-interactive view.
- `VerticalBarEdge` now builds `VerticalBarEdgeScope` > `BarRegionScope` >
  child. Tests that build `VerticalBarEdgeScope` directly get null regions; add
  a `BarRegionScope`.
- Add `VerticalBarPage` and its types (`VerticalBarSlots`, `VerticalBarAction`,
  `VerticalBarMenuItem`, `VerticalBarInvocation`, `VerticalBarCell`,
  `VerticalBarBack`, and three typedefs): a full-window pushed page's back
  control and actions in the vertical bar column, where UIKit puts them, with
  an overflow menu. `VerticalBarCell.tooltipConstraints` gives application
  controls the default controls' tooltip constraints.
- Add `VerticalBarShell` (with `railPaddingOf`) and `VerticalBarRailEnd`: the
  same for tab pages, above a rail on the column's edge.
- Add `VerticalBarColumn`, and `RailPlacement.systemRailWidth` (96), which
  centres a rail and its cells on the vertical bar.
- Add `RailLayout`, which reads a rail's placement and safe area in one context
  and derives its width and padding from them.
- Upgrading: 0.1.1 APIs and constants behave as before and need no code
  changes. A caret constraint on 0.1.x does not select 0.2.0; update the
  manifest and lockfile, and rebuild the iOS app for the new native code. To
  roll back, restore the previous manifest and lockfile.
- Checked on the iOS 27.2 Simulator only; see the README's
  [Limitations](README.md#limitations).
- Example: a band-aware app bar, region readouts, a detail page with column
  actions, and tab pages in a `VerticalBarShell`, using `RailLayout`.

## 0.1.1

- Prepare the plugin for its initial pub.dev release, with hosted-package
  installation instructions and publication metadata.
- Keep the public Dart API and native iOS implementation unchanged from 0.1.0.
- Example: the content is painted past the top and bottom safe areas instead of
  being clipped below the status bar and above the home indicator. The scroll
  viewport stays inside the safe area, so caret and focus reveals stay clear of
  the status bar.
- Documentation images are now iOS 27.2 Simulator screenshots of the example's
  normal entry point: iPhone Duo outer and inner displays, the left Split View
  app, and iPhone 17. The simulated preview renderer writes to
  `example/build/simulated_previews/` instead of `doc/images/`.

## 0.1.0

- Provide Flutter side-rail placement, safe-area spacing, stable content layout,
  and floating-action-button helpers.
- Integrate native iOS edge detection through Swift Package Manager, with
  ordered method-channel events and a width-based fallback.
- Include unit/widget and native-contract tests, standalone development
  configuration, usage documentation, and dependency migration guidance.
- Add hosted Flutter checks and an opt-in native build check using a disposable
  iOS host, with generated registration and compiled plugin symbol validation.
- Include the MIT License, contributor and security reporting guidance, and a
  publication checklist. This version was distributed through public Git
  hosting only; pub.dev publication was disabled.
- Add a runnable iOS/Android example, simulated Flutter layout previews, and
  notices for Flutter templates and rendering fonts/icons.
- Document SDK requirements, geometry assumptions, and native runtime
  verification limits.
