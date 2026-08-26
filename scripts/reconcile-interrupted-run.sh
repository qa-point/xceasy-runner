#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <run-directory>" >&2
    exit 64
fi

run_directory=$(cd "$1" && pwd)
plan="$run_directory/execution-plan.json"
source_results="$run_directory/allure-results"
source_summary="$run_directory/execution-summary.json"
destination="$run_directory/reconciled-allure-results"
report="$run_directory/crash-reconciliation.json"
reconciled_summary="$run_directory/reconciled-execution-summary.json"
script_directory=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

[ -f "$plan" ] || { echo "Execution plan not found: $plan" >&2; exit 66; }
[ -f "$source_summary" ] || { echo "Execution summary not found: $source_summary" >&2; exit 66; }
jq -e '(.schema_version == "1.0.0") and (.assignments | type == "array")' "$plan" >/dev/null
jq -e '.missing | type == "array"' "$source_summary" >/dev/null

if [ -e "$destination" ]; then
    echo "Reconciliation destination already exists: $destination" >&2
    exit 73
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-reconciliation.XXXXXX")
cleanup() {
    status=$?
    if [ "$status" -eq 0 ]; then
        rm -rf "$temporary_directory"
    else
        echo "Retained failed reconciliation workspace: $temporary_directory" >&2
    fi
}
trap cleanup EXIT

synthetic_results="$temporary_directory/synthetic-allure-results"
mkdir -p "$synthetic_results"
run_id=$(jq -r '.run_id' "$plan")
timestamp_milliseconds=$(($(date +%s) * 1000))

jq -c '.missing[]' "$source_summary" |
while IFS= read -r missing; do
    test_name=$(printf '%s' "$missing" | jq -r '.test')
    device_id=$(printf '%s' "$missing" | jq -r '.device_id')
    shard_index=$(printf '%s' "$missing" | jq -r '.shard_index')
    method_name=${test_name##*/}
    uuid=$(printf '%s' "$run_id|host-reconciled|$test_name|$device_id|$shard_index" | shasum -a 256 | awk '{print $1}')
    test_case_id=$(printf '%s' "$test_name" | shasum -a 256 | awk '{print $1}')
    history_id=$(printf '%s|%s' "$test_case_id" "$device_id" | shasum -a 256 | awk '{print $1}')

    jq -n \
        --arg uuid "$uuid" \
        --arg test_case_id "$test_case_id" \
        --arg history_id "$history_id" \
        --arg full_name "$test_name" \
        --arg name "$method_name" \
        --arg run_id "$run_id" \
        --arg device_id "$device_id" \
        --argjson shard_index "$shard_index" \
        --argjson timestamp "$timestamp_milliseconds" '
        {
            uuid: $uuid,
            testCaseId: $test_case_id,
            historyId: $history_id,
            fullName: $full_name,
            name: $name,
            status: "broken",
            stage: "finished",
            statusDetails: {
                known: true,
                muted: false,
                flaky: false,
                message: "Test execution was interrupted before an in-process Allure result was finalized.",
                trace: "Host reconciliation created this result from execution-plan.json and execution-summary.json."
            },
            start: $timestamp,
            stop: $timestamp,
            labels: [
                {name: "xceasy.run_id", value: $run_id},
                {name: "xceasy.device_id", value: $device_id},
                {name: "xceasy.shard_index", value: ($shard_index | tostring)},
                {name: "xceasy.attempt", value: "0"},
                {name: "xceasy.host_reconciled", value: "true"}
            ]
        }' > "$synthetic_results/$uuid-result.json"
    jq -n --arg uuid "$uuid" --arg run_id "$run_id" '
        {uuid: ("container-" + $uuid), name: "Host crash reconciliation", children: [$uuid], befores: [], afters: [], description: ("run_id=" + $run_id)}
    ' > "$synthetic_results/$uuid-container.json"
done

jq -n --arg run_id "$run_id" '{name: "XCEasy host reconciliation", type: "xceasy", buildName: $run_id}' \
    > "$synthetic_results/executor.json"
jq -n '[{name: "Interrupted execution", matchedStatuses: ["broken"], messageRegex: ".*interrupted.*"}]' \
    > "$synthetic_results/categories.json"
printf 'xceasy.run_id=%s\nxceasy.reconciled=true\n' "$run_id" > "$synthetic_results/environment.properties"

if [ -d "$source_results" ] && [ -n "$(find "$source_results" -maxdepth 1 -name '*-result.json' -print -quit)" ]; then
    "$script_directory/aggregate-allure-results.sh" "$destination" "$source_results" "$synthetic_results" >/dev/null
else
    "$script_directory/aggregate-allure-results.sh" "$destination" "$synthetic_results" >/dev/null
fi
"$script_directory/validate-allure-results.sh" "$destination" >/dev/null

started_at=$(jq -r '.started_at' "$source_summary")
finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
duration_seconds=$(jq -r '.duration_seconds' "$source_summary")
"$script_directory/build-execution-summary.sh" \
    "$plan" "$destination" "$started_at" "$finished_at" "$duration_seconds" interrupted "$reconciled_summary"

synthetic_count=$(jq '.counts.missing' "$source_summary")
jq -n \
    --arg run_id "$run_id" \
    --arg source_summary "execution-summary.json" \
    --arg reconciled_summary "reconciled-execution-summary.json" \
    --arg results "reconciled-allure-results" \
    --argjson synthetic_count "$synthetic_count" \
    --slurpfile before "$source_summary" \
    --slurpfile after "$reconciled_summary" '
    {
        schema_version: "1.0.0",
        run_id: $run_id,
        status: (if $synthetic_count > 0 then "reconciled" else "nothing_to_reconcile" end),
        source_summary: $source_summary,
        reconciled_summary: $reconciled_summary,
        allure_results: $results,
        counts: {
            missing_before: $before[0].counts.missing,
            synthetic_broken_results: $synthetic_count,
            missing_after: $after[0].counts.missing
        },
        invariant: "Synthetic broken results preserve missing execution evidence and never convert an interrupted run to passed."
    }' > "$report"

echo "Interrupted run reconciled: $report"
