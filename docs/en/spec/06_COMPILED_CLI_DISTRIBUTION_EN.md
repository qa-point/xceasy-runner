# 06. Compiled CLI distribution

English · [Русский](../../ru/spec/06_COMPILED_CLI_DISTRIBUTION_RU.md) · [Contents](README_EN.md)

- Public command: `xceasyctl`.
- Minimum Swift package platform: macOS 13.
- `make build` creates the release binary.
- `make install PREFIX=/absolute/path` installs the binary and private engine.
- `make package` creates a versioned `tar.gz` and SHA-256 checksum.
- Runtime checks `XCEASY_RUNNER_ROOT`, installed `libexec`, then a source checkout.
- `bin/xceasy` is not public API and remains a private compatibility engine.
