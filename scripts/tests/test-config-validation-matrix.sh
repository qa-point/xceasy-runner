#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-config-matrix.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT
base="$temporary_directory/base.json"
candidate="$temporary_directory/candidate.json"

jq -n '{
  schema_version:"1.0.0",
  mode:"shard",
  workspace:"Example.xcworkspace",
  scheme:"Example",
  test_target:"ExampleUITests",
  runner_bundle_id:"example.tests.xctrunner",
  output_directory:"artifacts",
  devices:[{type:"simulator",id:"simulator-1"}]
}' > "$base"

expect_valid() {
    name=$1
    filter=$2
    jq "$filter" "$base" > "$candidate"
    "$repository_root/scripts/validate-config.sh" "$candidate" >/dev/null || {
        echo "Expected valid config case failed: $name" >&2
        exit 1
    }
}

expect_invalid() {
    name=$1
    filter=$2
    jq "$filter" "$base" > "$candidate"
    if "$repository_root/scripts/validate-config.sh" "$candidate" >/dev/null 2>&1; then
        echo "Expected invalid config case was accepted: $name" >&2
        exit 1
    fi
}

expect_valid minimal '.'
expect_valid replicate '.mode="replicate"'
expect_valid recovery_lower_bound '.max_recovery_attempts=0'
expect_valid recovery_upper_bound '.max_recovery_attempts=5'
expect_valid explicit_defaults '.retry_missing_tests=true | .require_all_devices=false | .state_isolation="none"'
expect_valid state_reset '.state_isolation="app_reset_hook"'
expect_valid simulator_name '.devices=[{type:"simulator",name:"QA iPhone"}]'
expect_valid physical_id '.devices=[{type:"physical",id:"physical-1"}]'
expect_valid physical_name '.devices=[{type:"physical",name:"QA iPhone"}]'
expect_valid mixed_devices '.devices=[{type:"simulator",id:"sim-1"},{type:"physical",id:"phone-1"}]'
expect_valid test_plan '.test_plan="Regression" | .test_configuration="English"'
expect_valid selection '.selection={include_any:["Smoke"],include_all:["IOS"],exclude:["Flaky"]}'
expect_valid performance '.performance_environment_key="ios|debug" | .performance_baseline="baseline.json" | .performance_policy="policy.json"'
expect_valid physical_signing '.devices=[{type:"physical",id:"phone-1"}] | .physical_device={development_team:"TEAM123",allow_provisioning_updates:true,allow_device_registration:true}'

for field in schema_version mode workspace scheme test_target runner_bundle_id output_directory devices; do
    jq --arg field "$field" 'del(.[$field])' "$base" > "$candidate"
    if "$repository_root/scripts/validate-config.sh" "$candidate" >/dev/null 2>&1; then
        echo "Missing required field was accepted: $field" >&2
        exit 1
    fi
done

expect_invalid unsupported_schema '.schema_version="1.1.0"'
expect_invalid invalid_mode '.mode="parallel"'
expect_invalid unknown_field '.unknown=true'
expect_invalid empty_workspace '.workspace=""'
expect_invalid empty_scheme '.scheme=""'
expect_invalid empty_test_target '.test_target=""'
expect_invalid empty_runner_bundle_id '.runner_bundle_id=""'
expect_invalid empty_output '.output_directory=""'
expect_invalid retry_wrong_type '.retry_missing_tests="true"'
expect_invalid require_all_wrong_type '.require_all_devices=1'
expect_invalid recovery_negative '.max_recovery_attempts=-1'
expect_invalid recovery_too_large '.max_recovery_attempts=6'
expect_invalid recovery_fraction '.max_recovery_attempts=1.5'
expect_invalid empty_devices '.devices=[]'
expect_invalid legacy_string_device '.devices=["simulator-1"]'
expect_invalid invalid_device_type '.devices=[{type:"watch",id:"watch-1"}]'
expect_invalid device_without_selector '.devices=[{type:"simulator"}]'
expect_invalid device_with_both_selectors '.devices=[{type:"simulator",id:"sim-1",name:"QA"}]'
expect_invalid device_with_unknown_field '.devices=[{type:"simulator",id:"sim-1",model:"iPhone"}]'
expect_invalid duplicate_devices '.devices=[{type:"simulator",id:"sim-1"},{type:"simulator",id:"sim-1"}]'
expect_invalid plan_without_configuration '.test_plan="Regression"'
expect_invalid configuration_without_plan '.test_configuration="English"'
expect_invalid invalid_state_isolation '.state_isolation="reinstall"'
expect_invalid state_isolation_false '.state_isolation=false'
expect_invalid physical_wrong_type '.physical_device=[]'
expect_invalid physical_false '.physical_device=false'
expect_invalid physical_team_wrong_type '.physical_device={development_team:false}'
expect_invalid registration_without_updates '.devices=[{type:"physical",id:"phone-1"}] | .physical_device={allow_device_registration:true,allow_provisioning_updates:false}'
expect_invalid physical_unknown_field '.physical_device={automatic_signing:true}'
expect_invalid empty_performance_key '.performance_environment_key=""'
expect_invalid baseline_wrong_type '.performance_baseline=false'
expect_invalid policy_wrong_type '.performance_policy=42'
expect_invalid selection_unknown_field '.selection={tags:["Smoke"]}'
expect_invalid selection_wrong_type '.selection=[]'
expect_invalid selection_false '.selection=false'
expect_invalid selection_value_wrong_type '.selection={include_any:[1]}'
expect_invalid selection_empty_value '.selection={include_all:[""]}'
expect_invalid selection_duplicates '.selection={exclude:["Flaky","Flaky"]}'

echo "Execution config validation matrix passed"
