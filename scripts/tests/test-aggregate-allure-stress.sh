#!/bin/bash
set -euo pipefail

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

shards=()
for ((index = 0; index < 20; index++)); do
    shard="$temporary_directory/shards/$index"
    mkdir -p "$shard"
    uuid=$(printf '00000000-0000-0000-0000-%012d' "$index")
    jq -n \
        --arg uuid "$uuid" \
        --arg name "test-$index" \
        --arg test_case_id "$(printf '%064x' "$index")" \
        --arg history_id "$(printf '%064x' "$((index + 100))")" \
        '{uuid: $uuid, testCaseId: $test_case_id, historyId: $history_id, fullName: ("StressSuite/" + $name + "()"), name: ($name + "()"), status: "passed", stage: "finished", start: 1, stop: 2}' \
        > "$shard/$uuid-result.json"
    jq -n --arg uuid "$uuid" '{uuid: ("container-" + $uuid), children: [$uuid]}' \
        > "$shard/$uuid-container.json"
    jq -n '{name: "XCEasy stress", type: "local"}' > "$shard/executor.json"
    jq -n '[]' > "$shard/categories.json"
    printf 'suite=stress\n' > "$shard/environment.properties"
    shards+=("$shard")
done

"$repository_root/scripts/aggregate-allure-results.sh" "$temporary_directory/allure-results" "${shards[@]}" >/dev/null
"$repository_root/scripts/validate-allure-results.sh" "$temporary_directory/allure-results" >/dev/null

result_count=$(find "$temporary_directory/allure-results" -maxdepth 1 -name '*-result.json' | wc -l | tr -d ' ')
container_count=$(find "$temporary_directory/allure-results" -maxdepth 1 -name '*-container.json' | wc -l | tr -d ' ')
if [ "$result_count" -ne 20 ] || [ "$container_count" -ne 20 ]; then
    echo "Expected 20 isolated results and containers, got results=$result_count containers=$container_count" >&2
    exit 1
fi

echo "Twenty-shard Allure aggregation stress test passed"
