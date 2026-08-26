#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
mkdir -p "$temporary_directory/run/shards/0"
cp "$repository_root/tests/fixtures/diagnostic-execution-summary.json" "$temporary_directory/run/execution-summary.json"
cp "$repository_root/tests/fixtures/diagnostic-device-health.json" "$temporary_directory/run/device-health.json"
cp "$repository_root/tests/fixtures/diagnostic-product-classification.json" "$temporary_directory/run/shards/0/classification.json"

"$repository_root/scripts/build-diagnostic-summary.sh" \
    "$temporary_directory/run/execution-summary.json" \
    "$temporary_directory/run/device-health.json" \
    "$temporary_directory/run"

jq -e '
    .conclusion_code == "run.product_failure" and
    .classification_counts.product == 1 and
    .recommended_actions == [{reason_code: "inspect.failed_assertions", priority: "high"}] and
    .classifications[0].evidence_path == "shards/0/classification.json"
' "$temporary_directory/run/diagnostic-summary.json" >/dev/null

mkdir -p "$temporary_directory/recovered/shards/0"
jq '.status = "passed" | .counts.missing = 0 | .counts.failed = 0 | .counts.retried = 2' \
    "$repository_root/tests/fixtures/diagnostic-execution-summary.json" \
    > "$temporary_directory/recovered/execution-summary.json"
cp "$repository_root/tests/fixtures/diagnostic-device-health.json" "$temporary_directory/recovered/device-health.json"
jq -n '{
    schema_version: "1.0.0",
    category: "infrastructure",
    reason_code: "xcode.execution_without_results",
    retryable: true,
    evidence: {result_count: 0}
}' > "$temporary_directory/recovered/shards/0/classification.json"

"$repository_root/scripts/build-diagnostic-summary.sh" \
    "$temporary_directory/recovered/execution-summary.json" \
    "$temporary_directory/recovered/device-health.json" \
    "$temporary_directory/recovered"

jq -e '
    .conclusion_code == "run.passed_recovered" and
    .recommended_actions == [{reason_code: "review.recovered_workers", priority: "medium"}]
' "$temporary_directory/recovered/diagnostic-summary.json" >/dev/null

echo "Diagnostic summary contract tests passed"
