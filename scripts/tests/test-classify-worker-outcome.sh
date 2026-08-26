#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

mkdir -p "$temporary_directory/passed" "$temporary_directory/product" "$temporary_directory/test" "$temporary_directory/empty"
cp "$repository_root/tests/fixtures/execution-result-passed.json" "$temporary_directory/passed/fixture-result.json"
cp "$repository_root/tests/fixtures/execution-result-failed.json" "$temporary_directory/product/fixture-result.json"
cp "$repository_root/tests/fixtures/execution-result-broken.json" "$temporary_directory/test/fixture-result.json"

"$repository_root/scripts/classify-worker-outcome.sh" 0 0 "$temporary_directory/passed" "$temporary_directory/passed.json"
"$repository_root/scripts/classify-worker-outcome.sh" 65 0 "$temporary_directory/product" "$temporary_directory/product.json"
"$repository_root/scripts/classify-worker-outcome.sh" 65 0 "$temporary_directory/test" "$temporary_directory/test.json"
"$repository_root/scripts/classify-worker-outcome.sh" 70 66 "$temporary_directory/empty" "$temporary_directory/infrastructure.json"
"$repository_root/scripts/classify-worker-outcome.sh" 0 0 "$temporary_directory/empty" "$temporary_directory/unknown.json"

jq -e '.category == "passed" and .retryable == false' "$temporary_directory/passed.json" >/dev/null
jq -e '.category == "product" and .reason_code == "allure.assertion_failed"' "$temporary_directory/product.json" >/dev/null
jq -e '.category == "test" and .reason_code == "allure.test_broken"' "$temporary_directory/test.json" >/dev/null
jq -e '.category == "infrastructure" and .retryable == true' "$temporary_directory/infrastructure.json" >/dev/null
jq -e '.category == "unknown" and .retryable == false' "$temporary_directory/unknown.json" >/dev/null

echo "Worker outcome classification contract tests passed"
