# Building and releasing IPAs

Repository: [reomgit/WattageManage](https://github.com/reomgit/WattageManage)

## Automatic builds and releases

The **Build IPA** workflow runs for pushes to `main`, pull requests targeting `main`, version tags, and manual runs. It uses GitHub's `xcode-27` Apple Silicon runner and the shared `WattageManage` scheme to archive a Release build for physical iPhones/iPads. Both the app and the widget extension are included.

Each successful run uploads a `Wattage-unsigned-<run number>` artifact containing:

- `Wattage-unsigned.ipa`
- `SHA256SUMS`

Download the artifact from the workflow run's **Artifacts** section. Artifacts are retained for 30 days; build logs are retained for 7 days. An unsigned IPA needs re-signing with an Apple certificate and compatible provisioning profiles before installation. The embedded widget and App Group also need compatible signing entitlements.

Push a version tag to publish the IPA and checksum as permanent GitHub Release assets:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Tags must use `vMAJOR.MINOR` or `vMAJOR.MINOR.PATCH`. The tag sets the marketing version of both targets. The workflow run number sets the build number. A failed build does not publish a release.

To run the same unsigned archive locally with Xcode 27 or later:

```sh
scripts/ci/build-ipa.sh unsigned
```

Output is written to `build/ci/export/`; the archive is in `build/ci/Wattage.xcarchive`. These paths are ignored by Git.

## Signed IPA setup

The **Signed IPA** workflow is manual and uses an Apple Distribution certificate with two distribution provisioning profiles. Configure it in **Settings → Secrets and variables → Actions → Repository secrets**.

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 of an exported Apple Distribution `.p12`, including its private key |
| `P12_PASSWORD` | Password protecting the `.p12` |
| `APP_PROVISION_PROFILE_BASE64` | Base64 of the app's distribution `.mobileprovision` |
| `WIDGET_PROVISION_PROFILE_BASE64` | Base64 of the widget extension's distribution `.mobileprovision` |

The app profile must match `dev.reom.WattageManage`, and the widget profile must match `dev.reom.WattageManage.Widgets`. Both must belong to the same Apple Developer team, include the signing certificate, and enable the App Group `group.dev.reom.WattageManage`. The workflow derives the team and profile UUIDs from the profiles. It validates expiration, bundle IDs, App Group, and distribution type before archiving.

For a fork using different identifiers, update the bundle identifiers and App Group in the Xcode project, both entitlements files, `WattageWidgets/Shared/WattageLiveData.swift`, and `scripts/ci/prepare-profiles.py` before creating profiles.

To store the files without printing the values in a terminal, use these commands from the repository directory, replacing the example paths with your own:

```sh
base64 -i /path/to/distribution.p12 | gh secret set BUILD_CERTIFICATE_BASE64
gh secret set P12_PASSWORD
base64 -i /path/to/app.mobileprovision | gh secret set APP_PROVISION_PROFILE_BASE64
base64 -i /path/to/widget.mobileprovision | gh secret set WIDGET_PROVISION_PROFILE_BASE64
```

`gh secret set P12_PASSWORD` prompts for the password. Do not commit signing files. They are ignored by `.gitignore`.

Open **Actions → Signed IPA → Run workflow**, select a trusted branch or version tag, and choose an export method:

- **`release-testing`**: use Ad Hoc distribution profiles. The resulting IPA installs only on devices registered in both profiles.
- **`app-store-connect`**: use App Store distribution profiles. The resulting IPA is for later upload to App Store Connect; this workflow exports the package locally on the runner and does not upload it to Apple.

You can also dispatch it with the CLI:

```sh
gh workflow run signed-ipa.yml --ref main -f export_method=release-testing
```

Download `Wattage-signed-<export method>-<run number>` from the completed run. The artifact contains `Wattage-signed.ipa` and `SHA256SUMS` and is retained for 7 days. Signed IPAs contain provisioning information, and artifacts in a public repository can be downloaded by users with access to its Actions artifacts.

Only repository collaborators who can run workflows should dispatch signing builds, because the selected revision's scripts will have access to the signing secrets. Pull-request builds use the unsigned workflow and receive no signing secrets. Signing uses a temporary keychain on an ephemeral GitHub-hosted runner; an `always()` cleanup step removes the keychain, profiles, and temporary signing files.

## Maintenance

Third-party Actions are pinned to commit SHAs. Dependabot checks for Actions updates weekly. Workflow permissions are limited to source reads during builds; only the tag-release job receives repository write access. No dependencies or private credentials are required for the unsigned pipeline.

References: [GitHub Xcode 27 runner](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/), [Apple signing assets on GitHub runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
