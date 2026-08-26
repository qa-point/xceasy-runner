#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
cleanup() {
    status=$?
    if [ "$status" -eq 0 ]; then
        rm -rf "$temporary_directory"
    else
        echo "Retained failed recovery fixture: $temporary_directory" >&2
    fi
}
trap cleanup EXIT

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
            {type: "simulator", id: "device-3"}
        ]
    }' > "$temporary_directory/config.json"

PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/state" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/config.json"

run_directory=$(find "$temporary_directory/artifacts" -mindepth 1 -maxdepth 1 -type d -print -quit)
if [ -z "$run_directory" ]; then
    echo "Run directory was not created" >&2
    exit 1
fi

if ! jq -e '
    .status == "passed" and
    .counts.planned == 12 and
    .counts.executed == 12 and
    .counts.passed == 12 and
    .counts.missing == 0 and
    .counts.duplicated == 0 and
    .counts.retried == 4
' "$run_directory/execution-summary.json" >/dev/null; then
    echo "Unexpected multi-round execution summary" >&2
    jq . "$run_directory/execution-summary.json" >&2
    exit 1
fi

if ! jq -e '
    ([.retry_assignments[] | select(.attempt == 2)] | length) == 2 and
    ([.retry_assignments[] | select(.attempt == 3)] | length) == 1 and
    ([.retry_assignments[] | select(.attempt == 3)][0].device_id == "device-2")
' "$run_directory/execution-plan.json" >/dev/null; then
    echo "Unexpected multi-round retry assignments" >&2
    jq .retry_assignments "$run_directory/execution-plan.json" >&2
    exit 1
fi

jq -e '.category == "infrastructure" and .retryable == true' \
    "$run_directory/shards/2/classification.json" >/dev/null
jq -e '.category == "infrastructure" and .retryable == true' \
    "$run_directory/retries/2/workers/0/classification.json" >/dev/null
jq -e '.category == "passed"' \
    "$run_directory/retries/3/workers/0/classification.json" >/dev/null
jq -e '
    .conclusion_code == "run.passed_recovered" and
    .classification_counts.infrastructure == 2 and
    (.recommended_actions | map(.reason_code) | index("review.recovered_workers")) != null
' "$run_directory/diagnostic-summary.json" >/dev/null

"$repository_root/scripts/validate-artifact-manifest.sh" \
    "$run_directory" "$run_directory/artifact-manifest.json" >/dev/null

echo "Multi-round missing-only recovery contract test passed"
