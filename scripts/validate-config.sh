#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <xceasy-runner.json>" >&2
    exit 64
fi

config=$1
[ -f "$config" ] || { echo "Configuration not found: $config" >&2; exit 66; }
command -v jq >/dev/null 2>&1 || { echo "Required command not found: jq" >&2; exit 69; }

jq -e '
    type == "object" and
    (.schema_version == "1.0.0") and
    ((keys - [
        "schema_version", "mode", "retry_missing_tests", "max_recovery_attempts",
        "require_all_devices", "workspace", "scheme", "test_target",
        "runner_bundle_id", "output_directory", "devices", "selection",
        "performance_environment_key", "performance_baseline", "performance_policy",
        "physical_device", "state_isolation", "test_plan", "test_configuration"
    ]) | length == 0) and
    (.mode == "shard" or .mode == "replicate") and
    ((if has("retry_missing_tests") then .retry_missing_tests else true end) | type == "boolean") and
    ((if has("require_all_devices") then .require_all_devices else false end) | type == "boolean") and
    ((if has("max_recovery_attempts") then .max_recovery_attempts else 2 end) as $value |
        ($value | type) == "number" and ($value | floor) == $value and $value >= 0 and $value <= 5) and
    all(.workspace, .scheme, .test_target, .runner_bundle_id, .output_directory;
        type == "string" and length > 0) and
    (.devices | type == "array" and length > 0) and
    (.devices | all(.[];
            (type == "object") and
            (((keys - ["type", "id", "name"]) | length) == 0) and
            (.type == "simulator" or .type == "physical") and
            (
                ((has("id") and (has("name") | not)) and (.id | type == "string" and length > 0)) or
                ((has("name") and (has("id") | not)) and (.name | type == "string" and length > 0))
            )
        )) and
        ([.devices[] | [.type, (.id // ""), (.name // "")]] | length == (unique | length)) and
        ((if has("physical_device") then .physical_device else {} end) | type == "object") and
        (((if has("physical_device") then .physical_device else {} end) | keys - ["allow_provisioning_updates", "allow_device_registration", "development_team"]) | length == 0) and
        ((if has("physical_device") and (.physical_device | has("allow_provisioning_updates")) then .physical_device.allow_provisioning_updates else false end) | type == "boolean") and
        ((if has("physical_device") and (.physical_device | has("allow_device_registration")) then .physical_device.allow_device_registration else false end) | type == "boolean") and
        ((if has("physical_device") and (.physical_device | has("development_team")) then .physical_device.development_team else "" end) | type == "string") and
        (((if has("physical_device") and (.physical_device | has("allow_device_registration")) then .physical_device.allow_device_registration else false end) | not) or (.physical_device.allow_provisioning_updates == true)) and
    ((has("test_plan") and has("test_configuration") and
          (.test_plan | type == "string" and length > 0) and
          (.test_configuration | type == "string" and length > 0)) or
     ((has("test_plan") | not) and (has("test_configuration") | not))) and
    ((if has("state_isolation") then .state_isolation else "none" end) as $value | $value == "none" or $value == "app_reset_hook") and
    ((if has("selection") then .selection else {} end) | type == "object") and
    (((if has("selection") then .selection else {} end) | keys - ["include_any", "include_all", "exclude"]) | length == 0) and
    all(
        (if has("selection") and (.selection | has("include_any")) then .selection.include_any else [] end),
        (if has("selection") and (.selection | has("include_all")) then .selection.include_all else [] end),
        (if has("selection") and (.selection | has("exclude")) then .selection.exclude else [] end);
        type == "array" and all(.[]; type == "string" and length > 0) and length == (unique | length)
    ) and
    ((if has("performance_environment_key") then .performance_environment_key else "unspecified" end) | type == "string" and length > 0) and
    ((if has("performance_baseline") then .performance_baseline else "" end) | type == "string") and
    ((if has("performance_policy") then .performance_policy else "" end) | type == "string")
' "$config" >/dev/null || {
    echo "Configuration does not satisfy the declared execution config schema: $config" >&2
    exit 65
}
