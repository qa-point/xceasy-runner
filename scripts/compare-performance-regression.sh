#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 <baseline.json> <candidate-summaries-directory> <output.json> [policy.json] [environment-key]" >&2
    exit 64
fi

baseline=$1
candidate_directory=$2
output=$3
script_directory=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
policy=${4:-"$script_directory/performance-regression-policy.json"}
environment_key=${5:-$(jq -r '.environmentKey' "$baseline")}
candidate=$(mktemp)
trap 'rm -f "$candidate"' EXIT

jq -e '.schemaVersion == "1.0.0" and (.operations | type == "array")' "$baseline" >/dev/null
jq -e '
    .schemaVersion == "1.0.0" and
    (.minimumExecutionSamples | type == "number" and . >= 1) and
    (.maximumRelativeP95Increase | type == "number" and . >= 0) and
    (.maximumAbsoluteP95IncreaseMilliseconds | type == "number" and . >= 0) and
    (.requireEnvironmentMatch | type == "boolean") and
    (.failOnRegression | type == "boolean")
' "$policy" >/dev/null

"$script_directory/build-performance-baseline.sh" \
    "$candidate_directory" "$candidate" "$environment_key" >/dev/null

jq -n \
    --slurpfile baseline "$baseline" \
    --slurpfile candidate "$candidate" \
    --slurpfile policy "$policy" '
    $baseline[0] as $base
    | $candidate[0] as $current
    | $policy[0] as $rules
    | ($base.environmentKey == $current.environmentKey) as $environment_matches
    | [
        $current.operations[] as $candidate_operation
        | ([$base.operations[] | select(.operationKey == $candidate_operation.operationKey)][0] // null) as $baseline_operation
        | if $rules.requireEnvironmentMatch and ($environment_matches | not) then
            {
                operationKey: $candidate_operation.operationKey,
                status: "incompatible_environment",
                reasonCode: "performance.environment_mismatch",
                baselineP95Milliseconds: ($baseline_operation.p95OfExecutionP95Milliseconds // null),
                candidateP95Milliseconds: $candidate_operation.p95OfExecutionP95Milliseconds,
                evidence: $candidate_operation.evidence
            }
          elif $baseline_operation == null then
            {
                operationKey: $candidate_operation.operationKey,
                status: "new_operation",
                reasonCode: "performance.baseline_missing",
                baselineP95Milliseconds: null,
                candidateP95Milliseconds: $candidate_operation.p95OfExecutionP95Milliseconds,
                evidence: $candidate_operation.evidence
            }
          elif $baseline_operation.executionSamples < $rules.minimumExecutionSamples or
               $candidate_operation.executionSamples < $rules.minimumExecutionSamples then
            {
                operationKey: $candidate_operation.operationKey,
                status: "insufficient_data",
                reasonCode: "performance.minimum_sample_count_not_met",
                baselineSamples: $baseline_operation.executionSamples,
                candidateSamples: $candidate_operation.executionSamples,
                baselineP95Milliseconds: $baseline_operation.p95OfExecutionP95Milliseconds,
                candidateP95Milliseconds: $candidate_operation.p95OfExecutionP95Milliseconds,
                evidence: $candidate_operation.evidence
            }
          else
            ($candidate_operation.p95OfExecutionP95Milliseconds - $baseline_operation.p95OfExecutionP95Milliseconds) as $delta
            | (if $baseline_operation.p95OfExecutionP95Milliseconds == 0
               then (if $delta > 0 then 999999 else 0 end)
               else $delta / $baseline_operation.p95OfExecutionP95Milliseconds
               end) as $relative
            | (($delta >= $rules.maximumAbsoluteP95IncreaseMilliseconds) and
               ($relative >= $rules.maximumRelativeP95Increase)) as $regressed
            | {
                operationKey: $candidate_operation.operationKey,
                status: (if $regressed then "regressed" else "within_threshold" end),
                reasonCode: (if $regressed then "performance.cross_run_regression" else "performance.within_threshold" end),
                baselineSamples: $baseline_operation.executionSamples,
                candidateSamples: $candidate_operation.executionSamples,
                baselineP95Milliseconds: $baseline_operation.p95OfExecutionP95Milliseconds,
                candidateP95Milliseconds: $candidate_operation.p95OfExecutionP95Milliseconds,
                absoluteDeltaMilliseconds: $delta,
                relativeDelta: $relative,
                evidence: $candidate_operation.evidence,
                suggestedAction: (if $regressed then "Inspect the cited execution summaries and dominant operation phases before changing timeouts." else null end)
            }
          end
    ] as $findings
    | {
        schemaVersion: "1.0.0",
        environmentKey: $current.environmentKey,
        baselineEnvironmentKey: $base.environmentKey,
        policy: $rules,
        status: (if any($findings[]; .status == "regressed") then "regressed"
                 elif any($findings[]; .status == "incompatible_environment") then "incompatible_environment"
                 elif any($findings[]; .status == "insufficient_data") then "insufficient_data"
                 else "passed" end),
        counts: {
            compared: ($findings | length),
            regressed: ([$findings[] | select(.status == "regressed")] | length),
            insufficient: ([$findings[] | select(.status == "insufficient_data")] | length),
            incompatible: ([$findings[] | select(.status == "incompatible_environment")] | length)
        },
        findings: $findings
    }
' > "$output"

status=$(jq -r '.status' "$output")
if [ "$status" = "regressed" ] && [ "$(jq -r '.failOnRegression' "$policy")" = "true" ]; then
    echo "Performance regression policy failed; see $output" >&2
    exit 1
fi

echo "Performance comparison completed with status=$status: $output"
