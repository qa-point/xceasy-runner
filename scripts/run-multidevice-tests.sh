#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <execution-config.json> [--plan-only]" >&2
    exit 64
fi

config=$1
plan_only=${2:-}
if [ -n "$plan_only" ] && [ "$plan_only" != "--plan-only" ]; then
    echo "Unknown option: $plan_only" >&2
    exit 64
fi

script_directory=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$script_directory/lib/environment.sh"
resolve_xcode_developer_dir
"$script_directory/validate-config.sh" "$config"

for dependency in jq plutil xcodebuild xcrun; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "Required command not found: $dependency" >&2
        exit 69
    fi
done

config_directory=${XC_EASY_CONFIG_BASE_DIRECTORY:-$(cd "$(dirname "$config")" && pwd)}
workspace_value=$(jq -r '.workspace' "$config")
output_value=$(jq -r '.output_directory' "$config")
case "$workspace_value" in /*) workspace=$workspace_value ;; *) workspace="$config_directory/$workspace_value" ;; esac
case "$output_value" in /*) output_root=$output_value ;; *) output_root="$config_directory/$output_value" ;; esac

scheme=$(jq -r '.scheme' "$config")
test_target=$(jq -r '.test_target' "$config")
runner_bundle_id=$(jq -r '.runner_bundle_id' "$config")
mode=$(jq -r '.mode' "$config")
retry_missing_tests=$(jq -r 'if has("retry_missing_tests") then .retry_missing_tests else true end' "$config")
require_all_devices=$(jq -r '.require_all_devices // false' "$config")
max_recovery_attempts=$(jq -r 'if has("max_recovery_attempts") then .max_recovery_attempts else 2 end' "$config")
performance_environment_key=$(jq -r '.performance_environment_key // "unspecified"' "$config")
performance_baseline_value=$(jq -r '.performance_baseline // ""' "$config")
performance_policy_value=$(jq -r '.performance_policy // ""' "$config")
state_isolation=$(jq -r '.state_isolation // "none"' "$config")
test_plan=$(jq -r '.test_plan // ""' "$config")
test_configuration=$(jq -r '.test_configuration // ""' "$config")
if [ "$retry_missing_tests" != "true" ]; then
    max_recovery_attempts=0
fi
case "$performance_baseline_value" in
    "") performance_baseline= ;;
    /*) performance_baseline=$performance_baseline_value ;;
    *) performance_baseline="$config_directory/$performance_baseline_value" ;;
esac
case "$performance_policy_value" in
    "") performance_policy="$script_directory/performance-regression-policy.json" ;;
    /*) performance_policy=$performance_policy_value ;;
    *) performance_policy="$config_directory/$performance_policy_value" ;;
esac

run_id="run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
started_epoch=$(date +%s)
run_directory="$output_root/$run_id"
tests_file="$run_directory/tests.txt"
assignments_jsonl="$run_directory/assignments.jsonl"
all_tests_file="$run_directory/all-tests.txt"
metadata_manifest="$run_directory/test-metadata-manifest.json"
selection_report="$run_directory/test-selection.json"
simulator_registry="$run_directory/simulator-devices.json"
physical_registry="$run_directory/physical-devices.json"
device_health="$run_directory/device-health.json"
healthy_devices="$run_directory/healthy-devices.json"
mkdir -p "$run_directory/shards"
: > "$assignments_jsonl"

configured_simulators=$(jq '[.devices[] | if type == "string" then true else .type == "simulator" end] | map(select(.)) | length' "$config")
configured_physical=$(jq '[.devices[] | select(type == "object" and .type == "physical")] | length' "$config")
if [ "$configured_simulators" -gt 0 ]; then
    xcrun simctl list devices --json > "$simulator_registry"
else
    echo '{"devices":{}}' > "$simulator_registry"
fi
if [ "$configured_physical" -gt 0 ]; then
    xcrun devicectl list devices --json-output "$physical_registry" >/dev/null
else
    echo '{"result":{"devices":[]}}' > "$physical_registry"
fi
"$script_directory/build-device-health-report.sh" "$simulator_registry" "$physical_registry" "$config" "$device_health"
jq '.healthy_devices' "$device_health" > "$healthy_devices"
device_count=$(jq 'length' "$healthy_devices")
rejected_device_count=$(jq '.rejected | length' "$device_health")
if [ "$device_count" -eq 0 ]; then
    echo "No healthy iOS devices remain after preflight; see $device_health" >&2
    exit 69
fi
if [ "$require_all_devices" = "true" ] && [ "$rejected_device_count" -gt 0 ]; then
    echo "Device preflight rejected $rejected_device_count configured device(s); see $device_health" >&2
    exit 69
fi

canonical_test_binary=
for device_type in simulator physical; do
    type_count=$(jq --arg type "$device_type" '[.[] | select(.type == $type)] | length' "$healthy_devices")
    [ "$type_count" -gt 0 ] || continue
    build_directory="$run_directory/builds/$device_type/derived-data"
    first_destination=$(jq -r --arg type "$device_type" '[.[] | select(.type == $type)][0].destination' "$healthy_devices")
    build_command=(xcodebuild -quiet -workspace "$workspace" -scheme "$scheme" -destination "$first_destination" -derivedDataPath "$build_directory")
    if [ -n "$test_plan" ]; then
        build_command+=(-testPlan "$test_plan" -only-test-configuration "$test_configuration")
    fi
    if [ "$device_type" = "simulator" ]; then
        build_command+=(CODE_SIGNING_ALLOWED=NO)
    else
        development_team=$(jq -r '.physical_device.development_team // ""' "$config")
        allow_updates=$(jq -r '.physical_device.allow_provisioning_updates // false' "$config")
        allow_registration=$(jq -r '.physical_device.allow_device_registration // false' "$config")
        [ -z "$development_team" ] || build_command+=("DEVELOPMENT_TEAM=$development_team")
        [ "$allow_updates" != "true" ] || build_command+=(-allowProvisioningUpdates)
        [ "$allow_registration" != "true" ] || build_command+=(-allowProvisioningDeviceRegistration)
    fi
    build_command+=(build-for-testing)
    "${build_command[@]}"

    xctestrun_candidates=("$build_directory"/Build/Products/*.xctestrun)
    if [ "${#xctestrun_candidates[@]}" -ne 1 ] || [ ! -f "${xctestrun_candidates[0]}" ]; then
        echo "Expected exactly one generated $device_type .xctestrun file" >&2
        exit 66
    fi
    test_binary=$(find "$build_directory/Build/Products" -type f -path "*/$test_target.xctest/$test_target" -print -quit)
    if [ -z "$test_binary" ]; then
        echo "Built $device_type test binary not found for target $test_target" >&2
        exit 66
    fi
    echo "${xctestrun_candidates[0]}" > "$run_directory/builds/$device_type/base-xctestrun-path"
    echo "$test_binary" > "$run_directory/builds/$device_type/test-binary-path"
    if [ -z "$canonical_test_binary" ]; then
        canonical_test_binary=$test_binary
    else
        comparison_tests="$run_directory/builds/$device_type/tests.txt"
        "$script_directory/enumerate-swift-tests.sh" "$test_binary" "$test_target" "$comparison_tests"
        canonical_tests="$run_directory/builds/canonical-tests.txt"
        "$script_directory/enumerate-swift-tests.sh" "$canonical_test_binary" "$test_target" "$canonical_tests"
        if ! cmp -s "$canonical_tests" "$comparison_tests"; then
            echo "Test enumeration differs between simulator and physical builds" >&2
            exit 65
        fi
    fi
done
test_binary=$canonical_test_binary

"$script_directory/enumerate-swift-tests.sh" "$test_binary" "$test_target" "$tests_file"

cp "$tests_file" "$all_tests_file"

"$script_directory/build-test-metadata-manifest.sh" \
    "$test_binary" "$all_tests_file" "$test_target" "$metadata_manifest"

include_any=$(jq -c '.selection.include_any // [] | unique | sort' "$config")
include_all=$(jq -c '.selection.include_all // [] | unique | sort' "$config")
exclude=$(jq -c '.selection.exclude // [] | unique | sort' "$config")
jq -n \
    --slurpfile manifest "$metadata_manifest" \
    --argjson include_any "$include_any" \
    --argjson include_all "$include_all" \
    --argjson exclude "$exclude" '
    def intersects($left; $right): any($left[]; . as $value | $right | index($value) != null);
    def includes_all($markers; $required): all($required[]; . as $value | $markers | index($value) != null);
    [
        $manifest[0].records[]
        | . as $record
        | (if ($exclude | length) > 0 and intersects($record.markers; $exclude) then
              {included: false, reason: "excluded_marker"}
           elif ($include_any | length) > 0 and (intersects($record.markers; $include_any) | not) then
              {included: false, reason: "include_any_not_matched"}
           elif ($include_all | length) > 0 and (includes_all($record.markers; $include_all) | not) then
              {included: false, reason: "include_all_not_matched"}
           else
              {included: true, reason: "selected"}
           end) as $decision
        | $record + $decision
    ] as $records
    | {
        schema_version: "1.0.0",
        policy: {include_any: $include_any, include_all: $include_all, exclude: $exclude},
        included_count: ($records | map(select(.included)) | length),
        excluded_count: ($records | map(select(.included | not)) | length),
        records: $records
    }
' > "$selection_report"
jq -r '.records[] | select(.included) | .identifier' "$selection_report" > "$tests_file"

test_count=$(wc -l < "$tests_file" | tr -d ' ')
if [ "$test_count" -eq 0 ]; then
    echo "No executable test methods were enumerated" >&2
    exit 65
fi

for ((device_index = 0; device_index < device_count; device_index++)); do
    device=$(jq -r ".[$device_index].device_id" "$healthy_devices")
    device_type=$(jq -r ".[$device_index].type" "$healthy_devices")
    destination=$(jq -r ".[$device_index].destination" "$healthy_devices")
    shard_directory="$run_directory/shards/$device_index"
    mkdir -p "$shard_directory"
    shard_tests="$shard_directory/tests.txt"
    : > "$shard_tests"
    if [ "$mode" = "replicate" ]; then
        cp "$tests_file" "$shard_tests"
    else
        test_index=0
        while IFS= read -r test_identifier; do
            if [ $((test_index % device_count)) -eq "$device_index" ]; then
                echo "$test_identifier" >> "$shard_tests"
            fi
            test_index=$((test_index + 1))
        done < "$tests_file"
    fi
    jq -n \
        --arg device_id "$device" \
        --arg device_type "$device_type" \
        --arg destination "$destination" \
        --argjson shard_index "$device_index" \
        --rawfile tests "$shard_tests" \
        '{shard_index: $shard_index, device_id: $device_id, device_type: $device_type, destination: $destination, tests: ($tests | split("\n") | map(select(length > 0)))}' \
        >> "$assignments_jsonl"
done

jq -n \
    --arg schema_version "1.0.0" \
    --arg run_id "$run_id" \
    --arg mode "$mode" \
    --arg test_plan "$test_plan" \
    --arg test_configuration "$test_configuration" \
    --argjson retry_missing_tests "$retry_missing_tests" \
    --argjson max_recovery_attempts "$max_recovery_attempts" \
    --argjson require_all_devices "$require_all_devices" \
    --argjson test_count "$test_count" \
    --slurpfile assignments "$assignments_jsonl" \
    --slurpfile device_health "$device_health" \
    --slurpfile selection "$selection_report" \
    '{
        schema_version: $schema_version,
        run_id: $run_id,
        mode: $mode,
        test_plan: (if $test_plan == "" then null else {name: $test_plan, configuration: $test_configuration} end),
        test_count: $test_count,
        recovery_policy: {
            retry_missing_tests: $retry_missing_tests,
            max_recovery_attempts: $max_recovery_attempts
        },
        require_all_devices: $require_all_devices,
        selection: $selection[0],
        device_health: $device_health[0],
        assignments: $assignments
    }' \
    > "$run_directory/execution-plan.json"

echo "Execution plan: $run_directory/execution-plan.json"
if [ "$plan_only" = "--plan-only" ]; then
    jq . "$run_directory/execution-plan.json"
    exit 0
fi

pids=()
for ((device_index = 0; device_index < device_count; device_index++)); do
    device=$(jq -r ".[$device_index].device_id" "$healthy_devices")
    device_type=$(jq -r ".[$device_index].type" "$healthy_devices")
    destination=$(jq -r ".[$device_index].destination" "$healthy_devices")
    shard_directory="$run_directory/shards/$device_index"
    shard_tests="$shard_directory/tests.txt"
    if [ ! -s "$shard_tests" ]; then
        echo "Shard $device_index has no tests; skipping device $device"
        continue
    fi
    base_xctestrun=$(cat "$run_directory/builds/$device_type/base-xctestrun-path")
    shard_xctestrun="$(dirname "$base_xctestrun")/xceasy-shard-$device_index.xctestrun"
    cp "$base_xctestrun" "$shard_xctestrun"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_RUN_ID "$run_id"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_DEVICE_ID "$device"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_DEVICE_TYPE "$device_type"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_STATE_ISOLATION "$state_isolation"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_SHARD_INDEX "$device_index"
    "$script_directory/set-xctestrun-environment.sh" "$shard_xctestrun" "$test_target" XC_EASY_ATTEMPT 1
    (
        if [ "$device_type" = "simulator" ]; then
            xcrun simctl boot "$device" >/dev/null 2>&1 || true
        fi
        command=(
            xcodebuild -quiet
            -xctestrun "$shard_xctestrun"
            -destination "$destination"
            -resultBundlePath "$shard_directory/result.xcresult"
            test-without-building
        )
        if [ -n "$test_configuration" ]; then
            command+=(-only-test-configuration "$test_configuration")
        fi
        while IFS= read -r test_identifier; do
            command+=("-only-testing:$test_identifier")
        done < "$shard_tests"
        if "${command[@]}" > "$shard_directory/xcodebuild.log" 2>&1; then
            test_status=0
        else
            test_status=$?
        fi
        if "$(dirname "$0")/export-allure-results.sh" \
            "$device_type" "$device" "$runner_bundle_id" "$shard_directory/allure-results" \
            > "$shard_directory/export.log" 2>&1; then
            export_status=0
        else
            export_status=$?
        fi
        echo "$test_status" > "$shard_directory/xcode-status"
        echo "$export_status" > "$shard_directory/export-status"
        if [ "$test_status" -ne 0 ]; then
            echo "$test_status" > "$shard_directory/status"
        elif [ "$export_status" -ne 0 ]; then
            echo 70 > "$shard_directory/status"
        else
            echo 0 > "$shard_directory/status"
        fi
    ) &
    pids+=("$!")
done

for pid in "${pids[@]}"; do
    wait "$pid" || true
done

failed=0
completed_shards=()
for ((device_index = 0; device_index < device_count; device_index++)); do
    shard_directory="$run_directory/shards/$device_index"
    shard_results="$run_directory/shards/$device_index/allure-results"
    if [ -d "$shard_results" ] && [ -n "$(find "$shard_results" -maxdepth 1 -name '*-result.json' -print -quit)" ]; then
        completed_shards+=("$shard_results")
    fi
    status_file="$run_directory/shards/$device_index/status"
    xcode_status=$(cat "$shard_directory/xcode-status" 2>/dev/null || echo 70)
    export_status=$(cat "$shard_directory/export-status" 2>/dev/null || echo 66)
    "$(dirname "$0")/classify-worker-outcome.sh" \
        "$xcode_status" "$export_status" "$shard_results" "$shard_directory/classification.json"
    if [ -f "$status_file" ] && [ "$(cat "$status_file")" -ne 0 ]; then
        echo "Shard $device_index failed; see $run_directory/shards/$device_index/xcodebuild.log" >&2
        failed=1
    fi
done

aggregate_directory="$run_directory/allure-results"
if [ "${#completed_shards[@]}" -gt 0 ]; then
    "$(dirname "$0")/aggregate-allure-results.sh" "$aggregate_directory" "${completed_shards[@]}"
    "$(dirname "$0")/validate-allure-results.sh" "$aggregate_directory"
else
    mkdir -p "$aggregate_directory"
fi

finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
finished_epoch=$(date +%s)
coordinator_status=passed
if [ "$failed" -ne 0 ]; then
    coordinator_status=failed
fi
"$(dirname "$0")/build-execution-summary.sh" \
    "$run_directory/execution-plan.json" \
    "$aggregate_directory" \
    "$started_at" \
    "$finished_at" \
    "$((finished_epoch - started_epoch))" \
    "$coordinator_status" \
    "$run_directory/execution-summary.json"

candidate_devices="$run_directory/recovery-candidates.json"
candidate_jsonl="$run_directory/recovery-candidates.jsonl"
: > "$candidate_jsonl"
for ((device_index = 0; device_index < device_count; device_index++)); do
    classification="$run_directory/shards/$device_index/classification.json"
    if [ "$(jq -r '.category' "$classification")" = "passed" ]; then
        jq -nc \
            --arg device_id "$(jq -r ".[$device_index].device_id" "$healthy_devices")" \
            --arg device_type "$(jq -r ".[$device_index].type" "$healthy_devices")" \
            --arg destination "$(jq -r ".[$device_index].destination" "$healthy_devices")" \
            --argjson shard_index "$device_index" \
            '{device_id: $device_id, device_type: $device_type, destination: $destination, shard_index: $shard_index}' >> "$candidate_jsonl"
    fi
done
jq -s '.' "$candidate_jsonl" > "$candidate_devices"

recovery_attempt=2
last_recovery_attempt=$((max_recovery_attempts + 1))
while [ "$mode" = "shard" ] && [ "$recovery_attempt" -le "$last_recovery_attempt" ]; do
    missing_count=$(jq '.counts.missing' "$run_directory/execution-summary.json")
    if [ "$missing_count" -eq 0 ] || [ "$(jq 'length' "$candidate_devices")" -eq 0 ]; then
        break
    fi

    recovery_root="$run_directory/retries/$recovery_attempt"
    recovery_plan="$recovery_root/recovery-plan.json"
    mkdir -p "$recovery_root"
    "$(dirname "$0")/build-recovery-plan.sh" \
        "$run_directory/execution-summary.json" \
        "$run_directory/execution-plan.json" \
        "$candidate_devices" \
        "$test_target" \
        "$recovery_attempt" \
        "$recovery_plan"

    recovery_assignment_count=$(jq '.assignments | length' "$recovery_plan")
    if [ "$recovery_assignment_count" -eq 0 ]; then
        break
    fi

    retry_plan_temporary="$run_directory/execution-plan.retry.json"
    jq --slurpfile recovery "$recovery_plan" \
        '.retry_assignments = ((.retry_assignments // []) + $recovery[0].assignments)' \
        "$run_directory/execution-plan.json" > "$retry_plan_temporary"
    mv "$retry_plan_temporary" "$run_directory/execution-plan.json"

    recovery_pids=()
    for ((assignment_index = 0; assignment_index < recovery_assignment_count; assignment_index++)); do
        recovery_directory="$recovery_root/workers/$assignment_index"
        mkdir -p "$recovery_directory"
        device=$(jq -r ".assignments[$assignment_index].device_id" "$recovery_plan")
        device_type=$(jq -r ".assignments[$assignment_index].device_type" "$recovery_plan")
        destination=$(jq -r ".assignments[$assignment_index].destination" "$recovery_plan")
        shard_index=$(jq -r ".assignments[$assignment_index].shard_index" "$recovery_plan")
        jq -r ".assignments[$assignment_index].tests[]" "$recovery_plan" > "$recovery_directory/tests.txt"

        base_xctestrun=$(cat "$run_directory/builds/$device_type/base-xctestrun-path")
        recovery_xctestrun="$(dirname "$base_xctestrun")/xceasy-retry-$recovery_attempt-$assignment_index.xctestrun"
        cp "$base_xctestrun" "$recovery_xctestrun"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_RUN_ID "$run_id"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_DEVICE_ID "$device"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_DEVICE_TYPE "$device_type"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_STATE_ISOLATION "$state_isolation"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_SHARD_INDEX "$shard_index"
        "$script_directory/set-xctestrun-environment.sh" "$recovery_xctestrun" "$test_target" XC_EASY_ATTEMPT "$recovery_attempt"

        (
            recovery_command=(
                xcodebuild -quiet
                -xctestrun "$recovery_xctestrun"
                -destination "$destination"
                -resultBundlePath "$recovery_directory/result.xcresult"
                test-without-building
            )
            if [ -n "$test_configuration" ]; then
                recovery_command+=(-only-test-configuration "$test_configuration")
            fi
            while IFS= read -r test_identifier; do
                recovery_command+=("-only-testing:$test_identifier")
            done < "$recovery_directory/tests.txt"
            if "${recovery_command[@]}" > "$recovery_directory/xcodebuild.log" 2>&1; then
                recovery_xcode_status=0
            else
                recovery_xcode_status=$?
            fi
            if "$(dirname "$0")/export-allure-results.sh" \
                "$device_type" "$device" "$runner_bundle_id" "$recovery_directory/allure-results" \
                > "$recovery_directory/export.log" 2>&1; then
                recovery_export_status=0
            else
                recovery_export_status=$?
            fi
            echo "$recovery_xcode_status" > "$recovery_directory/xcode-status"
            echo "$recovery_export_status" > "$recovery_directory/export-status"
        ) &
        recovery_pids+=("$!")
    done

    for pid in "${recovery_pids[@]}"; do
        wait "$pid" || true
    done

    failed_devices_jsonl="$recovery_root/failed-devices.jsonl"
    : > "$failed_devices_jsonl"
    recovery_failed=0
    for ((assignment_index = 0; assignment_index < recovery_assignment_count; assignment_index++)); do
        recovery_directory="$recovery_root/workers/$assignment_index"
        recovery_results="$recovery_directory/allure-results"
        recovery_xcode_status=$(cat "$recovery_directory/xcode-status" 2>/dev/null || echo 70)
        recovery_export_status=$(cat "$recovery_directory/export-status" 2>/dev/null || echo 66)
        "$(dirname "$0")/classify-worker-outcome.sh" \
            "$recovery_xcode_status" "$recovery_export_status" "$recovery_results" "$recovery_directory/classification.json"
        if [ -d "$recovery_results" ] && [ -n "$(find "$recovery_results" -maxdepth 1 -name '*-result.json' -print -quit)" ]; then
            completed_shards+=("$recovery_results")
        fi
        if [ "$(jq -r '.category' "$recovery_directory/classification.json")" != "passed" ]; then
            jq -c ".assignments[$assignment_index].device_id" "$recovery_plan" >> "$failed_devices_jsonl"
            recovery_failed=1
        fi
    done
    failed_devices="$recovery_root/failed-devices.json"
    jq -s 'unique' "$failed_devices_jsonl" > "$failed_devices"
    next_candidates="$recovery_root/next-candidates.json"
    jq --slurpfile failed "$failed_devices" \
        '[.[] | .device_id as $device_id | select(($failed[0] | index($device_id)) == null)]' \
        "$candidate_devices" > "$next_candidates"
    mv "$next_candidates" "$candidate_devices"

    if [ "${#completed_shards[@]}" -gt 0 ]; then
        mv "$aggregate_directory" "$run_directory/allure-results-before-attempt-$recovery_attempt"
        "$(dirname "$0")/aggregate-allure-results.sh" "$aggregate_directory" "${completed_shards[@]}"
        "$(dirname "$0")/validate-allure-results.sh" "$aggregate_directory"
    fi

    coordinator_status=passed
    if [ "$recovery_failed" -ne 0 ]; then
        coordinator_status=failed
    fi
    finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    finished_epoch=$(date +%s)
    "$(dirname "$0")/build-execution-summary.sh" \
        "$run_directory/execution-plan.json" \
        "$aggregate_directory" \
        "$started_at" \
        "$finished_at" \
        "$((finished_epoch - started_epoch))" \
        "$coordinator_status" \
        "$run_directory/execution-summary.json"
    recovery_attempt=$((recovery_attempt + 1))
done

if [ "$(jq -r '.status' "$run_directory/execution-summary.json")" = "passed" ]; then
    failed=0
else
    failed=1
fi

if [ "$(jq -r '.status' "$run_directory/execution-summary.json")" = "interrupted" ]; then
    "$(dirname "$0")/reconcile-interrupted-run.sh" "$run_directory"
fi

if [ -n "$(find "$aggregate_directory" -maxdepth 1 -name '*_performance-summary.json' -print -quit)" ]; then
    "$(dirname "$0")/build-performance-baseline.sh" \
        "$aggregate_directory" "$run_directory/performance-run-summary.json" "$performance_environment_key"
    if [ -n "$performance_baseline" ]; then
        if ! "$(dirname "$0")/compare-performance-regression.sh" \
            "$performance_baseline" \
            "$aggregate_directory" \
            "$run_directory/performance-regression.json" \
            "$performance_policy" \
            "$performance_environment_key"; then
            failed=1
        fi
    fi
fi

"$(dirname "$0")/build-diagnostic-summary.sh" \
    "$run_directory/execution-summary.json" "$device_health" "$run_directory"
"$(dirname "$0")/build-artifact-manifest.sh" \
    "$run_directory" "$run_directory/artifact-manifest.json"
"$(dirname "$0")/validate-artifact-manifest.sh" \
    "$run_directory" "$run_directory/artifact-manifest.json"

if [ "$failed" -ne 0 ]; then
    echo "Multi-device run incomplete: $run_directory" >&2
    exit 1
fi

echo "Multi-device run completed: $run_directory"
