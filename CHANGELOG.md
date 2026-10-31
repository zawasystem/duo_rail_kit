# Changelog

## 0.1.0

- Extract the existing Flutter side-rail and safe-area helpers into an independent
  package, preserving the public Dart API and native implementation.
- Preserve the Swift Package Manager plugin and method-channel contract.
- Move the package's unit/widget and native-contract tests into this repository.
- Add standalone development configuration, usage documentation, and migration
  guidance. Remove tooling used only to synchronize copied package directories.
- Add hosted Flutter checks and an opt-in native build check using a disposable
  iOS host, with generated registration and compiled plugin symbol validation.
- Translate code comments, test descriptions, fixture labels, and diagnostics into
  concise English without changing runtime behavior or test assertions.
- Add the MIT License, contributor guidance, security reporting guidance, and a
  publication checklist. The GitHub repository is now public; pub.dev
  publication remains disabled.
- Document anonymous HTTPS Git dependency access and remove the need for
  package-specific GitHub App authentication in consumers.
- Add a runnable iOS/Android example, documented Flutter layout previews, and
  verified notices for Flutter templates and the rendering fonts/icons.
- Document SDK and native runtime verification limits. Public APIs, layout rules,
  and the Dart/Swift channel contract remain unchanged.
