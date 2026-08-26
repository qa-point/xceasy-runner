# R03 — Execution, recovery и artifacts

Каждый non-empty assignment получает изолированные `.xctestrun`, `.xcresult`, logs, export directory и correlation values. Workers работают параллельно. Results объединяются только из завершённых exports и валидируются. Classification различает passed, product, test, infrastructure и unknown evidence. В shard mode bounded recovery переназначает только missing executions на eligible healthy workers. Оставшиеся missing executions можно reconciliate как явно synthetic broken results.

Финальный run содержит execution/diagnostic summaries, worker classifications, device health, optional performance comparison, единый `allure-results` и SHA-256 artifact manifest. Изменение после индексации не проходит validation.

Acceptance: two-worker fixture выполняет двенадцать tests ровно один раз; device loss сохраняет completed results; product failure не повторяется; tampering обнаруживается; raw secrets отсутствуют.
