# ADR 0006: compiled `xceasyctl` и private engine

Статус: принято, 2026-08-25.

## Решение

Публичная команда называется `xceasyctl` и собирается SwiftPM как macOS executable. Установка размещает binary в `<prefix>/bin/xceasyctl`, а текущий coordinator и schemas — в `<prefix>/libexec/xceasy-runner`.

`xceasyctl` валидирует команды и опции, находит private engine относительно binary либо через `XCEASY_RUNNER_ROOT` и заменяет текущий process через `execv`, сохраняя stdout, stderr, signals и exit code.

## Последствия

Consumer получает обычный compiled CLI и versioned archive с checksum. Дистрибутив пока не single-file: shell coordinator остаётся implementation detail и будет переноситься в Swift без изменения публичной команды.
