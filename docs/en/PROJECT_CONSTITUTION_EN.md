# XCEasy Runner project constitution

Status: active, version 1.0, August 13, 2026.

1. A plan is immutable evidence: selection and assignments are written before app execution.
2. One selected test executes once in `shard` mode; duplication is a failure. `replicate` is explicit.
3. Workers never share writable result directories. Aggregation happens only after export.
4. Missing execution, failed assertion, broken test, and infrastructure loss are distinct outcomes.
5. Recovery retries only missing executions and is bounded. It never hides completed failures.
6. Configuration schemas, reason codes, plans, summaries, and artifact layouts are versioned public contracts.
7. Secrets are removed before every log, report, CLI, and artifact sink.
8. Every failure leaves human-readable output and stable machine-readable evidence for AI diagnosis.
9. XCEasy compatibility is explicit; unknown metadata/schema versions fail rather than being guessed.
10. A release requires RU/EN documentation parity, contract tests, a real two-simulator acceptance run, and reproducible evidence.

Changes to these principles require an ADR and a constitution version update.
