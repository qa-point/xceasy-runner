# ADR 0006: compiled `xceasyctl` and private engine

Status: accepted, 2026-08-25.

## Decision

The public command is named `xceasyctl` and is built as a macOS executable by SwiftPM. Installation places the binary at `<prefix>/bin/xceasyctl`, while the current coordinator and schemas live under `<prefix>/libexec/xceasy-runner`.

`xceasyctl` validates commands and options, resolves the private engine relative to the binary or through `XCEASY_RUNNER_ROOT`, and replaces itself through `execv`, preserving stdout, stderr, signals, and exit status.

## Consequences

Consumers get a normal compiled CLI and a versioned archive with a checksum. The distribution is not yet single-file: the shell coordinator remains an implementation detail and can migrate to Swift without changing the public command.
