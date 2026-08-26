# R01 — Configuration and preflight

The CLI validates config 1.0.0 before invoking Xcode. Unknown keys, duplicate/empty devices, unsupported mode, invalid recovery limits, and malformed selection fail explicitly. Relative workspace/output/baseline/policy paths resolve from the config directory. Preflight snapshots `simctl` and excludes unavailable devices unless `require_all_devices` requires the exact matrix.

Acceptance: malformed config does not launch Xcode; no healthy device fails; every accepted/rejected device and stable reason is recorded before enumeration.
