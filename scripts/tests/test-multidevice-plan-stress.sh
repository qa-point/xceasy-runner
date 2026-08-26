#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

jq -n \
    --arg output "$temporary_directory/artifacts" \
    '{
        schema_version: "1.0.0",
        mode: "shard",
        retry_missing_tests: true,
        max_recovery_attempts: 2,
        require_all_devices: true,
        workspace: "Fake.xcworkspace",
        scheme: "Stress",
        test_target: "StressUITests",
        runner_bundle_id: "example.stress.xctrunner",
        output_directory: $output,
        devices: [
            {type: "simulator", id: "device-1"},
            {type: "simulator", id: "device-2"},
            {type: "simulator", id: "device-3"},
            {type: "simulator", id: "device-4"}
        ]
    }' > "$temporary_directory/config.json"

PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/config.json" --plan-only >/dev/null

plan=$(find "$temporary_directory/artifacts" -mindepth 2 -maxdepth 2 -name execution-plan.json -print -quit)
if [ -z "$plan" ]; then
    echo "Execution plan was not created" >&2
    exit 1
fi

jq -e '
    .mode == "shard" and
    .test_count == 100 and
    .recovery_policy == {retry_missing_tests: true, max_recovery_attempts: 2} and
    .require_all_devices == true and
    (.assignments | length) == 4 and
    all(.assignments[]; (.tests | length) == 25) and
    ([.assignments[].tests[]] | length) == 100 and
    ([.assignments[].tests[]] | unique | length) == 100
' "$plan" >/dev/null

echo "Hundred-test four-device coordinator planning stress test passed"
