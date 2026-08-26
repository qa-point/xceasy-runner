#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
mkdir -p "$temporary_directory/run/allure-results"
mkdir -p "$temporary_directory/run/shards/0/result.xcresult"
cp "$repository_root/tests/fixtures/manifest-summary.json" "$temporary_directory/run/execution-summary.json"
cp "$repository_root/tests/fixtures/manifest-artifact.log" "$temporary_directory/run/allure-results/test.log"
cp "$repository_root/tests/fixtures/manifest-artifact.log" "$temporary_directory/run/shards/0/result.xcresult/record.json"

"$repository_root/scripts/build-artifact-manifest.sh" "$temporary_directory/run" "$temporary_directory/run/artifact-manifest.json"
"$repository_root/scripts/validate-artifact-manifest.sh" "$temporary_directory/run" "$temporary_directory/run/artifact-manifest.json" >/dev/null
jq -e '
    .artifact_count == 3 and
    ([.artifacts[] | select(.kind == "xcresult_bundle")] | length) == 1 and
    all(.artifacts[]; (.sha256 | length) == 64 and .bytes > 0)
' "$temporary_directory/run/artifact-manifest.json" >/dev/null

cp "$repository_root/tests/fixtures/manifest-tampered.log" "$temporary_directory/run/allure-results/test.log"
if "$repository_root/scripts/validate-artifact-manifest.sh" "$temporary_directory/run" "$temporary_directory/run/artifact-manifest.json" >/dev/null 2>&1; then
    echo "Tampered artifact unexpectedly passed validation" >&2
    exit 1
fi

cp "$repository_root/tests/fixtures/manifest-artifact.log" "$temporary_directory/run/allure-results/test.log"
cp "$repository_root/tests/fixtures/manifest-tampered.log" "$temporary_directory/run/shards/0/result.xcresult/record.json"
if "$repository_root/scripts/validate-artifact-manifest.sh" "$temporary_directory/run" "$temporary_directory/run/artifact-manifest.json" >/dev/null 2>&1; then
    echo "Tampered xcresult bundle unexpectedly passed validation" >&2
    exit 1
fi

echo "Artifact manifest contract tests passed"
