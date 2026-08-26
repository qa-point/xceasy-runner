# ADR 0001 — Retry policy для missing tests

Статус: принят. Дата: 7 августа 2026 года.

## Контекст

Worker может пропасть, не выполнив shard полностью или выполнив только его часть. Повтор полного shard создаёт дубли успешных executions и искажает Allure history. В replicate mode device является частью запрошенной environment matrix, поэтому другой device не считается эквивалентной заменой.

## Решение

Coordinator по умолчанию включает missing-only recovery через `retry_missing_tests: true`. `max_recovery_attempts` задаёт максимальное число recovery rounds после initial execution, по умолчанию равен `2` и принимает целые значения от `0` до `5`. `retry_missing_tests: false` отключает recovery независимо от этого лимита.

Policy повторяет только executions, классифицированные как `missing`, только в `shard` mode и только на workers, чей последний завершённый assignment классифицирован как `passed`. Product/test failures с Allure result считаются выполненными и этой policy не повторяются. Worker, упавший в recovery round, исключается из следующих rounds.

Перед каждым round coordinator рассчитывает накопленное число назначенных tests для каждого доступного worker-а и жадно распределяет отсортированные missing tests на наименее загруженный worker. При равной нагрузке используется детерминированный порядок candidates. Assignments одного round выполняются параллельно.

Каждый retry увеличивает `attempt`, получает новый Allure UUID, фиксирует replacement device и добавляется в `execution-plan.json.retry_assignments`. Переназначенный shard execution закрывает исходный planned test даже при смене device. В replicate mode автоматическая подмена device запрещена.

## Последствия

- Успешные executions намеренно не повторяются.
- Run может восстановиться после последовательных runtime failures в пределах заданного лимита, не скрывая предыдущую infrastructure-диагностику.
- Recovery work балансируется по зафиксированной нагрузке и остаётся воспроизводимой.
- Default разрешает attempts `2` и `3`; пользователь может отключить или уменьшить recovery budget.
- Simulator health определяется ADR 0002, а worker outcome classification — ADR 0003.
