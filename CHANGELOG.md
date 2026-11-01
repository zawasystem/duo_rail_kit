# Changelog

## Unreleased

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
  publication checklist. The package is available through public Git hosting;
  pub.dev publication remains disabled.
- Add a runnable iOS/Android example, simulated Flutter layout previews, and
  notices for Flutter templates and rendering fonts/icons.
- Document SDK requirements, geometry assumptions, and native runtime
  verification limits.
