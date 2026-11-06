# duo_rail_kit maintenance

This is an independent Flutter plugin. [README.md](README.md) describes usage
and behavioural constraints, [CONTRIBUTING.md](CONTRIBUTING.md) the commands,
native checks, CI and layer rule, and [docs/publication.md](docs/publication.md)
the release steps.

- Use FVM; `.fvmrc` pins the development SDK. Run the package and example
  checks in CONTRIBUTING.md.
- Keep runtime dependencies limited to Flutter. Keep the application's code,
  navigation, styling, assets, localisation, analytics and account
  integrations, and any credentials or customer data, out of the package.
- Write comments, test names, fixture labels, diagnostics, and documentation in
  concise English. Keep API constraints and non-obvious implementation reasons;
  omit duplicate explanations and application history.
- Preserve public APIs and the Dart/Swift method-channel contract unless a
  deliberately versioned change is requested. Keep event sequence ordering,
  physical left/right semantics, stable widget-tree structure, the
  `VerticalBarEdge` → `SideStatusBarInsets` wrapper order, and the layer rule.
- iOS uses Swift Package Manager only: no CocoaPods integration, no edits to
  generated plugin registration files. Preserve iOS 15.0 as the package
  minimum; the native trait API needs the iOS 27.1 SDK to compile.
- Native changes need the iOS host build and Simulator or device checks for
  rotation, folding, and Split View; Flutter tests do not compile Swift. Keep
  the example's platform projects free of signing credentials and application
  configuration.
- Pin actions to reviewed commit SHAs; the workflow files decide runner
  selection. Never run untrusted PR code on a persistent self-hosted runner or
  expose private credentials to it. Verify SDK availability and the runner's
  billing conditions.
- Update README and CHANGELOG when API or behaviour changes. Use English
  Conventional Commits. The licence is MIT, copyright 2026 ZAWA SYSTEM; the
  GitHub repository is public.
- Publish to pub.dev only as part of an explicitly authorised release, after
  reviewing the version, changelog, validation results, dry-run warnings, and
  archive contents. Public Git hosting, a dry run, or MIT licensing alone does
  not authorise publication. Published versions and tags stay fixed (use a new
  version for later changes); keep the tag and the archive tied to the reviewed
  source.
- Label simulated example renders clearly; they do not verify native trait
  events, rotation, folding, or Split View on a device.
- Never claim CI, a publication dry run, or runtime checks passed without the
  corresponding result for the revision under review.
