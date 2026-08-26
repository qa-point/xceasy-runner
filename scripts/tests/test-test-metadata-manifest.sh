#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-manifest-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

cat > "$fixture/test-binary" <<'EOF'
{"schemaVersion":"1.0.0","kind":"Marker","scope":"class","declaration":"LoginTests","targetType":"LoginTests","concreteMethod":null,"canonicalScenario":null,"values":["Team1"],"options":{},"parameters":[]}
{"schemaVersion":"1.0.0","kind":"Marker","scope":"method","declaration":"invalidLogin","targetType":"LoginTests","concreteMethod":null,"canonicalScenario":null,"values":["Debug"],"options":{},"parameters":[]}
{"schemaVersion":"1.0.0","kind":"ParameterizedTest","scope":"method","declaration":"invalidLogin","targetType":"LoginTests","concreteMethod":"testInvalidLogin__p001_wrong","canonicalScenario":"invalidLogin","values":["wrong","[1] wrong"],"options":{},"parameters":[]}
EOF
printf '%s\n' 'UITests/LoginTests/testInvalidLogin__p001_wrong()' > "$fixture/tests.txt"

"$repository_root/scripts/build-test-metadata-manifest.sh" \
    "$fixture/test-binary" "$fixture/tests.txt" UITests "$fixture/manifest.json"

jq -e '
    .schema_version == "1.0.0"
    and .records[0].case_id == "wrong"
    and .records[0].markers == ["Debug", "Team1"]
' "$fixture/manifest.json" >/dev/null

echo "Test metadata manifest contract passed"
