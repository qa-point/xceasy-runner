# ADR 0005: одна test-plan configuration на runner launch

Статус: принято, 2026-08-25.

## Решение

Config schema 1.0.0 поддерживает `test_plan` только вместе с `test_configuration`. Runner передаёт `-testPlan` и `-only-test-configuration` в `build-for-testing`, сохраняет выбранную пару в execution plan и ограничивает `test-without-building` той же configuration.

Runner поддерживает legacy `.xctestrun` и format 2 с `TestConfigurations[].TestTargets[]`.

## Причина

Несколько configurations повторяют один XCTest несколько раз. Без configuration как части execution identity это создаёт ложные duplicates и неоднозначный recovery. Отдельный runner launch на каждую configuration сохраняет изоляцию отчётов и предсказуемую shard-семантику.
