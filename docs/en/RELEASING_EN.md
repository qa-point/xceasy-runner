# GitHub Releases

English · [Русский](../ru/RELEASING_RU.md) · [README](../../README_EN.md)

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
4. checks out `qa-point/xceasy` and `qa-point/xceasy-examples`;
5. installs the Tuist version pinned by `mise.toml`;
6. performs a real sharded acceptance run on two iPhone Simulators;
7. verifies the archive, checksum, signature, and packaged binary;
8. renders a Homebrew formula from the actual release archive;
9. creates the release through the official `gh` CLI.

## Distribution channels

GitHub Release is the source of truth for the binary archive and checksum.

Homebrew uses a separate `qa-point/homebrew-tap`. After the first release, copy the generated
`xceasyctl.rb` asset to `Formula/xceasyctl.rb` in the tap and verify
`brew install qa-point/tap/xceasyctl`. Automate tap updates only after that repository exists, using
a scoped secret that can write to the tap and nothing else.

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

Repository settings must allow Actions `Read and write permissions`; the workflow itself is restricted to `contents: write`.

Because `qa-point/xceasy` and `qa-point/xceasy-examples` are private, add the
`XC_EASY_INTEGRATION_TOKEN` Actions secret containing a fine-grained personal access token. Limit
repository access to those two repositories and grant read-only `Contents`. Checkout does not
persist these credentials in Git. The runner repository's standard `GITHUB_TOKEN` cannot read
sibling private repositories. To use a GitHub App instead, generate its short-lived installation
token during the job from App credentials; do not store an installation token as a persistent secret.
