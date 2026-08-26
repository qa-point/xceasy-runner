#!/bin/sh
set -eu

repository_root=$(cd "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

"$repository_root/scripts/build-simulator-health-report.sh" \
    "$repository_root/tests/fixtures/simctl-devices.json" \
    "$repository_root/tests/fixtures/simulator-health-config.json" \
    "$temporary_directory/health.json"

jq -e '
    .schema_version == "1.0.0" and
    .healthy_device_ids == ["available-device"] and
    (.devices | length) == 3 and
    (.rejected | map(.reason_code)) == ["simulator.unavailable", "simulator.not_found"]
' "$temporary_directory/health.json" >/dev/null

echo "Simulator health report contract tests passed"
