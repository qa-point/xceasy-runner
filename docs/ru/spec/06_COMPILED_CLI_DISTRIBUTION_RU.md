# 06. Compiled CLI distribution

Русский · [English](../../en/spec/06_COMPILED_CLI_DISTRIBUTION_EN.md) · [Оглавление](README_RU.md)

- Публичная команда: `xceasyctl`.
- Минимальная платформа Swift package: macOS 13.
- `make build` создаёт release binary.
- `make install PREFIX=/absolute/path` устанавливает binary и private engine.
- `make package` создаёт versioned `tar.gz` и SHA-256 checksum.
- Runtime сначала проверяет `XCEASY_RUNNER_ROOT`, затем installed `libexec`, затем source checkout.
- `bin/xceasy` не является public API и существует как private compatibility engine.

Установщики сохраняют quarantine macOS вместо его удаления. CI собирает с правами чтения; отдельная job подтверждает происхождение и публикует проверенные артефакты. Homebrew использует universal-релиз с checksum; Nix закрепляет проверенную стабильную Nixpkgs для обеих архитектур Darwin. Apple Developer ID/notarization остаются ненастроенными без signing identity.

Формула Homebrew и CI её установки находятся в репозитории Runner (`Formula/xceasyctl.rb` и `.github/workflows/homebrew.yml`). Tap подключается с явным Git URL; отдельный репозиторий не требуется. Формула в Git ссылается на последний опубликованный архив и обновляется через PR после публикации.
