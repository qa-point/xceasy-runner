# Code style XCEasy Runner

- Scripts используют strict mode, quoted variables, явные exit codes, temporary directories и atomic replacement контрактных артефактов.
- Предпочтительны небольшие scripts с одним input/output contract. JSON keys — `snake_case`, reason codes — lowercase dot notation.
- Нельзя парсить локализованный текст при наличии structured data или использовать fixed sleep для readiness.
- Destructive targets разрешаются явно; пользовательский широкий каталог не удаляется.
- Новое поведение требует positive, negative и malformed-input fixtures. Parallel changes проверяют isolation и отсутствие duplicates.
- Комментарии объясняют решение или invariant. Public commands и schemas получают RU/EN examples.
