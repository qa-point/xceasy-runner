# GitHub Releases

Русский · [English](../en/RELEASING_EN.md) · [README](../../README_RU.md)

## Что публикуется

Tag workflow `.github/workflows/release.yml` публикует GitHub Release с:

- universal macOS binary `xceasyctl` (`arm64` + `x86_64`);
- private runtime tree `libexec/xceasy-runner`;
- `tar.gz` archive;
- SHA-256 checksum;
- готовую Homebrew formula `xceasyctl.rb` с checksum именно этого archive;
- curated notes из `CHANGELOG.md` и автоматически сгенерированные GitHub notes.

Binary получает ad-hoc signature. Developer ID signing и notarization пока не настроены, поэтому это не заявляется как notarized distribution.

## Release gate

Перед публикацией workflow:

1. проверяет, что tag `vX.Y.Z`, `release-metadata.json`, schema и `CHANGELOG.md` согласованы;
2. запускает полный contract suite;
3. собирает universal binary и проверяет обе архитектуры;
4. устанавливает SwiftLint из `mise.toml`;
5. проверяет archive, checksum, signature и packaged binary;
6. генерирует Homebrew formula из фактического release archive;
7. создаёт release через официальный `gh` CLI.

Hosted release workflow не запускает UI-тесты. Если менялась execution logic, документированный реальный acceptance на двух simulators выполняется локально до создания release tag.

## Каналы распространения

GitHub Release — источник истины для binary archive и checksum.

Homebrew использует этот репозиторий напрямую; поддерживаемая формула находится в `Formula/xceasyctl.rb`.
После публикации каждого проверенного релиза скачайте его сгенерированный asset `xceasyctl.rb`
в этот путь и откройте PR в этом же репозитории. При подготовке следующего релиза формула
должна оставаться на последнем опубликованном архиве, а не ссылаться на ещё несуществующий asset.
Homebrew workflow устанавливает и проверяет формулу из текущей ревизии PR. Отдельный tap-репозиторий
и секрет с правами записи в другой репозиторий не нужны.

```bash
brew tap qa-point/runner https://github.com/qa-point/xceasy-runner.git
brew install qa-point/runner/xceasyctl
```

Nix distribution находится в корневом `flake.nix`: он собирает CLI из immutable release tag и
поддерживает только `aarch64-darwin`/`x86_64-darwin`. `nixpkgs` закреплён commit hash и
`flake.lock`; их обновление выполняется отдельным проверяемым change, а не во время release.

## Выпуск версии

Обновите `release-metadata.json` и добавьте одноимённый раздел в `CHANGELOG.md`, затем выполните локальную проверку:

```bash
./scripts/check.sh
./scripts/verify-release.sh v0.1.0
make package
```

После merge в `main` создайте и отправьте существующий tag:

```bash
git tag -a v0.1.0 -m "XCEasy Runner 0.1.0"
git push origin v0.1.0
```

Workflow не создаёт tag автоматически и использует `--verify-tag`. Ручной `workflow_dispatch` принимает только уже существующий tag.


Release workflow не обращается к соседним репозиториям и не требует secret
`XC_EASY_INTEGRATION_TOKEN`.

## Изоляция публикации и происхождение артефактов

Настройки репозитория по умолчанию остаются read-only. Сборка имеет только `contents: read`. Отдельная job публикации скачивает артефакт по ID, проверяет его digest и создаёт GitHub attestations. Только она получает `contents: write`, `id-token: write`, `attestations: write`, `artifact-metadata: write`; код и скрипты пакета там не исполняются. GH_TOKEN передаётся только шагам gh. Pull request проверяет и собирает пакет, но не публикует релиз. Ручная публикация использует workflow main; релизный тег должен ссылаться на commit, достижимый из main.

Будущие релизы из обновлённого workflow позволяют проверить происхождение командой `gh attestation verify ARCHIVE --repo qa-point/xceasy-runner --signer-workflow qa-point/xceasy-runner/.github/workflows/release.yml`. У существующего v0.1.1 таких attestations нет. Они не заменяют Apple Developer ID/notarization.
