# ADR 0002 — Health preflight для симуляторов

Статус: принят. Дата: 7 августа 2026 года.

## Контекст

Передача неизвестного или недоступного simulator в Xcode расходует worker attempt и создаёт план, не соответствующий реально исполнимому пулу. При этом одним пользователям подходит degraded execution, а строгая environment matrix должна падать при отсутствии любого requested destination.

## Решение

До test enumeration coordinator сохраняет snapshot `simctl list devices --json` и создаёт версионированный `device-health.json`. Requested simulator считается healthy, только если его UDID найден и `isAvailable` равен true. Для отказов используются стабильные reason codes, например `simulator.not_found` и `simulator.unavailable`.

По умолчанию (`require_all_devices: false`) rejected simulators фиксируются и исключаются до детерминированного sharding. При `require_all_devices: true` любой rejection останавливает run после записи health report. Пустой healthy pool всегда приводит к preflight failure.

## Последствия

- Execution plan содержит только destinations, прошедшие preflight, и включает полный health report.
- Degraded runs остаются явными и machine-readable.
- Текущий preflight поддерживает только iOS Simulators. Для physical devices нужен отдельный transport/export design.
- Runtime failures после preflight по-прежнему обрабатываются missing-only recovery.
