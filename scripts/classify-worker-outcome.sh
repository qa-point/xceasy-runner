#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <xcode-status> <export-status> <allure-results> <output.json>" >&2
    exit 64
fi

xcode_status=$1
export_status=$2
results_directory=$3
output=$4

results_jsonl=$(mktemp)
trap 'rm -f "$results_jsonl"' EXIT
if [ -d "$results_directory" ]; then
    for result in "$results_directory"/*-result.json; do
        [ -f "$result" ] || continue
        jq -c '{uuid, fullName, status}' "$result" >> "$results_jsonl"
    done
fi

jq -n \
    --argjson xcode_status "$xcode_status" \
    --argjson export_status "$export_status" \
    --slurpfile results "$results_jsonl" '
    ($results | map(select(.status == "failed")) | length) as $product_failures
    | ($results | map(select(.status == "broken")) | length) as $test_failures
    | ($results | map(select(.status != "passed" and .status != "failed" and .status != "broken" and .status != "skipped")) | length) as $unknown_results
    | if $product_failures > 0 then
        {category: "product", reason_code: "allure.assertion_failed", retryable: false}
      elif $test_failures > 0 then
        {category: "test", reason_code: "allure.test_broken", retryable: false}
      elif $unknown_results > 0 then
        {category: "unknown", reason_code: "allure.status_unknown", retryable: false}
      elif $export_status != 0 then
        {category: "infrastructure", reason_code: "artifact.export_failed", retryable: true}
      elif $xcode_status != 0 and ($results | length) == 0 then
        {category: "infrastructure", reason_code: "xcode.execution_without_results", retryable: true}
      elif $xcode_status != 0 then
        {category: "infrastructure", reason_code: "xcode.nonzero_with_partial_results", retryable: true}
      elif ($results | length) > 0 then
        {category: "passed", reason_code: "worker.completed", retryable: false}
      else
        {category: "unknown", reason_code: "worker.completed_without_results", retryable: false}
      end
    | . + {
        schema_version: "1.0.0",
        xcode_status: $xcode_status,
        export_status: $export_status,
        evidence: {
            result_count: ($results | length),
            passed: ($results | map(select(.status == "passed")) | length),
            product_failures: $product_failures,
            test_failures: $test_failures,
            unknown_results: $unknown_results
        }
      }
' > "$output"
