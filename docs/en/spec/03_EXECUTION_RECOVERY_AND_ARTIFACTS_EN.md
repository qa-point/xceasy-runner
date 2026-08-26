# R03 — Execution, recovery, and artifacts

Every non-empty assignment receives an isolated `.xctestrun`, `.xcresult`, logs, export directory, and correlation values. Workers run concurrently. Results are aggregated only from completed exports and validated. Classification distinguishes passed, product, test, infrastructure, and unknown evidence. In shard mode, bounded recovery reassigns only missing executions to eligible healthy workers. Remaining missing executions may be reconciled into explicitly synthetic broken results.

The terminal run contains execution/diagnostic summaries, worker classifications, device health, optional performance comparison, one `allure-results`, and a SHA-256 artifact manifest. Mutation after indexing fails validation.

Acceptance: a two-worker fixture executes twelve tests exactly once; device loss preserves completed results; product failure is never retried; tampering is detected; raw secrets are absent.
