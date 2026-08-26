# ADR 0001 — Missing-test retry policy

Status: accepted. Date: August 7, 2026.

## Context

A worker may disappear after completing none or part of its shard. Repeating the complete shard can duplicate successful executions and distort Allure history. In replicate mode, the device is part of the requested environment matrix and another device is not an equivalent replacement.

## Decision

The coordinator enables missing-only recovery by default through `retry_missing_tests: true`. `max_recovery_attempts` is the maximum number of recovery rounds after the initial execution, defaults to `2`, and accepts integer values from `0` through `5`. Setting `retry_missing_tests` to `false` disables recovery regardless of that limit.

The policy retries only executions classified as `missing`, only in `shard` mode, and only on workers whose latest completed assignment is classified as `passed`. Product/test failures that produced an Allure result are executed, not missing, and are never retried by this policy. A failed recovery worker is removed from subsequent rounds.

For every round, the coordinator calculates each eligible worker's accumulated assigned test count, then greedily assigns sorted missing tests to the least-loaded worker. Candidate order is the deterministic tie-breaker. Assignments in one round execute in parallel.

Every retry increments `attempt`, receives a new Allure UUID, records its replacement device, and is appended to `execution-plan.json.retry_assignments`. A reassigned shard execution satisfies the original planned test identity even when its device changes. Replicate mode never substitutes another device automatically.

## Consequences

- Successful executions are not intentionally repeated.
- A run can recover from consecutive runtime worker failures within a bounded policy without hiding earlier infrastructure evidence.
- Recovery work is balanced using recorded load and remains reproducible.
- The default allows attempts `2` and `3`; users can disable or lower the recovery budget.
- Simulator health is determined by ADR 0002, while worker outcome classification is determined by ADR 0003.
