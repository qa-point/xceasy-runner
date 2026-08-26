# ADR 0002 — Simulator health preflight

Status: accepted. Date: August 7, 2026.

## Context

Passing an unknown or unavailable simulator to Xcode wastes a worker attempt and makes the recorded plan differ from the pool that could actually execute it. At the same time, some users prefer degraded execution while strict environment matrices must fail if any requested destination is absent.

## Decision

Before test enumeration, the coordinator snapshots `simctl list devices --json` and creates versioned `device-health.json`. A requested simulator is healthy only when its UDID exists and `isAvailable` is true. Rejections use stable reason codes such as `simulator.not_found` and `simulator.unavailable`.

By default (`require_all_devices: false`), rejected simulators are recorded and removed before deterministic sharding. With `require_all_devices: true`, any rejection stops the run after writing the health report. An empty healthy pool always fails preflight.

## Consequences

- The execution plan contains only destinations that passed preflight and embeds the complete health report.
- Degraded runs remain explicit and machine-readable.
- Current preflight covers iOS Simulators only. Physical-device health requires a separate transport/export design.
- Runtime failures after preflight remain handled by missing-only recovery.
