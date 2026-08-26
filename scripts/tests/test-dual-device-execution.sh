#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
cleanup() {
    status=$?
    if [ "$status" -eq 0 ]; then
        rm -rf "$temporary_directory"
    else
        echo "Retained failed dual-device fixture: $temporary_directory" >&2
    fi
}
trap cleanup EXIT

jq -n --arg output "$temporary_directory/artifacts" '{
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
        {type: "simulator", id: "device-2"}
    ]
}' > "$temporary_directory/config.json"

PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/state" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/config.json" >/dev/null

run_directory=$(find "$temporary_directory/artifacts" -mindepth 1 -maxdepth 1 -type d -print -quit)
[ -n "$run_directory" ] || { echo "Dual-device run directory was not created" >&2; exit 1; }
jq -e '
    .mode == "shard" and
    .test_count == 12 and
    (.assignments | length) == 2 and
    all(.assignments[]; (.tests | length) == 6) and
    (([.assignments[].tests[]] | length) == ([.assignments[].tests[]] | unique | length))
' "$run_directory/execution-plan.json" >/dev/null
jq -e '
    .status == "passed" and
    .counts.planned == 12 and
    .counts.executed == 12 and
    .counts.passed == 12 and
    .counts.failed == 0 and
    .counts.missing == 0 and
    .counts.unexpected == 0 and
    .counts.duplicated == 0
' "$run_directory/execution-summary.json" >/dev/null

result_count=$(find "$run_directory/allure-results" -maxdepth 1 -name '*-result.json' | wc -l | tr -d ' ')
uuid_count=$(jq -r '.uuid' "$run_directory/allure-results"/*-result.json | LC_ALL=C sort -u | wc -l | tr -d ' ')
device_count=$(jq -r '.labels[] | select(.name == "xceasy.device_id") | .value' \
    "$run_directory/allure-results"/*-result.json | LC_ALL=C sort -u | wc -l | tr -d ' ')
[ "$result_count" -eq 12 ] && [ "$uuid_count" -eq 12 ] && [ "$device_count" -eq 2 ] || {
    echo "Dual-device Allure isolation failed: results=$result_count uuids=$uuid_count devices=$device_count" >&2
    exit 1
}
"$repository_root/scripts/validate-artifact-manifest.sh" \
    "$run_directory" "$run_directory/artifact-manifest.json" >/dev/null

echo "Two-device sharding and artifact-isolation contract test passed"
