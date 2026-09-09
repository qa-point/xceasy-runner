# Установка и первый запуск

Русский · [English](../en/GETTING_STARTED_EN.md) · [README](../../README_RU.md)

## Что устанавливается

Публичная команда называется `xceasyctl`. Вместе с ней устанавливается private runtime в
`libexec/xceasy-runner`; переносить только файл `xceasyctl` нельзя.

Для работы нужны macOS, полный Xcode и `jq`. CLI сам использует `DEVELOPER_DIR`, активный
`xcode-select` либо находит `/Applications/Xcode.app`/`Xcode-beta.app`.

Runner является частью экосистемы XCEasy и требует XCUITest target с подключённым XCEasy. Именно
XCEasy предоставляет test metadata, Allure results, logs и diagnostics, которые runner отбирает,
распределяет и агрегирует. Автономный XCTest target без XCEasy не является поддерживаемым input.

## GitHub Release

Скачайте archive и checksum одной версии со страницы Releases:

```bash
shasum -a 256 -c xceasy-runner-0.1.2-macos-universal.tar.gz.sha256
tar -xzf xceasy-runner-0.1.2-macos-universal.tar.gz
sudo ./xceasy-runner-0.1.2/install.sh /usr/local
xceasyctl version
```

Без `sudo` установите в пользовательский prefix:

```bash
./xceasy-runner-0.1.2/install.sh "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
```

Установщик сохраняет quarantine macOS. Текущие архивы имеют ad-hoc подпись, без Developer ID/notarization. Если Gatekeeper блокирует запуск, используйте проверенную сборку из исходников либо стандартное разрешение macOS для доверенного ПО. Архив v0.1.1 выпущен до исправления установщика; Homebrew и Nix не запускают этот установщик.

## Homebrew

Репозиторий Runner одновременно является Homebrew tap. Формула находится в `Formula/xceasyctl.rb`; при подключении явно укажите Git URL:

```bash
brew tap qa-point/runner https://github.com/qa-point/xceasy-runner.git
brew install qa-point/runner/xceasyctl
xceasyctl version
brew test qa-point/runner/xceasyctl
```

Обновление и удаление:

```bash
brew update
brew upgrade qa-point/runner/xceasyctl
brew uninstall xceasyctl
```

Формула закрепляет URL и SHA-256 релизного архива и устанавливает приватный runtime без запуска установщика из архива.

### Переход со старого tap

Если Runner установлен из `qa-point/tap`, перед командами выше удалите прежний пакет и отключите старый tap:

```bash
brew uninstall qa-point/tap/xceasyctl
brew untap qa-point/tap
```

Это удаляет прежний пакет/tap Homebrew, а не конфигурацию ваших тестовых проектов. Затем подключите репозиторий Runner и установите `qa-point/runner/xceasyctl` командами выше.

## Nix

Нужны включённые `nix-command` и `flakes`, macOS и полный Xcode. Версия 0.1.2 использует Nixpkgs 26.05 и поддерживает `aarch64-darwin` и `x86_64-darwin`; нативные сборки проверяются в CI. Для сборки Intel нужен Intel builder.


Flake поддерживает только `aarch64-darwin` и `x86_64-darwin`, потому что выполнение XCUITest требует macOS и Xcode:

```bash
nix profile add github:qa-point/xceasy-runner/v0.1.2
xceasyctl version
```

Без постоянной установки:

```bash
nix run github:qa-point/xceasy-runner/v0.1.2 -- version
```

Для локального checkout используйте `nix build` или `nix run . -- version`. Release tag обязателен
для воспроизводимой удалённой установки.

## Сборка из исходников

```bash
make build
make install PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
xceasyctl version
```

## Подготовка проекта

1. Подключите и настройте XCEasy в XCUITest target.
2. Скопируйте [`examples/xceasy-runner.json`](../../examples/xceasy-runner.json) в корень UI-test проекта.
3. Укажите `workspace`, `scheme`, `test_target` и `runner_bundle_id`.
4. Добавьте simulator или physical devices по `id` либо `name`.
5. Если scheme использует test plan, задайте `test_plan` и одну `test_configuration`.
6. Проверьте config и execution plan без запуска тестов:

```bash
xceasyctl validate-config ./xceasy-runner.json
xceasyctl test --config ./xceasy-runner.json --plan-only
```

### Минимальный config для Simulator

```json
{
  "schema_version": "1.0.0",
  "mode": "shard",
  "workspace": "./XCEasyExamples.xcworkspace",
  "scheme": "UIKitExample",
  "test_target": "UIKitExampleUITests",
  "runner_bundle_id": "com.qa-point.xceasy-examples.uikit-tests.xctrunner",
  "output_directory": "./runner-artifacts",
  "devices": [
    {
      "type": "simulator",
      "name": "iPhone 17 Pro"
    }
  ]
}
```

Относительные `workspace` и `output_directory` считаются от директории, где лежит config. Имя
simulator должно однозначно совпадать с доступным устройством из `xcrun simctl list devices
available`; для CI стабильнее использовать `"id": "SIMULATOR_UDID"` вместо `name`.

- `mode: shard` выполняет каждый тест один раз и делит набор между devices.
- `workspace`, `scheme`, `test_target` определяют Xcode UI-test bundle.
- `runner_bundle_id` — bundle ID приложения с суффиксом `.xctrunner`, из container которого runner
  забирает XCEasy artifacts.
- `output_directory` содержит отдельный `run-*` для каждого запуска.
- `devices` задаёт simulator, physical devices либо их mix.

### Два Simulator

```json
"devices": [
  { "type": "simulator", "id": "FIRST_SIMULATOR_UDID" },
  { "type": "simulator", "id": "SECOND_SIMULATOR_UDID" }
]
```

В `shard` mode тесты распределяются между ними без дублирования. В `replicate` mode полный набор
выполняется на каждом device.

### Physical device и mixed matrix

```json
{
  "devices": [
    { "type": "simulator", "id": "SIMULATOR_UDID" },
    { "type": "physical", "id": "PHYSICAL_DEVICE_UDID" }
  ],
  "physical_device": {
    "development_team": "APPLE_DEVELOPMENT_TEAM_ID",
    "allow_provisioning_updates": true,
    "allow_device_registration": false
  }
}
```

Это только заменяемый фрагмент основного config, а не самостоятельный JSON-файл. Physical device
должен быть подключён, доверен и подготовлен для development. Runner отдельно собирает продукты для
`iphonesimulator` и `iphoneos`.

### Test plan, отбор и изоляция state

Следующие опциональные поля добавляются на верхний уровень config:

```json
{
  "test_plan": "UIKitExampleTestPlan",
  "test_configuration": "English",
  "selection": {
    "include_any": ["Smoke"],
    "include_all": ["IOS"],
    "exclude": ["Flaky"]
  },
  "state_isolation": "app_reset_hook",
  "retry_missing_tests": true,
  "max_recovery_attempts": 2,
  "require_all_devices": true
}
```

Этот блок также является фрагментом. `app_reset_hook` работает только когда тестовое приложение
реализует consumer-side reset по `XC_EASY_STATE_ISOLATION`; runner не переустанавливает приложение.
Полный config со всеми используемыми возможностями находится в
[`examples/xceasy-runner.json`](../../examples/xceasy-runner.json), а точный контракт — в
[`execution-config-1.0.0.schema.json`](../../schemas/execution-config-1.0.0.schema.json).

## Запуск

Обычный запуск:

```bash
xceasyctl test --config ./xceasy-runner.json
```

Временная замена устройств и test plan без изменения JSON:

```bash
xceasyctl test \
  --config ./xceasy-runner.json \
  --simulator SIMULATOR_UDID \
  --test-plan UIKitExampleTestPlan \
  --test-configuration English
```

Выбор тестов по XCEasy metadata:

```bash
xceasyctl test --annotation Smoke
xceasyctl test --require-annotation Smoke --require-annotation IOS
xceasyctl test --exclude-annotation Flaky
```

Каждый запуск создаёт `run-*` внутри `output_directory`. Готовые Allure inputs находятся в
`allure-results`; план, итог, диагностика и проверка целостности — в `execution-plan.json`,
`execution-summary.json`, `diagnostic-summary.json` и `artifact-manifest.json`.

## Проверка установки

```bash
xceasyctl version
xceasyctl help
xceasyctl validate-config ./xceasy-runner.json
```

CLI не включает Xcode, simulator runtimes, signing identities или provisioning profiles. Их нужно
подготовить на машине отдельно.
