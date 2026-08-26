#!/bin/sh
set -eu

if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <execution-summary.json> <execution-plan.json> <candidate-devices.json> <test-target> <attempt> <output.json>" >&2
    exit 64
fi

summary=$1
plan=$2
candidates=$3
test_target=$4
attempt=$5
output=$6

jq -e '.missing | type == "array"' "$summary" >/dev/null
jq -e 'type == "array" and all(.[]; (.device_id | type == "string") and (.device_type | type == "string") and (.destination | type == "string") and (.shard_index | type == "number"))' "$candidates" >/dev/null

jq -n \
    --slurpfile summary "$summary" \
    --slurpfile plan "$plan" \
    --slurpfile candidates "$candidates" \
    --arg test_target "$test_target" \
    --argjson attempt "$attempt" '
    def previous_load($device_id):
        ([$plan[0].assignments[] | select(.device_id == $device_id) | .tests | length] | add // 0)
        + ([$plan[0].retry_assignments[]? | select(.device_id == $device_id) | .tests | length] | add // 0);
    [$candidates[0][] | . + {load: previous_load(.device_id)}] as $workers
    | reduce ($summary[0].missing | sort_by(.test)[] | select(. as $missing | any($workers[]; .device_type == ($missing.device_type // "simulator")))) as $missing (
        {
            workers: $workers,
            assignments: [$workers[] | {attempt: $attempt, device_id: .device_id, device_type: .device_type, destination: .destination, shard_index: .shard_index, starting_load: .load, tests: []}]
        };
        ([.workers | to_entries[] | select(.value.device_type == ($missing.device_type // "simulator"))] | min_by(.value.load, .key) | .key) as $index
        | .assignments[$index].tests += [$test_target + "/" + $missing.test]
        | .workers[$index].load += 1
    )
    | {
        schema_version: "1.0.0",
        attempt: $attempt,
        assignments: [.assignments[] | select(.tests | length > 0)]
    }
' > "$output"
