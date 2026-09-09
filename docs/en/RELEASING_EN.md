# GitHub Releases

English · [Русский](../ru/RELEASING_RU.md) · [README](../../README.md)

## Published assets

The tag workflow at `.github/workflows/release.yml` publishes a GitHub Release containing:

- universal macOS `xceasyctl` (`arm64` and `x86_64`);
- the private `libexec/xceasy-runner` runtime tree;
- a `tar.gz` archive;
- SHA-256 checksum;
- a ready-to-publish `xceasyctl.rb` Homebrew formula containing that archive's checksum;
- curated notes from `CHANGELOG.md` plus GitHub-generated notes.

The binary receives an ad-hoc signature. Developer ID signing and notarization are not configured yet, so this is not claimed as a notarized distribution.

## Release gate

Before publishing, the workflow:

1. verifies agreement between `vX.Y.Z`, `release-metadata.json`, schema, and `CHANGELOG.md`;
2. runs the complete contract suite;
3. builds a universal binary and verifies both architectures;
4. installs the SwiftLint version pinned by `mise.toml`;
5. verifies the archive, checksum, signature, and packaged binary;
6. renders a Homebrew formula from the actual release archive;
7. creates the release through the official `gh` CLI.

The hosted release workflow does not run UI tests. Perform the documented real two-simulator acceptance locally before creating the release tag when execution behavior changes.

## Distribution channels

GitHub Release is the source of truth for the binary archive and checksum.

Homebrew uses this repository directly, with the maintained formula at `Formula/xceasyctl.rb`.
After publishing each verified release, download its generated `xceasyctl.rb` asset into that
path and open a pull request in this repository. Keep the formula on the latest published
archive while preparing a future release; do not point it at an asset that does not exist yet.
The Homebrew workflow installs and tests the formula from the PR revision. No separate tap
repository or cross-repository write secret is needed.

```bash
brew tap qa-point/runner https://github.com/qa-point/xceasy-runner.git
brew install qa-point/runner/xceasyctl
```

Nix distribution lives in the root `flake.nix`. It builds from an immutable release tag and exposes
only `aarch64-darwin` and `x86_64-darwin`. The `nixpkgs` input is pinned by commit and `flake.lock`;
update them as a separately reviewed change, not dynamically during a release.

## Releasing a version

Update `release-metadata.json` and add the matching `CHANGELOG.md` section, then verify locally:

```bash
./scripts/check.sh
./scripts/verify-release.sh v0.1.0
make package
```

After merging to `main`, create and push an existing tag:

```bash
git tag -a v0.1.0 -m "XCEasy Runner 0.1.0"
git push origin v0.1.0
```

The workflow never creates a tag and uses `--verify-tag`. Manual `workflow_dispatch` also accepts an existing tag only.

Repository defaults remain read-only. The build job has `contents: read`; a separate publish job downloads the verified artifact by ID, checks its digest and creates GitHub provenance attestations before publication. Only that job has `contents: write`, `id-token: write`, `attestations: write`, and `artifact-metadata: write`. It never checks out or executes package code. GH_TOKEN is scoped to gh publication steps. Pull requests verify/package but cannot publish. Manual publication must use the workflow on main, and release tags must refer to commits reachable from main.

The release workflow does not access sibling repositories and does not require an
`XC_EASY_INTEGRATION_TOKEN` secret.

## Verify provenance

Future releases from the hardened workflow include GitHub attestations. Verify a downloaded archive with `gh attestation verify ARCHIVE --repo qa-point/xceasy-runner --signer-workflow qa-point/xceasy-runner/.github/workflows/release.yml`. The existing v0.1.1 release has no such attestation; do not claim it does. Attestations do not replace Apple Developer ID/notarization.
