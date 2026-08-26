# ADR 0004: physical and mixed device transport

Status: accepted, 2026-08-17.

## Decision

Config schema 1.0.0 represents a device as an object with a `type` (`simulator`/`physical`) and exactly one `id` or `name` selector. The runner performs separate `build-for-testing` operations for `iphonesimulator` and `iphoneos`; assignments store `device_type` and an Xcode destination.

Simulator artifacts are exported through `simctl`; physical artifacts use `devicectl device copy from` with the `appDataContainer` domain. Recovery uses healthy candidates of the same type only.

## Limitations

Signing, trust, and developer mode remain Xcode/CI responsibilities. Fake contracts cover the physical path; real-device acceptance is not claimed without hardware.
