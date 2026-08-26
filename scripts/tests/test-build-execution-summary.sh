#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
mkdir -p "$temporary_directory/results"

cp "$repository_root/tests/fixtures/execution-plan-summary.json" "$temporary_directory/plan.json"
cp "$repository_root/tests/fixtures/execution-result-passed.json" "$temporary_directory/results/a-result.json"
cp "$repository_root/tests/fixtures/execution-result-failed.json" "$temporary_directory/results/b-result.json"

"$repository_root/scripts/build-execution-summary.sh" \
    "$temporary_directory/plan.json" \
    "$temporary_directory/results" \
    2026-08-07T00:00:00Z \
    2026-08-07T00:00:10Z \
    10 \
    failed \
    "$temporary_directory/summary.json"

jq -e '
    .schema_version == "1.0.0" and
    .status == "interrupted" and
    .counts == {planned: 3, executed: 2, passed: 1, failed: 1, missing: 1, unexpected: 0, duplicated: 0, retried: 0} and
    .missing == [{test: "BannerTests/testMissing()", device_id: "device-2", device_type: "simulator", shard_index: 1}]
' "$temporary_directory/summary.json" >/dev/null

cp "$repository_root/tests/fixtures/execution-result-passed.json" "$temporary_directory/results/c-result.json"
"$repository_root/scripts/build-execution-summary.sh" \
    "$temporary_directory/plan.json" \
    "$temporary_directory/results" \
    2026-08-07T00:00:00Z \
    2026-08-07T00:00:10Z \
    10 \
    passed \
    "$temporary_directory/duplicate-summary.json"

jq -e '.status == "interrupted" and .counts.duplicated == 1 and .duplicated[0].count == 2' \
    "$temporary_directory/duplicate-summary.json" >/dev/null

rm "$temporary_directory/results/c-result.json"
cp "$repository_root/tests/fixtures/execution-result-retried.json" "$temporary_directory/results/c-result.json"
"$repository_root/scripts/build-execution-summary.sh" \
    "$temporary_directory/plan.json" \
    "$temporary_directory/results" \
    2026-08-07T00:00:00Z \
    2026-08-07T00:00:20Z \
    20 \
    failed \
    "$temporary_directory/retry-summary.json"

jq -e '
    .status == "failed" and
    .counts.missing == 0 and
    .counts.unexpected == 0 and
    .counts.duplicated == 0 and
    .counts.retried == 1 and
    (.executions[] | select(.test == "BannerTests/testMissing()") | .device_id == "device-1" and .attempt == 2)
' "$temporary_directory/retry-summary.json" >/dev/null

echo "Execution summary contract tests passed"
