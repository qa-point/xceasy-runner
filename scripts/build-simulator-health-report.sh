#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <simctl-devices.json> <execution-config.json> <output.json>" >&2
    exit 64
fi

registry=$1
config=$2
output=$3

jq -e '.devices | type == "object"' "$registry" >/dev/null
jq -e '.devices | type == "array" and length > 0' "$config" >/dev/null

jq -n \
    --slurpfile registry "$registry" \
    --slurpfile config "$config" '
    [$registry[0].devices | to_entries[] as $runtime | $runtime.value[] | . + {runtime: $runtime.key}] as $known
    | [$config[0].devices | to_entries[]
        | .key as $requested_index
        | .value as $device_id
        | ([$known[] | select(.udid == $device_id)][0] // null) as $device
        | if $device == null then
            {requested_index: $requested_index, device_id: $device_id, status: "rejected", reason_code: "simulator.not_found"}
          elif ($device.isAvailable // false) != true then
            {requested_index: $requested_index, device_id: $device_id, status: "rejected", reason_code: "simulator.unavailable", name: $device.name, runtime: $device.runtime, state: $device.state}
          else
            {requested_index: $requested_index, device_id: $device_id, status: "healthy", reason_code: null, name: $device.name, runtime: $device.runtime, state: $device.state}
          end] as $devices
    | {
        schema_version: "1.0.0",
        platform: "iOS Simulator",
        devices: $devices,
        healthy_device_ids: [$devices[] | select(.status == "healthy") | .device_id],
        rejected: [$devices[] | select(.status == "rejected")]
    }
' > "$output"
