#!/bin/sh
set -eu

if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <execution-plan.json> <allure-results> <started-at> <finished-at> <duration-seconds> <coordinator-status> <output.json>" >&2
    exit 64
fi

plan=$1
results_directory=$2
started_at=$3
finished_at=$4
duration_seconds=$5
coordinator_status=$6
output=$7

if [ ! -f "$plan" ]; then
    echo "Execution plan not found: $plan" >&2
    exit 66
fi
case "$coordinator_status" in
    passed|failed|interrupted) ;;
    *) echo "Invalid coordinator status: $coordinator_status" >&2; exit 64 ;;
esac

results_jsonl=$(mktemp)
trap 'rm -f "$results_jsonl"' EXIT
if [ -d "$results_directory" ]; then
    for result in "$results_directory"/*-result.json; do
        [ -f "$result" ] || continue
        jq -c '.' "$result" >> "$results_jsonl"
    done
fi

jq -n \
    --slurpfile plan "$plan" \
    --slurpfile results "$results_jsonl" \
    --arg started_at "$started_at" \
    --arg finished_at "$finished_at" \
    --argjson duration_seconds "$duration_seconds" \
    --arg coordinator_status "$coordinator_status" '
    def get_label($name): ([.labels[]? | select(.name == $name) | .value][0] // "unknown");
    def expected_executions:
        [$plan[0].assignments[] as $assignment
            | $assignment.tests[]
            | {
                test: sub("^[^/]+/"; ""),
                device_id: $assignment.device_id,
                device_type: ($assignment.device_type // "simulator"),
                shard_index: $assignment.shard_index
            }];
    def actual_executions:
        [$results[]
            | {
                test: .fullName,
                device_id: get_label("xceasy.device_id"),
                device_type: get_label("xceasy.device_type"),
                shard_index: (get_label("xceasy.shard_index") | tonumber? // -1),
                attempt: (get_label("xceasy.attempt") | tonumber? // 1),
                status: .status,
                uuid: .uuid
            }];
    expected_executions as $expected
    | actual_executions as $actual
    | [$expected[] | . as $item | select(any($actual[]; .test == $item.test and ($plan[0].mode == "shard" or .device_id == $item.device_id)) | not)] as $missing
    | [$actual[] | . as $item | select(any($expected[]; .test == $item.test and ($plan[0].mode == "shard" or .device_id == $item.device_id)) | not)] as $unexpected
    | [$actual | group_by(if $plan[0].mode == "shard" then [.test] else [.test, .device_id] end)[] | select(length > 1) | {test: .[0].test, device_id: .[0].device_id, count: length, uuids: map(.uuid)}] as $duplicated
    | {
        schema_version: "1.0.0",
        run_id: $plan[0].run_id,
        mode: $plan[0].mode,
        status: (if $coordinator_status == "passed" and ($missing | length) == 0 and ($unexpected | length) == 0 and ($duplicated | length) == 0 and all($actual[]; .status == "passed") then "passed" elif $coordinator_status == "interrupted" or ($missing | length) > 0 then "interrupted" else "failed" end),
        coordinator_status: $coordinator_status,
        started_at: $started_at,
        finished_at: $finished_at,
        duration_seconds: $duration_seconds,
        counts: {
            planned: ($expected | length),
            executed: ($actual | length),
            passed: ([$actual[] | select(.status == "passed")] | length),
            failed: ([$actual[] | select(.status != "passed")] | length),
            missing: ($missing | length),
            unexpected: ($unexpected | length),
            duplicated: ($duplicated | length),
            retried: ([$actual[] | select(.attempt > 1)] | length)
        },
        missing: $missing,
        unexpected: $unexpected,
        duplicated: $duplicated,
        executions: $actual
    }
' > "$output"
