# Техническое руководство XCEasy Runner

## Граница ответственности

Runner — host-side orchestration, а не Swift-фреймворк тестов. XCEasy создаёт данные и артефакты отдельного теста; runner перечисляет, отбирает, назначает, запускает, экспортирует, объединяет и анализирует весь прогон.

Публичный entrypoint — compiled Swift executable `xceasyctl`. Он проверяет форму команды и разрешает versioned private engine из дерева `libexec/xceasy-runner`. Текущий coordinator остаётся shell-based за этой границей; consumers не должны вызывать его напрямую.

## Pipeline

```text
config validation -> simulator preflight -> XCTest enumeration -> build-for-testing
       -> metadata manifest -> marker selection -> immutable plan
       -> parallel test-without-building workers -> isolated export
       -> classification -> missing-only recovery -> Allure aggregation
       -> execution/diagnostic/performance summaries -> integrity manifest
```

Coordinator записывает `XC_EASY_RUN_ID`, `XC_EASY_DEVICE_ID`, `XC_EASY_SHARD_INDEX` и `XC_EASY_ATTEMPT` в отдельную копию `.xctestrun` каждого worker. XCEasy переносит эти значения в diagnostic events и Allure labels.

## Совместимость

Runner 0.1.0 принимает config schema 1.0.0 и XCEasy metadata manifest 1.0.0. После `build-for-testing` он перечисляет symbols Swift XCTest methods из собранного test binary, не запуская UI-test runner. Metadata извлекается из детерминированных записей XCEasy macros. Тесты без macro metadata тоже запускаются, но имеют пустой набор markers. Objective-C test bundles не входят в enumeration contract версии 0.1.0.

## Ошибки

Классификация опирается на evidence. Завершённые Allure results со статусом `failed`/`broken` не считаются missing. Synthetic `broken` result создаётся только при явной reconciliation прерванного plan и помечается `xceasy.host_reconciled=true`.

## Текущая граница

Версия 0.1.0 поддерживает iOS Simulators, физические iPhone/iPad и смешанные device matrix. Постоянная performance history и загрузка в TestOps остаются ответственностью CI пользователя.
