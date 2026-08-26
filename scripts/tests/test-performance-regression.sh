#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
baseline_summaries="$temporary_directory/baseline"
passing_summaries="$temporary_directory/passing"
regressed_summaries="$temporary_directory/regressed"
mkdir -p "$baseline_summaries" "$passing_summaries" "$regressed_summaries"

make_summary() {
    directory=$1
    execution=$2
    p95=$3
    jq -n --arg execution "$execution" --argjson p95 "$p95" '{
        schemaVersion: "1.0.0",
        testId: "BannerTests/testBanner()",
        executionId: $execution,
        metrics: [{
            operationKey: "ui.tap",
            count: 5,
            minimumMilliseconds: 10,
            maximumMilliseconds: $p95,
            meanMilliseconds: $p95,
            medianMilliseconds: $p95,
            p90Milliseconds: $p95,
            p95Milliseconds: $p95,
            p99Milliseconds: $p95
        }],
        findings: []
    }' > "$directory/${execution}_performance-summary.json"
}

for index in 1 2 3; do
    make_summary "$baseline_summaries" "base-$index" $((100 + index))
    make_summary "$passing_summaries" "pass-$index" $((110 + index))
    make_summary "$regressed_summaries" "slow-$index" $((500 + index))
done

baseline="$temporary_directory/baseline.json"
"$repository_root/scripts/build-performance-baseline.sh" \
    "$baseline_summaries" "$baseline" "ios-26.5|iphone-17-pro|debug" >/dev/null
jq -e '
    .operationCount == 1 and
    .operations[0].executionSamples == 3 and
    .operations[0].observationCount == 15 and
    .operations[0].p95OfExecutionP95Milliseconds == 103
' "$baseline" >/dev/null

"$repository_root/scripts/compare-performance-regression.sh" \
    "$baseline" "$passing_summaries" "$temporary_directory/passing.json" \
    "$repository_root/scripts/performance-regression-policy.json" \
    "ios-26.5|iphone-17-pro|debug" >/dev/null
jq -e '.status == "passed" and .counts.regressed == 0' "$temporary_directory/passing.json" >/dev/null

if "$repository_root/scripts/compare-performance-regression.sh" \
    "$baseline" "$regressed_summaries" "$temporary_directory/regressed.json" \
    "$repository_root/scripts/performance-regression-policy.json" \
    "ios-26.5|iphone-17-pro|debug" >/dev/null 2>&1; then
    echo "Regression fixture must fail the policy" >&2
    exit 1
fi
jq -e '
    .status == "regressed" and
    .counts.regressed == 1 and
    .findings[0].reasonCode == "performance.cross_run_regression" and
    (.findings[0].evidence | length) == 3
' "$temporary_directory/regressed.json" >/dev/null

"$repository_root/scripts/compare-performance-regression.sh" \
    "$baseline" "$passing_summaries" "$temporary_directory/incompatible.json" \
    "$repository_root/scripts/performance-regression-policy.json" \
    "ios-26.5|iphone-17e|debug" >/dev/null
jq -e '.status == "incompatible_environment" and .counts.incompatible == 1' \
    "$temporary_directory/incompatible.json" >/dev/null

echo "Cross-run performance regression contract test passed"
