#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <test-binary> <enumerated-tests.txt> <test-target> <output.json>" >&2
    exit 64
fi

binary=$1
tests=$2
test_target=$3
output=$4

for dependency in strings jq; do
    command -v "$dependency" >/dev/null 2>&1 || { echo "Required command not found: $dependency" >&2; exit 69; }
done
[ -f "$binary" ] || { echo "Test binary not found: $binary" >&2; exit 66; }
[ -f "$tests" ] || { echo "Enumerated tests not found: $tests" >&2; exit 66; }

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-metadata.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT
descriptors="$temporary_directory/descriptors.json"

strings -a "$binary" \
    | jq -R 'fromjson? | select(type == "object") | select(.schemaVersion == "1.0.0" and (.kind | type == "string"))' \
    | jq -s 'unique_by([.kind, .scope, .targetType, .declaration, .concreteMethod, .values])' \
    > "$descriptors"

jq -Rn \
    --arg schema_version "1.0.0" \
    --arg target "$test_target" \
    --slurpfile descriptors "$descriptors" '
    def lines: [inputs | select(length > 0)];
    def method_name($identifier): ($identifier | capture("^[^/]+/(?<class>[^/]+)/(?<method>[^()]+)\\(\\)$"));
    lines as $tests
    | {
        schema_version: $schema_version,
        records: [
            $tests[] as $identifier
            | method_name($identifier) as $parts
            | ($descriptors[0] | map(select(
                .kind == "ParameterizedTest"
                and .targetType == $parts.class
                and .concreteMethod == $parts.method
            )) | first) as $parameterized
            | {
                identifier: $identifier,
                canonical_scenario: ($parameterized.canonicalScenario // $parts.method),
                case_id: ($parameterized.values[0] // null),
                markers: (
                    $descriptors[0]
                    | map(select(
                        .kind == "Marker"
                        and .targetType == $parts.class
                        and (
                            .scope == "class"
                            or .declaration == $parts.method
                            or .declaration == ($parameterized.canonicalScenario // "")
                        )
                    ) | .values[])
                    | unique | sort
                )
            }
        ]
    }
' < "$tests" > "$output"

jq -e '.schema_version == "1.0.0" and (.records | type == "array")' "$output" >/dev/null
