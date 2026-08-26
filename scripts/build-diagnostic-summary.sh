#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <execution-summary.json> <device-health.json> <classifications-directory>" >&2
    exit 64
fi

execution_summary=$1
device_health=$2
classifications_directory=$3
output=$(dirname "$execution_summary")/diagnostic-summary.json
classifications_jsonl=$(mktemp)
performance_report=$(mktemp)
trap 'rm -f "$classifications_jsonl" "$performance_report"' EXIT
if [ -f "$(dirname "$execution_summary")/performance-regression.json" ]; then
    cp "$(dirname "$execution_summary")/performance-regression.json" "$performance_report"
else
    jq -n '{status: "not_evaluated", counts: {regressed: 0}}' > "$performance_report"
fi

if [ -d "$classifications_directory" ]; then
    find "$classifications_directory" -name classification.json -type f -print | LC_ALL=C sort |
    while IFS= read -r classification; do
        jq -c --arg path "${classification#$(dirname "$execution_summary")/}" '. + {evidence_path: $path}' "$classification"
    done > "$classifications_jsonl"
fi

jq -n \
    --slurpfile summary "$execution_summary" \
    --slurpfile health "$device_health" \
    --slurpfile classifications "$classifications_jsonl" \
    --slurpfile performance "$performance_report" '
    ($classifications | map(select(.category == "product")) | length) as $product
    | ($classifications | map(select(.category == "test")) | length) as $test
    | ($classifications | map(select(.category == "infrastructure")) | length) as $infrastructure
    | ($classifications | map(select(.category == "unknown")) | length) as $unknown
    | ($health[0].rejected | length) as $rejected
    | (if $performance[0].status == "regressed" then "run.performance_regression"
       elif $summary[0].status == "passed" and $rejected > 0 and $infrastructure > 0 then "run.passed_degraded_recovered"
       elif $summary[0].status == "passed" and $infrastructure > 0 then "run.passed_recovered"
       elif $summary[0].status == "passed" and $rejected > 0 then "run.passed_degraded"
       elif $summary[0].status == "passed" then "run.passed"
       elif $summary[0].status == "interrupted" then "run.infrastructure_incomplete"
       elif $product > 0 then "run.product_failure"
       elif $test > 0 then "run.test_failure"
       elif $infrastructure > 0 then "run.infrastructure_failure"
       else "run.unknown_failure" end) as $conclusion
    | {
        schema_version: "1.0.0",
        run_id: $summary[0].run_id,
        status: $summary[0].status,
        conclusion_code: $conclusion,
        execution_counts: $summary[0].counts,
        classification_counts: {
            product: $product,
            test: $test,
            infrastructure: $infrastructure,
            unknown: $unknown
        },
        rejected_device_count: $rejected,
        performance: {
            status: $performance[0].status,
            regression_count: ($performance[0].counts.regressed // 0),
            evidence_path: (if $performance[0].status == "not_evaluated" then null else "performance-regression.json" end)
        },
        classifications: $classifications,
        evidence: {
            execution_plan: "execution-plan.json",
            execution_summary: "execution-summary.json",
            device_health: "device-health.json",
            artifact_manifest: "artifact-manifest.json",
            allure_results: "allure-results"
        },
        recommended_actions:
            (if $conclusion == "run.performance_regression" then [{reason_code: "inspect.performance_regression", priority: "high"}]
             elif $conclusion == "run.passed_degraded_recovered" then [
                {reason_code: "review.rejected_devices", priority: "medium"},
                {reason_code: "review.recovered_workers", priority: "medium"}
             ]
             elif $conclusion == "run.passed_recovered" then [{reason_code: "review.recovered_workers", priority: "medium"}]
             elif $conclusion == "run.passed_degraded" then [{reason_code: "review.rejected_devices", priority: "medium"}]
             elif $conclusion == "run.infrastructure_incomplete" or $conclusion == "run.infrastructure_failure" then [{reason_code: "inspect.worker_infrastructure", priority: "high"}]
             elif $conclusion == "run.product_failure" then [{reason_code: "inspect.failed_assertions", priority: "high"}]
             elif $conclusion == "run.test_failure" then [{reason_code: "inspect.test_implementation", priority: "high"}]
             elif $conclusion == "run.unknown_failure" then [{reason_code: "collect.additional_evidence", priority: "high"}]
             else [] end)
      }
' > "$output"
