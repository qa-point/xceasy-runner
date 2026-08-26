#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

"$repository_root/scripts/build-recovery-plan.sh" \
    "$repository_root/tests/fixtures/recovery-summary.json" \
    "$repository_root/tests/fixtures/recovery-execution-plan.json" \
    "$repository_root/tests/fixtures/recovery-candidates.json" \
    SampleUITests \
    3 \
    "$temporary_directory/recovery-plan.json"

jq -e '
    .attempt == 3 and
    (.assignments | length) == 2 and
    (.assignments[0] | .device_id == "device-1" and .starting_load == 4 and (.tests | length) == 1) and
    (.assignments[1] | .device_id == "device-2" and .starting_load == 2 and (.tests | length) == 3) and
    ([.assignments[].tests[]] | sort) == [
      "SampleUITests/Suite/testA()",
      "SampleUITests/Suite/testB()",
      "SampleUITests/Suite/testC()",
      "SampleUITests/Suite/testD()"
    ]
' "$temporary_directory/recovery-plan.json" >/dev/null

echo "Load-aware recovery plan contract tests passed"
