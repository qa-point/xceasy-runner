# Installation and first run

English · [Русский](../ru/GETTING_STARTED_RU.md) · [README](../../README_EN.md)

## Installed layout

The public command is `xceasyctl`. It is installed together with its private runtime under
`libexec/xceasy-runner`; copying the `xceasyctl` file alone is not supported.

The host needs macOS, full Xcode, and `jq`. The CLI honors `DEVELOPER_DIR`, checks `xcode-select`,
and then discovers `/Applications/Xcode.app` or `Xcode-beta.app`.

The runner is part of the XCEasy ecosystem and requires an XCUITest target with XCEasy integrated.
XCEasy provides the test metadata, Allure results, logs, and diagnostics that the runner selects,
distributes, and aggregates. A standalone XCTest target without XCEasy is not a supported input.

## GitHub Release

Download the archive and checksum for the same version from Releases:

```bash
shasum -a 256 -c xceasy-runner-0.1.0-macos-universal.tar.gz.sha256
tar -xzf xceasy-runner-0.1.0-macos-universal.tar.gz
sudo ./xceasy-runner-0.1.0/install.sh /usr/local
xceasyctl version
```

Use a user-owned prefix to avoid `sudo`:

```bash
./xceasy-runner-0.1.0/install.sh "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
```

## Homebrew

After the tap is published, installation will be:

```bash
brew tap qa-point/tap
brew install xceasyctl
```

Upgrade or uninstall with:

```bash
brew upgrade xceasyctl
brew uninstall xceasyctl
```

Until `qa-point/homebrew-tap` exists, this channel is prepared but not published; use a GitHub
Release or a local source build.

## Nix

The flake supports `aarch64-darwin` and `x86_64-darwin` only because XCUITest execution requires macOS and Xcode:

```bash
nix profile install github:qa-point/xceasy-runner/v0.1.0
xceasyctl version
```

Run without installing:

```bash
nix run github:qa-point/xceasy-runner/v0.1.0 -- version
```

Use `nix build` or `nix run . -- version` in a local checkout. A release tag is required for a
reproducible remote installation.

## Build from source

```bash
make build
make install PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
xceasyctl version
```

## Prepare a project

1. Integrate and configure XCEasy in the XCUITest target.
2. Copy [`examples/xceasy-runner.json`](../../examples/xceasy-runner.json) to the UI-test project root.
3. Set `workspace`, `scheme`, `test_target`, and `runner_bundle_id`.
4. Add simulator or physical devices by `id` or `name`.
5. When the scheme uses a test plan, set `test_plan` and exactly one `test_configuration`.
6. Validate the config and execution plan without running tests:

```bash
xceasyctl validate-config ./xceasy-runner.json
xceasyctl test --config ./xceasy-runner.json --plan-only
```

### Minimal Simulator config

```json
{
  "schema_version": "1.0.0",
  "mode": "shard",
  "workspace": "./XCEasyExamples.xcworkspace",
  "scheme": "UIKitExample",
  "test_target": "UIKitExampleUITests",
  "runner_bundle_id": "com.qa-point.xceasy-examples.uikit-tests.xctrunner",
  "output_directory": "./runner-artifacts",
  "devices": [
    {
      "type": "simulator",
      "name": "iPhone 17 Pro"
    }
  ]
}
```

Relative `workspace` and `output_directory` paths resolve from the config directory. A simulator
name must uniquely match a device reported by `xcrun simctl list devices available`; prefer
`"id": "SIMULATOR_UDID"` in CI for stable selection.

- `mode: shard` executes every test once and distributes the suite across devices.
- `workspace`, `scheme`, and `test_target` identify the Xcode UI-test bundle.
- `runner_bundle_id` is the application bundle ID ending in `.xctrunner`; the runner exports XCEasy
  artifacts from its container.
- `output_directory` receives an isolated `run-*` directory for every invocation.
- `devices` accepts simulators, physical devices, or a mixed matrix.

### Two Simulators

```json
"devices": [
  { "type": "simulator", "id": "FIRST_SIMULATOR_UDID" },
  { "type": "simulator", "id": "SECOND_SIMULATOR_UDID" }
]
```

In `shard` mode, tests are distributed without duplication. In `replicate` mode, the complete suite
runs on every device.

### Physical device and mixed matrix

```json
{
  "devices": [
    { "type": "simulator", "id": "SIMULATOR_UDID" },
    { "type": "physical", "id": "PHYSICAL_DEVICE_UDID" }
  ],
  "physical_device": {
    "development_team": "APPLE_DEVELOPMENT_TEAM_ID",
    "allow_provisioning_updates": true,
    "allow_device_registration": false
  }
}
```

This is a replacement fragment for the main config, not a standalone JSON document. The physical
device must be connected, trusted, and enabled for development. The runner builds separate
`iphonesimulator` and `iphoneos` products.

### Test plan, selection, and state isolation

Add these optional fields at the top level of the main config:

```json
{
  "test_plan": "UIKitExampleTestPlan",
  "test_configuration": "English",
  "selection": {
    "include_any": ["Smoke"],
    "include_all": ["IOS"],
    "exclude": ["Flaky"]
  },
  "state_isolation": "app_reset_hook",
  "retry_missing_tests": true,
  "max_recovery_attempts": 2,
  "require_all_devices": true
}
```

This is also a fragment. `app_reset_hook` works only when the test application implements a
consumer-side reset for `XC_EASY_STATE_ISOLATION`; the runner does not reinstall the application.
See [`examples/xceasy-runner.json`](../../examples/xceasy-runner.json) for a complete config and
[`execution-config-1.0.0.schema.json`](../../schemas/execution-config-1.0.0.schema.json) for the exact
contract.

## Run tests

Normal execution:

```bash
xceasyctl test --config ./xceasy-runner.json
```

Override devices and a test plan for one invocation without editing JSON:

```bash
xceasyctl test \
  --config ./xceasy-runner.json \
  --simulator SIMULATOR_UDID \
  --test-plan UIKitExampleTestPlan \
  --test-configuration English
```

Select tests through XCEasy metadata:

```bash
xceasyctl test --annotation Smoke
xceasyctl test --require-annotation Smoke --require-annotation IOS
xceasyctl test --exclude-annotation Flaky
```

Every invocation creates a `run-*` directory below `output_directory`. Allure inputs are under
`allure-results`; inspect `execution-plan.json`, `execution-summary.json`, `diagnostic-summary.json`,
and `artifact-manifest.json` for planning, outcome, diagnostics, and integrity evidence.

## Verify the installation

```bash
xceasyctl version
xceasyctl help
xceasyctl validate-config ./xceasy-runner.json
```

The CLI does not bundle Xcode, simulator runtimes, signing identities, or provisioning profiles.
Prepare those separately on the host.
