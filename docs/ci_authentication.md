# Public Git dependency access

The GitHub repository is public. Developer machines, application CI, and
Dependabot can fetch `https://github.com/zawasystem/duo_rail_kit.git` without
authentication. This does not publish the package on pub.dev.

## Consumer configuration

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

After checking out the application and installing its Flutter SDK, CI and release
jobs only need their normal `flutter pub get` step. They do not need a separate
package checkout, token, Git URL rewrite, or credential-bearing dependency URL.
The consumer repository itself can remain private.

The five consumer migration branches use `ref: '0.1.0'`, with
`b21e358959c31e077f062ff4aa8d387c5e1ea764` as the lockfile's `resolved-ref`.
They do not follow `main`. Published version tags stay fixed; selecting a newer
release tag and updating its lockfile is a separate reviewed change.

The temporary `compat/initial-extraction` tag was removed after these branches
were validated and pushed. See [migration history](../MIGRATION.md) for the effect
on historical consumer commits that still reference the original extraction.

## Dependabot

No package-specific Dependabot secret or private repository access grant is
needed. Consumer configurations still exclude automatic version updates for
`duo_rail_kit`: the reviewed pin is updated deliberately across applications.
This policy is independent of repository visibility. Dependabot can resolve the
public Git dependency while updating other packages.

## Removing the former private-repository setup

The consumer migration branches no longer use `prepare-duo-rail-kit` in CI or
Android/iOS release jobs. Its helper files and tests have also been removed.
Normal dependency resolution uses the canonical HTTPS URL and the selected tag
or commit recorded in the manifest and lockfile.

`DUO_RAIL_KIT_APP_CLIENT_ID` and `DUO_RAIL_KIT_APP_PRIVATE_KEY` are no longer
consumed by those workflows. If they were registered as Actions or Dependabot
secrets, they can be removed after all branches that use the old action have been
retired. Likewise, a dedicated package-only GitHub App installation/key or
Dependabot private-access grant can be removed if one was created and has no
remaining users. No credential or organization-setting deletion is implied by
this source change.

Keep authentication for private application checkouts, signing certificates,
store uploads, and other services. Those credentials have a separate purpose.
Public access to this dependency also does not change billing or runner access
for a consumer's private repository.

## Verification

On 2026-11-01, the `0.1.0` tag resolved to the SHA above through the README's
installation example with an empty Pub cache. The check disabled Git system/global
configuration, credential helpers, and interactive prompting.
See the dated record in [publication preparation](publication.md).

For future changes, verify that the selected tag or commit resolves to the
expected SHA with a fresh cache, review the lockfile, and check the consumer CI
result. A successful local fetch proves
public dependency access, not signing, store delivery, or completion of CI.
