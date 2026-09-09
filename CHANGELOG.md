# Changelog

## Unreleased

- Harden public CI, pin GitHub Actions, scan secrets, and document private vulnerability reporting.
- Separate read-only packaging from attested release publication.
- Preserve download quarantine during archive installation.
- Keep the Homebrew formula and installation CI in the Runner repository; restore Intel Nix evaluation with a pinned stable Nixpkgs revision.

## 0.1.1 — 2026-09-07

- Install ripgrep for hosted CI and release verification.
- Document Homebrew and Nix installation and distribution prerequisites.
- Verify universal CLI packaging, installation, and a two-simulator shard run.
- Preserve configuration and metadata schema 1.0.0.

## 0.1.0 — 2026-08-25

- Initial public preview of XCEasy Runner.
- Added the compiled Swift `xceasyctl` executable and SwiftPM package.
- Added reproducible build, prefix-based install, release archive, and SHA-256 packaging commands.
- Moved shell orchestration behind the installed private `libexec/xceasy-runner` boundary.
- Added config schema 1.0.0 with Xcode test plan and single test-configuration selection.
- Added `--test-plan` and `--test-configuration` CLI overrides.
- Added `.xctestrun` format-2 environment injection used by Xcode test plans.
- Added real test-plan examples and contract plus simulator acceptance coverage.
- Added simulator and physical-device selectors to the initial config contract.
- Added separate simulator/device builds, mixed matrices, `devicectl` export, and same-type recovery.
- Added opt-in `app_reset_hook` state isolation without reinstalling the application.
- Added physical-device CLI overrides, contracts, and production documentation.
- Extracted multi-simulator XCTest orchestration from XCEasy.
- Added deterministic shard and replicate modes.
- Added marker selection, bounded missing-only recovery, Allure aggregation,
  performance comparison, diagnostic summaries, and integrity manifests.
- Added the `xceasy test` CLI and versioned configuration schema.
