# ADR 0003 — Run diagnostics и целостность artifacts

Статус: принят. Дата: 7 августа 2026 года.

## Контекст

Ненулевого exit code Xcode недостаточно, чтобы понять, относится ли failure к продукту, test code, infrastructure или неизвестной причине. Человеку и ИИ также нужен короткий вывод со стабильными reason codes и проверяемый индекс evidence, на котором этот вывод основан.

## Решение

Каждый initial и recovery worker записывает `classification.json` schema `1.0.0`. Классификация использует экспортированные Allure results и process statuses со следующим приоритетом:

1. Allure result со status `failed` — `product` с reason `allure.assertion_failed`;
2. Allure result со status `broken` — `test` с reason `allure.test_broken`;
3. неподдерживаемый Allure status — `unknown`;
4. failures экспорта или Xcode execution без более сильного результата — `infrastructure`;
5. успешный worker с results — `passed`, а успешный worker без results — `unknown`.

На уровне worker classification только infrastructure помечается retryable. Recovery missing executions отдельно регулируется ADR 0001. Классификация является evidence-based эвристикой, а не разрешением автоматически менять product expectations или test code.

После выполнения coordinator создаёт `diagnostic-summary.json` с итогом run, execution/classification counts, evidence paths и стабильными reason codes рекомендуемых действий. Успешный run, которому потребовался infrastructure recovery, получает `run.passed_recovered`; degraded и одновременно recovered execution получает `run.passed_degraded_recovered`, поэтому восстановленная нестабильность infrastructure не скрывается за обычным success. Затем создаётся `artifact-manifest.json`: он содержит commit/dirty state репозитория, а для каждого индексируемого artifact — relative path, kind, размер в байтах и SHA-256. Для `.xcresult` рассчитывается детерминированный digest по отсортированным описаниям внутренних файлов; `derived-data` исключается как пересобираемый промежуточный output. Validator заново вычисляет размеры и hashes и падает при отсутствии или изменении evidence.

## Последствия

- ИИ может выполнить triage run без parsing локализованного текста и догадок по exit code.
- Product/test failures не попадают в infrastructure retry path.
- Подмена evidence или случайное изменение после run обнаруживается для indexed files и `.xcresult` bundles.
- Текущий classifier пока не выделяет framework defects в отдельную категорию и не анализирует расширенные failure fingerprints; неоднозначные данные остаются `unknown`.
- Run-level manifest дополняет, но не заменяет per-test diagnostic envelope XCEasy из F04 и F09 framework repository.
