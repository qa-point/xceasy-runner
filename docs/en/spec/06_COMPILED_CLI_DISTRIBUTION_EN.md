# 06. Compiled CLI distribution

English · [Русский](../../ru/spec/06_COMPILED_CLI_DISTRIBUTION_RU.md) · [Contents](README_EN.md)

- Public command: `xceasyctl`.
- Minimum Swift package platform: macOS 13.
- `make build` creates the release binary.
- `make install PREFIX=/absolute/path` installs the binary and private engine.
- `make package` creates a versioned `tar.gz` and SHA-256 checksum.
- Runtime checks `XCEASY_RUNNER_ROOT`, installed `libexec`, then a source checkout.
- `bin/xceasy` is not public API and remains a private compatibility engine.

Installers preserve macOS quarantine instead of removing it. CI builds with read-only permissions; a separate job attests and publishes verified artifacts. Homebrew uses a checksummed universal release; Nix pins a reviewed stable Nixpkgs revision for both Darwin architectures. Apple Developer ID/notarization remain unconfigured without a signing identity.

The Homebrew formula and its installation CI live in the Runner repository (`Formula/xceasyctl.rb` and `.github/workflows/homebrew.yml`). Users tap it with an explicit Git URL; a separate repository is not required. The checked-in formula follows the latest published archive and is updated through a PR after publication.
