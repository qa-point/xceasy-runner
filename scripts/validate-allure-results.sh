#!/bin/sh
set -eu

directory=${1:-allure-results}

if [ ! -d "$directory" ]; then
    echo "Allure results directory not found: $directory" >&2
    exit 66
fi

result_count=0
container_count=0
container_children_file=$(mktemp)
trap 'rm -f "$container_children_file"' EXIT

for container in "$directory"/*-container.json; do
    [ -f "$container" ] || continue
    container_count=$((container_count + 1))
    jq -e '(.uuid | type == "string" and length > 0) and (.children | type == "array" and length > 0)' "$container" >/dev/null
    jq -r '.children[]' "$container" >> "$container_children_file"
done

for result in "$directory"/*-result.json; do
    [ -f "$result" ] || continue
    result_count=$((result_count + 1))
    jq -e '
        (.uuid | type == "string" and length > 0) and
        (.testCaseId | type == "string" and test("^[a-f0-9]{64}$")) and
        (.historyId | type == "string" and test("^[a-f0-9]{64}$")) and
        (.fullName | type == "string" and length > 0) and
        (.name | type == "string" and length > 0) and
        (.status | type == "string" and length > 0) and
        (.stage == "finished") and
        (.start | type == "number") and
        (.stop | type == "number") and
        (.stop >= .start)
    ' "$result" >/dev/null

    result_uuid=$(jq -r '.uuid' "$result")
    if ! grep -Fxq "$result_uuid" "$container_children_file"; then
        echo "Result is not linked from a container: $result_uuid" >&2
        exit 65
    fi

    jq -r '.. | objects | .attachments? // empty | .[]? | .source // empty' "$result" |
    while IFS= read -r source; do
        if [ ! -f "$directory/$source" ]; then
            echo "Missing attachment referenced by $(basename "$result"): $source" >&2
            exit 65
        fi
    done
done

if [ "$result_count" -eq 0 ]; then
    echo "No *-result.json files found in $directory" >&2
    exit 65
fi

if [ "$container_count" -eq 0 ]; then
    echo "No *-container.json files found in $directory" >&2
    exit 65
fi

for service_file in executor.json categories.json; do
    jq empty "$directory/$service_file"
done

echo "Validated $result_count result file(s) and $container_count container file(s) in $directory"
