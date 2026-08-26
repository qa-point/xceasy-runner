# Конституция XCEasy Runner

Статус: активна, версия 1.0, 13 августа 2026.

1. Plan — неизменяемое доказательство: selection и assignments записываются до запуска приложения.
2. В `shard` каждый выбранный тест выполняется один раз; дубликат считается ошибкой. `replicate` всегда задаётся явно.
3. Workers не используют общий writable-каталог. Aggregation начинается только после export.
4. Missing execution, assertion failure, broken test и infrastructure loss — разные outcomes.
5. Recovery ограничен и повторяет только missing executions, не скрывая завершившиеся failures.
6. Config schemas, reason codes, plans, summaries и artifact layouts — версионируемые public contracts.
7. Secrets удаляются до каждого log/report/CLI/artifact sink.
8. Каждая ошибка оставляет понятный человеку вывод и стабильные данные для AI-диагностики.
9. Совместимость с XCEasy задаётся явно; неизвестные schema versions отклоняются.
10. Release требует RU/EN parity, contract tests, реальный acceptance на двух simulators и воспроизводимые доказательства.

Изменение принципов требует ADR и новой версии конституции.
