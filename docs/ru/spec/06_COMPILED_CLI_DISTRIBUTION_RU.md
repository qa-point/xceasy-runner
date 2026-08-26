# 06. Compiled CLI distribution

Русский · [English](../../en/spec/06_COMPILED_CLI_DISTRIBUTION_EN.md) · [Оглавление](README_RU.md)

- Публичная команда: `xceasyctl`.
- Минимальная платформа Swift package: macOS 13.
- `make build` создаёт release binary.
- `make install PREFIX=/absolute/path` устанавливает binary и private engine.
- `make package` создаёт versioned `tar.gz` и SHA-256 checksum.
- Runtime сначала проверяет `XCEASY_RUNNER_ROOT`, затем installed `libexec`, затем source checkout.
- `bin/xceasy` не является public API и существует как private compatibility engine.
