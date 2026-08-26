# ADR 0005: one test-plan configuration per runner invocation

Status: accepted, 2026-08-25.

## Decision

Config schema 1.0.0 supports `test_plan` only together with `test_configuration`. The runner passes `-testPlan` and `-only-test-configuration` to `build-for-testing`, records the pair in the execution plan, and constrains `test-without-building` to the same configuration.

Both legacy `.xctestrun` files and format 2 `TestConfigurations[].TestTargets[]` are supported.

## Rationale

Multiple configurations repeat each XCTest. Without configuration as part of execution identity this produces false duplicates and ambiguous recovery. One runner invocation per configuration preserves report isolation and deterministic shard semantics.
