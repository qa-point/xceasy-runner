# XCEasy Runner technical guide

## Boundary

The runner is host-side orchestration, not a Swift test framework. XCEasy emits per-test metadata and artifacts; the runner enumerates, selects, assigns, executes, exports, aggregates, reconciles, and summarizes them.

The public entrypoint is the compiled Swift `xceasyctl` executable. It validates command shape and resolves a versioned private engine from the `libexec/xceasy-runner` tree. The current coordinator remains shell-based behind that boundary; consumers must not invoke it directly.

## Pipeline

```text
validate config -> simulator preflight -> XCTest enumeration -> build-for-testing
       -> metadata manifest -> marker selection -> immutable plan
       -> parallel test-without-building workers -> isolated export
       -> classification -> missing-only recovery -> Allure aggregation
       -> execution/diagnostic/performance summaries -> integrity manifest
```

The coordinator injects `XC_EASY_RUN_ID`, `XC_EASY_DEVICE_ID`, `XC_EASY_SHARD_INDEX`, and `XC_EASY_ATTEMPT` into per-worker `.xctestrun` copies. XCEasy records those values in diagnostic events and Allure labels.

## Compatibility

Runner 0.1.0 accepts execution config 1.0.0 and XCEasy metadata manifest 1.0.0. After `build-for-testing`, it enumerates Swift XCTest method symbols from the built test binary without launching the UI-test runner. Metadata extraction reads deterministic records embedded by XCEasy macros. Tests without macro metadata still run and have an empty marker set. Objective-C test bundles are outside the 0.1.0 enumeration contract.

## Failures

Worker classification is evidence-based. Completed `failed`/`broken` Allure results are never treated as missing. An interrupted plan may receive synthetic `broken` results only during explicit reconciliation, marked `xceasy.host_reconciled=true`.

## Known boundary

0.1.0 supports iOS Simulators, physical iPhone/iPad devices, and mixed device matrices. Permanent performance history and TestOps upload remain external CI responsibilities.
