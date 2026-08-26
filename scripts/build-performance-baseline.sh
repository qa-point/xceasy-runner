#!/bin/sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <performance-summaries-directory> <output.json> [environment-key]" >&2
    exit 64
fi

summaries_directory=$(cd "$1" && pwd)
output=$2
environment_key=${3:-unspecified}
observations=$(mktemp)
trap 'rm -f "$observations"' EXIT

find "$summaries_directory" -type f -name '*_performance-summary.json' -print | LC_ALL=C sort |
while IFS= read -r summary; do
    jq -e '
        .schemaVersion == "1.0.0" and
        (.testId | type == "string") and
        (.executionId | type == "string") and
        (.metrics | type == "array")
    ' "$summary" >/dev/null
    relative_path=${summary#"$summaries_directory"/}
    jq -c --arg source "$relative_path" '
        .testId as $test_id
        | .executionId as $execution_id
        | .metrics[]
        | {
            operation_key: .operationKey,
            test_id: $test_id,
            execution_id: $execution_id,
            source: $source,
            observation_count: .count,
            p95_milliseconds: .p95Milliseconds
        }
    ' "$summary" >> "$observations"
done

if [ ! -s "$observations" ]; then
    echo "No performance summary files found in $summaries_directory" >&2
    exit 65
fi

jq -s \
    --arg environment_key "$environment_key" '
    def percentile($fraction):
        sort as $sorted
        | ($sorted | length) as $count
        | if $count == 0 then null
          else (($fraction * $count | ceil) - 1) as $index | $sorted[$index]
          end;
    group_by(.operation_key)
    | map(
        . as $group
        | ($group | map(.p95_milliseconds)) as $p95_values
        | {
            operationKey: $group[0].operation_key,
            executionSamples: ($group | length),
            observationCount: ($group | map(.observation_count) | add),
            medianOfExecutionP95Milliseconds: ($p95_values | percentile(0.50)),
            p95OfExecutionP95Milliseconds: ($p95_values | percentile(0.95)),
            maximumExecutionP95Milliseconds: ($p95_values | max),
            evidence: ($group | map({testId: .test_id, executionId: .execution_id, source: .source}) | unique_by(.executionId, .source))
        }
    ) as $operations
    | {
        schemaVersion: "1.0.0",
        environmentKey: $environment_key,
        generatedAt: (now | todateiso8601),
        operationCount: ($operations | length),
        operations: $operations
    }
' "$observations" > "$output"

echo "Performance baseline written to $output"
