# R02 — Selection и distribution

После `build-for-testing` runner перечисляет обычные Swift XCTest identifiers из built binary без запуска UI-test process, строит XCEasy metadata manifest 1.0.0, применяет `exclude`, `include_any` (OR), затем `include_all` (AND) и сохраняет каждое решение. Пустые rules выбирают все tests. `shard` сортирует identifiers и назначает round-robin без duplicates; `replicate` копирует выбранный список на каждый healthy device. Empty shards не запускаются. Objective-C bundles не поддерживаются в 0.1.0.

Acceptance: excluded tests не попадают в assignment; 100 tests создают deterministic complete unique shard plan; tests без markers выбираются при пустом include; plan-only не запускает workers.
