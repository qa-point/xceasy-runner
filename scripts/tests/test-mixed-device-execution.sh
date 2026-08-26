#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

jq -n --arg output "$temporary_directory/artifacts" '{
  schema_version:"1.0.0", mode:"shard", retry_missing_tests:false, require_all_devices:true,
  workspace:"Fake.xcworkspace", scheme:"Stress", test_target:"StressUITests",
  runner_bundle_id:"example.stress.xctrunner", output_directory:$output,
  devices:[{type:"simulator",id:"device-1"},{type:"physical",id:"physical-device-1"}],
  physical_device:{allow_provisioning_updates:false,allow_device_registration:false},
  state_isolation:"app_reset_hook"
  ,test_plan:"Mixed Regression", test_configuration:"English"
}' > "$temporary_directory/config.json"

PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/state" \
XC_EASY_EXPECT_TEST_PLAN="Mixed Regression" \
XC_EASY_EXPECT_TEST_CONFIGURATION="English" \
  "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/config.json" >/dev/null

run_directory=$(find "$temporary_directory/artifacts" -mindepth 1 -maxdepth 1 -type d -print -quit)
jq -e '
  .schema_version == "1.0.0" and
  .test_plan == {name:"Mixed Regression",configuration:"English"} and
  (.assignments | length) == 2 and
  ([.assignments[].device_type] | sort) == ["physical","simulator"] and
  all(.assignments[]; .destination | startswith("platform=iOS"))
' "$run_directory/execution-plan.json" >/dev/null
jq -e '.status == "passed" and .counts.executed == 12 and .counts.missing == 0' \
  "$run_directory/execution-summary.json" >/dev/null

echo "Mixed simulator/physical execution contract test passed"
