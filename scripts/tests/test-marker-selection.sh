#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-selection-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

jq -n --arg output "$fixture/artifacts" '{
    schema_version: "1.0.0",
    mode: "shard",
    retry_missing_tests: false,
    require_all_devices: true,
    workspace: "Fake.xcworkspace",
    scheme: "Stress",
    test_target: "StressUITests",
    runner_bundle_id: "example.stress.xctrunner",
    output_directory: $output,
    devices: [
        {type: "simulator", id: "device-1"},
        {type: "simulator", id: "device-2"}
    ],
    selection: {
        include_all: ["smoke"],
        exclude: ["Debug"]
    }
}' > "$fixture/config.json"

PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$fixture/config.json" --plan-only >/dev/null

plan=$(find "$fixture/artifacts" -name execution-plan.json -print -quit)
jq -e '
    .test_count == 99
    and .selection.included_count == 99
    and .selection.excluded_count == 1
    and (.selection.records[] | select(.identifier | endswith("/test0()")) | .reason) == "excluded_marker"
    and ([.assignments[].tests[]] | index("StressUITests/StressSuite/test0()") == null)
' "$plan" >/dev/null

echo "Pre-shard marker selection contract passed"
