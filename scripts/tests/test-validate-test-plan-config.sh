#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

jq -n '{
  schema_version:"1.0.0", mode:"shard", workspace:"Example.xcworkspace", scheme:"Example",
  test_target:"ExampleUITests", runner_bundle_id:"example.tests.xctrunner", output_directory:"artifacts",
  devices:[{type:"simulator",id:"simulator-1"}], test_plan:"Regression", test_configuration:"English"
}' > "$temporary_directory/valid.json"
"$repository_root/scripts/validate-config.sh" "$temporary_directory/valid.json"

jq 'del(.test_configuration)' "$temporary_directory/valid.json" > "$temporary_directory/missing-configuration.json"
if "$repository_root/scripts/validate-config.sh" "$temporary_directory/missing-configuration.json" >/dev/null 2>&1; then
  echo "Config with a test plan but no configuration was accepted" >&2
  exit 1
fi

jq '.schema_version="1.1.0"' "$temporary_directory/valid.json" > "$temporary_directory/unsupported-version.json"
if "$repository_root/scripts/validate-config.sh" "$temporary_directory/unsupported-version.json" >/dev/null 2>&1; then
  echo "Unsupported future schema version was accepted" >&2
  exit 1
fi

echo "Test-plan config validation contract passed"
