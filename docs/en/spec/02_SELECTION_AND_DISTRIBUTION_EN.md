# R02 — Selection and distribution

After `build-for-testing`, the runner enumerates ordinary Swift XCTest identifiers from the built binary without starting a UI-test process, builds XCEasy metadata manifest 1.0.0, applies `exclude`, `include_any` (OR), then `include_all` (AND), and stores every decision. Empty rules select all tests. `shard` sorts identifiers and assigns them round-robin without duplicates; `replicate` copies the selected list to every healthy device. Empty shards are not launched. Objective-C bundles are not supported in 0.1.0.

Acceptance: excluded tests never enter an assignment; 100 tests produce a deterministic complete unique shard plan; marker-free tests remain selectable when no include rule exists; plan-only never launches test workers.
