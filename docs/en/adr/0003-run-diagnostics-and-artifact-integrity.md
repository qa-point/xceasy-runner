# ADR 0003 — Run diagnostics and artifact integrity

Status: accepted. Date: August 7, 2026.

## Context

A non-zero Xcode exit code is not enough to decide whether a failure belongs to the product, test code, infrastructure, or an unknown cause. Humans and AI also need one concise conclusion with stable reason codes and a verifiable index of the evidence used to reach it.

## Decision

Every initial and recovery worker writes `classification.json` with schema `1.0.0`. Classification uses the exported Allure results and process statuses in this precedence order:

1. an Allure `failed` result is `product` with `allure.assertion_failed`;
2. an Allure `broken` result is `test` with `allure.test_broken`;
3. an unsupported Allure status is `unknown`;
4. export or Xcode execution failures without a stronger result are `infrastructure`;
5. a successful worker with results is `passed`; a successful worker without results is `unknown`.

Only infrastructure classifications are marked retryable at the worker-classification layer. Missing execution recovery remains controlled separately by ADR 0001. Classification is an evidence-based heuristic, not permission to change product expectations or test code automatically.

After execution, the coordinator writes `diagnostic-summary.json` with the run conclusion, execution and classification counts, evidence paths, and stable recommended-action reason codes. A successful run that required infrastructure recovery uses `run.passed_recovered`; degraded and recovered execution uses `run.passed_degraded_recovered`, so repaired infrastructure instability is never hidden behind a plain success. It then writes `artifact-manifest.json` with repository commit/dirty state and, for every indexed artifact, relative path, kind, byte size, and SHA-256. `.xcresult` bundles receive a deterministic digest over their sorted internal file descriptions; `derived-data` is excluded as rebuildable intermediate output. The validator recomputes sizes and hashes and fails on missing or changed evidence.

## Consequences

- AI can triage a run without parsing localized prose or guessing from an exit code.
- Product/test failures do not enter the infrastructure retry path.
- Evidence tampering or accidental post-run mutation is detectable for indexed files and `.xcresult` bundles.
- The current classifier does not yet distinguish framework defects as a separate category or inspect richer failure fingerprints; ambiguous evidence remains `unknown`.
- The run-level manifest complements, but does not replace, XCEasy's per-test diagnostic envelope described by F04 and F09 in the framework repository.
