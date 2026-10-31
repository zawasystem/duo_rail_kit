# Extraction and migration

## Source snapshot

Version 0.1.0 was extracted from tracked files at source commit
`8c08b1d6f49d4a9f0e584f571aa6ae270c8fa4cc` on 2026-10-31.
The source package lived at `app/packages/duo_rail_kit`; its tests lived at
`app/test/duo_rail_kit`. The source working tree was clean when copied.

At the extraction revision, the six files under `lib/`, the native Swift source,
and `Package.swift` were byte-for-byte copies. Public exports, constants,
method-channel names, payloads, event sequencing, widget behavior, and the iOS
minimum deployment target are unchanged. The extraction retained source comments
to make its provenance auditable.

During extraction, only tracked package/test files were copied. No application
source, account data, credentials, environment configuration, build output, SDK
caches, `.swiftpm`
directories, or generated Flutter/Xcode files were imported.

## Initial extraction changes

- Add package version `0.1.0`, standalone development dependencies, analysis
  options, FVM configuration, and generated-file exclusions.
- Keep `publish_to: 'none'`. The repository was initially private. MIT licensing
  was subsequently approved, and the owner made GitHub hosting public on
  2026-11-01. Publishing to pub.dev still requires separate authorization.
- Move six existing test files to `test/`. Adjust the Swift source test's relative
  path and its documentation for the new package root; keep its assertions.
- Replace the old copy-maintenance README with independent usage documentation,
  and add a changelog, generic example, and shared contributor instructions.
  Publication preparation adds runnable iOS/Android example hosts; these were
  created for this package and are not copied application projects.
- Add Ubuntu analysis/test CI and an opt-in private macOS native job. The native
  script generates a temporary Flutter iOS host using the generic example,
  explicitly enables SPM, builds without signing, and checks registration and
  defined plugin symbols. Generated host files are removed on exit.
- Omit `tool/sync.sh`: it copied package and test directories into applications,
  whereas consumers should now resolve a single versioned package.
- Omit `kit_digest_test.dart`: it enforced a constant digest across those copied
  directories. The source snapshot's FNV-1a digest was `4797e9db2b42a447`; it also
  covered documentation and old paths, so it is not a checksum of this repository.
  Reviewed Git revisions and application lockfiles replace this copy-sync guard.

No application's dependency or integration was changed as part of the package
extraction. Existing application-specific rail layout, text, themes, breakpoints,
grid calculations, overlays, and regression tests stay with their owners.

## Migrating a consumer

1. Replace the copied path dependency with this repository, pinned to a release
   tag such as `0.1.0` or a reviewed full commit SHA. For local validation, use a
   path to a checkout instead.
2. Use the public HTTPS URL, which needs no package-specific authentication.
   Remove any former private-package checkout/token steps from CI and release
   workflows; keep unrelated signing authentication. See
   [Git dependency access](docs/ci_authentication.md).
3. Run `fvm flutter pub get` and review the resolved dependency and application
   lockfile. Existing `package:duo_rail_kit/duo_rail_kit.dart` imports remain valid.
4. Remove the copied package directory and its six package tests, old digest test,
   and copy-sync instructions. Keep all application integration/layout tests.
   The package tests now run here; Flutter does not run a dependency's tests when
   testing an application.
5. Preserve the root wrapper order, native SPM configuration, all application
   layout choices, and generated plugin registration. Do not rename the package,
   native class, SPM product, or method channel as part of dependency migration.
6. Run package and application analysis/tests. Build an iOS host with the required
   SDK and verify the plugin is registered. Compare Duo outer/inner orientations,
   both Split View sides, keyboard and large-text layouts, and state preservation.
   Check unaffected phone/tablet/Android layouts as well.

Rollback consists of restoring the previous dependency and lockfile (and copied
files if they were removed). No persisted application data migration is needed.

## Publication preparation

The package now uses the [MIT License](LICENSE), with copyright held by
ZAWA SYSTEM. Publication preparation replaces the private self-hosted native CI
job with an explicit manual job on a GitHub-hosted macOS runner. Runtime code and
the native contract remain unchanged by the packaging work. The [example](example/README.md) has its own iOS/Android hosts;
its simulated previews demonstrate Flutter layout, not native device behavior.

The GitHub repository is public as of 2026-11-01. Consumers can resolve their
existing reviewed SHA over HTTPS without authentication. The
`compat/initial-extraction` tag retains the original extraction revision for
those consumers; rewriting `main` does not change their fixed dependency.

Keep `publish_to: 'none'` until pub.dev publication is separately authorized.
Follow [docs/publication.md](docs/publication.md) for SDK availability,
release-candidate tests, the pub.dev dry run, history/archive review, and CI
verification. GitHub visibility does not establish a pub.dev release or native
runtime compatibility.
