# XCEasy Runner agent instructions

Read `docs/en/PROJECT_CONSTITUTION_EN.md`, `docs/en/TECHNICAL_GUIDE_EN.md`,
`docs/en/CODE_STYLE_EN.md`, `docs/en/CONTRIBUTING_EN.md`, and the relevant
feature specification before changing behavior. Keep public RU/EN documentation
aligned. Treat configuration schemas, execution plans, reason codes, and artifact
layouts as versioned contracts. Never log secrets or claim verification that did
not complete.

## Distribution and security

- This repository is also the Homebrew tap. Keep the generated, published-release formula in `Formula/xceasyctl.rb` and installation checks in `.github/workflows/homebrew.yml`; do not create a separate tap repository.
- Document `brew tap qa-point/runner https://github.com/qa-point/xceasy-runner.git` followed by `brew install qa-point/runner/xceasyctl`. Test the actual PR revision as a tap before claiming installation works.
- Render formula updates with `scripts/render-homebrew-formula.sh` from a verified published archive, or download the generated release formula. Do not hand-edit generated checksums or point the maintained formula at an unpublished release. Update it through a PR after publication.
- Keep RU/EN installation, release, migration, and agent guidance aligned. When moving taps, verify the new installation before removing the previous tap or repository; GitHub repository deletion requires an explicit user request.
- Pin GitHub Actions to full commit SHAs. Keep packaging read-only and publication isolated; never restore a personal token requirement for public dependencies or disable macOS quarantine in installers.
- Nix must build and install on both Darwin architectures in CI. Updating Nixpkgs requires evaluating both platforms and checking native builds; do not infer Intel support from an Apple Silicon build.
- Developer ID signing, notarization, merge, and release publication must not be claimed without the corresponding completed operation and required authorization.
