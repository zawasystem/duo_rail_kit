# Publication checklist

The package uses the [MIT License](../LICENSE), copyright 2026 ZAWA SYSTEM.
This checklist is not evidence that a release has completed.

## Authorisation

Publish only with explicit authorisation for that release. Published versions
and tags stay fixed: use a new version for later changes and never move a tag.

## Release record

| Version | State | Source |
| --- | --- | --- |
| `0.1.0` | Git tag only | `b21e358959c31e077f062ff4aa8d387c5e1ea764` |
| `0.1.1` | Published manually on 2026-11-01; verified publisher `zawasystem.com` | [tag `0.1.1`](https://github.com/zawasystem/duo_rail_kit/releases/tag/0.1.1), `fc3b2e09ad693bee0c075d0f9f41c61df7d621f9` |
| `0.2.0` | Published by the GitHub Actions workflow on 2026-11-07 (JST); verified publisher `zawasystem.com` | [tag `0.2.0`](https://github.com/zawasystem/duo_rail_kit/releases/tag/0.2.0), `454b4cfbbef9a774678619b571b0e1e0a2dd1ec8` |
| `0.2.1` | Published by the GitHub Actions workflow on 2026-11-07 (JST), verified publisher `zawasystem.com` | [tag `0.2.1`](https://github.com/zawasystem/duo_rail_kit/tree/0.2.1), `377ca44680fb65216b83359e1bccbf9f26331f5b` |

## Release-candidate checks

- Align `pubspec.yaml`, the changelog, and the README's installation
  instructions; check the publishing account and package destination.
- Run the package, example and native checks in
  [CONTRIBUTING.md](../CONTRIBUTING.md) with the minimum and the development
  SDK; keep the minimum in both workflows equal to the `pubspec.yaml` lower
  bound and confirm a clean installation from public SDK distributions.
- Build the iOS example (CocoaPods is not provided) and the Android example,
  and check ordinary phone and tablet layouts.
- On a Simulator or device, check the Duo orientations, both Split View sides,
  rotation, folding, and status-bar visibility. Record the `topBar` and
  `verticalBar` payloads, including `topBarTop`, on Duo inner portrait and
  landscape, both Split View windows, iPhone, and iPad, and check the example's
  detail page with and without the vertical bar column.
- The fixed 84-point column and 152-point bound below the status display come
  from Simulator measurements: recheck them against the OS builds advertised as
  supported ([README limitations](../README.md#limitations)).
- Record commands, SDKs, the tested revision, and results; never reuse results
  of an older revision. Documentation images and example previews do not
  replace runtime checks.

## Dry run

From the release source (the root `pubspec.yaml` has no `publish_to`; the
example keeps `publish_to: 'none'`):

```sh
fvm flutter pub publish --dry-run
```

Review every warning and the file list: example sources, the licence, the iOS
files, and no credentials, caches, local paths, or unrelated application files.
Check the README links and images from that file set; commands that need
excluded scripts or `.fvmrc` must point readers to a Git checkout.

## Publish via OIDC

The [publishing workflow](../.github/workflows/publish.yml) runs on stable
version tags such as `0.2.0`, which must exactly match `pubspec.yaml`, and
publishes with a short-lived GitHub OIDC token (no stored secret). It needs
GitHub Actions publishing on the package's pub.dev Admin page with repository
`zawasystem/duo_rail_kit` and tag pattern `{{version}}`; requiring a GitHub
Actions environment there is optional and the owner's decision, and needs an
`environment:` line with the same name on the `publish` job in the same change.

State on 2026-11-07, read on the pub.dev Admin page: publishing from GitHub
Actions is enabled for `zawasystem/duo_rail_kit` with tag pattern `{{version}}`
and push events; `workflow_dispatch` events and a required environment are off.
Manual publishing is also enabled. Recheck it before each tag.

The workflow does not compile or run the native plugin, so finish the native
checks first. Push a release tag only after review and authorisation; never
push a test version to exercise CI. Without automated publishing, publish the
tagged source with `fvm flutter pub publish`, as for `0.1.1`; a started command
or a browser login is not proof that the upload finished.

## After publishing

Verify the version on pub.dev, inspect its archive, and resolve it from a clean
consumer with an empty Pub cache. Check the published README, images, API
documentation, and analysis results. Add the release commit and tag to the
release record.

## Repository review

- Review the whole public history, branches and tags included (comments,
  commit metadata, example identifiers, generated platform files, images), for
  private application or personal information.
- Review [third-party notices](../THIRD_PARTY_NOTICES.md) and the archive: the
  MIT License does not replace the Flutter template licence or the font and
  icon terms of the documentation images; check other dependency notices too.
  Recheck the selected artefacts' notices when the renderer's SDK or fonts
  change.
- Verify the private reporting channel in [SECURITY.md](../SECURITY.md);
  repository visibility alone does not enable it.
- Use isolated hosted or ephemeral runners with timeouts and concurrency
  limits, and observe a successful CI run at the intended revision; a workflow
  file or a local build is not proof that CI has run.
