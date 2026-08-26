#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-runtime-config.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

write_config() {
    output=$1
    mode=$2
    devices=$3
    jq -n --arg output "$output" --arg mode "$mode" --argjson devices "$devices" '{
        schema_version:"1.0.0",
        mode:$mode,
        workspace:"Fake.xcworkspace",
        scheme:"Stress",
        test_target:"StressUITests",
        runner_bundle_id:"example.stress.xctrunner",
        output_directory:$output,
        devices:$devices
    }'
}

# Defaults and replicate semantics: every healthy device receives the complete selected suite.
replicate_root="$temporary_directory/replicate"
write_config "$replicate_root" replicate '[{"type":"simulator","id":"device-1"},{"type":"simulator","id":"device-2"}]' \
    > "$temporary_directory/replicate.json"
PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/replicate.json" --plan-only >/dev/null
replicate_plan=$(find "$replicate_root" -name execution-plan.json -print -quit)
jq -e '
    .mode == "replicate" and
    .recovery_policy == {retry_missing_tests:true,max_recovery_attempts:2} and
    .require_all_devices == false and
    .test_plan == null and
    .selection.policy == {include_any:[],include_all:[],exclude:[]} and
    .test_count == 100 and
    (.assignments | length) == 2 and
    all(.assignments[]; (.tests | length) == 100)
' "$replicate_plan" >/dev/null

# A rejected device is tolerated by default and recorded in the plan.
degraded_root="$temporary_directory/degraded"
write_config "$degraded_root" shard '[{"type":"simulator","id":"device-1"},{"type":"simulator","id":"missing-device"}]' \
    > "$temporary_directory/degraded.json"
PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/degraded.json" --plan-only >/dev/null
degraded_plan=$(find "$degraded_root" -name execution-plan.json -print -quit)
jq -e '
    .require_all_devices == false and
    (.assignments | length) == 1 and
    .device_health.counts == {requested:2,healthy:1,simulator:1,physical:0} and
    (.device_health.rejected | length) == 1
' "$degraded_plan" >/dev/null

# The same matrix must fail when every configured device is required.
jq '.require_all_devices=true | .output_directory=$output' \
    --arg output "$temporary_directory/strict" "$temporary_directory/degraded.json" \
    > "$temporary_directory/strict.json"
if PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/strict.json" --plan-only \
    >/dev/null 2>&1; then
    echo "require_all_devices=true accepted a rejected device" >&2
    exit 1
fi

# Physical signing options must be forwarded only to the physical build.
signing_log="$temporary_directory/xcodebuild.log"
jq -n --arg output "$temporary_directory/signing" '{
    schema_version:"1.0.0",mode:"shard",retry_missing_tests:false,require_all_devices:true,
    workspace:"Fake.xcworkspace",scheme:"Stress",test_target:"StressUITests",
    runner_bundle_id:"example.stress.xctrunner",output_directory:$output,
    devices:[{type:"simulator",id:"device-1"},{type:"physical",id:"physical-device-1"}],
    physical_device:{development_team:"TEAM123",allow_provisioning_updates:true,allow_device_registration:true}
}' > "$temporary_directory/signing.json"
PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/signing-state" \
XC_EASY_XCODEBUILD_LOG="$signing_log" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/signing.json" --plan-only >/dev/null
grep -q 'CODE_SIGNING_ALLOWED=NO.*build-for-testing' "$signing_log"
grep -q 'DEVELOPMENT_TEAM=TEAM123.*-allowProvisioningUpdates.*-allowProvisioningDeviceRegistration.*build-for-testing' "$signing_log"

# State isolation must reach the generated xctestrun environment.
jq -n --arg output "$temporary_directory/isolation" '{
    schema_version:"1.0.0",mode:"shard",retry_missing_tests:false,
    workspace:"Fake.xcworkspace",scheme:"Stress",test_target:"StressUITests",
    runner_bundle_id:"example.stress.xctrunner",output_directory:$output,
    devices:[{type:"simulator",id:"device-1"}],state_isolation:"app_reset_hook"
}' > "$temporary_directory/isolation.json"
PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/isolation-state" \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/isolation.json" >/dev/null
isolation_run=$(find "$temporary_directory/isolation" -mindepth 1 -maxdepth 1 -type d -print -quit)
isolation_xctestrun=$(find "$isolation_run/builds/simulator" -name 'xceasy-shard-0.xctestrun' -print -quit)
[ "$(plutil -extract StressUITests.EnvironmentVariables.XC_EASY_STATE_ISOLATION raw "$isolation_xctestrun")" = "app_reset_hook" ]

# Relative performance baseline/policy paths and the environment key must flow through the main run.
jq -n '{
    schemaVersion:"1.0.0",environmentKey:"ios|debug",generatedAt:"2026-01-01T00:00:00Z",
    operationCount:1,operations:[{
        operationKey:"ui.tap",executionSamples:1,observationCount:5,
        medianOfExecutionP95Milliseconds:200,p95OfExecutionP95Milliseconds:200,
        maximumExecutionP95Milliseconds:200,evidence:[]
    }]
}' > "$temporary_directory/baseline.json"
jq '.minimumExecutionSamples=1' "$repository_root/scripts/performance-regression-policy.json" \
    > "$temporary_directory/policy.json"
jq -n --arg output "$temporary_directory/performance" '{
    schema_version:"1.0.0",mode:"shard",retry_missing_tests:false,
    workspace:"Fake.xcworkspace",scheme:"Stress",test_target:"StressUITests",
    runner_bundle_id:"example.stress.xctrunner",output_directory:$output,
    devices:[{type:"simulator",id:"device-1"}],
    performance_environment_key:"ios|debug",
    performance_baseline:"baseline.json",
    performance_policy:"policy.json"
}' > "$temporary_directory/performance.json"
PATH="$repository_root/scripts/tests/fakes/recovery:$PATH" \
XC_EASY_FAKE_STATE="$temporary_directory/performance-state" \
XC_EASY_FAKE_PERFORMANCE=true \
    "$repository_root/scripts/run-multidevice-tests.sh" "$temporary_directory/performance.json" >/dev/null
performance_run=$(find "$temporary_directory/performance" -mindepth 1 -maxdepth 1 -type d -print -quit)
jq -e '.environmentKey == "ios|debug" and .operationCount == 1' "$performance_run/performance-run-summary.json" >/dev/null
jq -e '.environmentKey == "ios|debug" and .status == "passed"' "$performance_run/performance-regression.json" >/dev/null

echo "Runtime configuration behavior matrix passed"
