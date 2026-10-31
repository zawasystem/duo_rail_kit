# Public Git dependency access

The GitHub repository is public. Developer machines, application CI, and
Dependabot can fetch `https://github.com/zawasystem/duo_rail_kit.git` without
authentication. This does not publish the package on pub.dev.

## Dependency configuration

Pin the dependency to a release tag or a reviewed full commit SHA in
`pubspec.yaml`, and commit the resulting `pubspec.lock` with its resolved SHA.
Keep the canonical HTTPS URL in both files:

```yaml
dependencies:
  duo_rail_kit:
    git:
      url: https://github.com/zawasystem/duo_rail_kit.git
      ref: '0.1.0'
```

The `0.1.0` tag points to `b21e358959c31e077f062ff4aa8d387c5e1ea764`.
Check that the lockfile's `resolved-ref` matches the reviewed revision. Published
version tags stay fixed; selecting a newer release tag and updating the lockfile
is a separate reviewed change. A tagged dependency does not follow `main`.

## CI setup

After checking out the application and installing its Flutter SDK, resolve the
dependency with the normal `flutter pub get` step. No credentials or separate
checkout are required for this public package. Keep credentials out of dependency
URLs and do not add Git URL rewrites for package access.

Authenticate application checkout, signing, and deployment separately as needed.
Public package access does not replace those integrations.

## Dependabot

Dependabot can resolve the public Git dependency without package-specific
credentials. Configure automatic updates or manual review according to the
application's dependency policy. Review the selected revision and resulting
lockfile, and run application checks before accepting an update.

## Verification

For a clean installation check, resolve the dependency with an empty Pub cache
and without Git credential helpers, interactive prompting, or URL rewrites.
Verify that the selected tag or commit resolves to the expected SHA and review
the lockfile diff for unrelated changes.

Run the application's analysis and tests, and inspect the CI result for the
revision being integrated. A successful local fetch verifies dependency access;
it does not establish signing, store delivery, native behavior, or CI completion.
See [publication preparation](publication.md) for package release checks.
