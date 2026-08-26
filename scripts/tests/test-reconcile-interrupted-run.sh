#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
run_directory="$temporary_directory/run"
mkdir -p "$run_directory/allure-results"

jq -n '{
    schema_version: "1.0.0",
    run_id: "run-crash",
    mode: "shard",
    assignments: [
        {device_id: "device-1", shard_index: 0, tests: ["SampleTests/BannerTests/testPassed()"]},
        {device_id: "device-2", shard_index: 1, tests: ["SampleTests/BannerTests/testInterrupted()"]}
    ]
}' > "$run_directory/execution-plan.json"

passed_uuid=$(printf passed | shasum -a 256 | awk '{print $1}')
test_case_id=$(printf testPassed | shasum -a 256 | awk '{print $1}')
history_id=$(printf historyPassed | shasum -a 256 | awk '{print $1}')
jq -n \
    --arg uuid "$passed_uuid" \
    --arg test_case_id "$test_case_id" \
    --arg history_id "$history_id" '{
        uuid: $uuid,
        testCaseId: $test_case_id,
        historyId: $history_id,
        fullName: "BannerTests/testPassed()",
        name: "testPassed()",
        status: "passed",
        stage: "finished",
        start: 1,
        stop: 2,
        labels: [
            {name: "xceasy.device_id", value: "device-1"},
            {name: "xceasy.shard_index", value: "0"},
            {name: "xceasy.attempt", value: "1"}
        ]
    }' > "$run_directory/allure-results/$passed_uuid-result.json"
jq -n --arg uuid "$passed_uuid" '{uuid: ("container-" + $uuid), children: [$uuid]}' \
    > "$run_directory/allure-results/$passed_uuid-container.json"
jq -n '{name: "fixture", type: "local"}' > "$run_directory/allure-results/executor.json"
jq -n '[]' > "$run_directory/allure-results/categories.json"
printf 'fixture=true\n' > "$run_directory/allure-results/environment.properties"

"$repository_root/scripts/build-execution-summary.sh" \
    "$run_directory/execution-plan.json" \
    "$run_directory/allure-results" \
    "2026-08-09T10:00:00Z" \
    "2026-08-09T10:01:00Z" \
    60 interrupted \
    "$run_directory/execution-summary.json"

"$repository_root/scripts/reconcile-interrupted-run.sh" "$run_directory" >/dev/null
"$repository_root/scripts/validate-allure-results.sh" "$run_directory/reconciled-allure-results" >/dev/null

jq -e '
    .status == "reconciled" and
    .counts.missing_before == 1 and
    .counts.synthetic_broken_results == 1 and
    .counts.missing_after == 0
' "$run_directory/crash-reconciliation.json" >/dev/null
jq -e '.status == "interrupted" and .counts.failed == 1 and .counts.missing == 0' \
    "$run_directory/reconciled-execution-summary.json" >/dev/null
jq -se '
    any(.[];
        .status == "broken" and
        ([.labels[] | select(.name == "xceasy.host_reconciled") | .value][0] == "true")
    )
' "$run_directory/reconciled-allure-results"/*-result.json >/dev/null

if "$repository_root/scripts/reconcile-interrupted-run.sh" "$run_directory" >/dev/null 2>&1; then
    echo "Reconciliation must reject an existing destination" >&2
    exit 1
fi

echo "Interrupted-run host reconciliation contract test passed"
