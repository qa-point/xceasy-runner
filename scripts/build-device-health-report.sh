#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <simctl-devices.json> <devicectl-devices.json> <execution-config.json> <output.json>" >&2
    exit 64
fi

simulator_registry=$1
physical_registry=$2
config=$3
output=$4

jq -e '.devices | type == "object"' "$simulator_registry" >/dev/null
jq -e '(.result.devices // []) | type == "array"' "$physical_registry" >/dev/null

jq -n \
    --slurpfile simulators "$simulator_registry" \
    --slurpfile physical "$physical_registry" \
    --slurpfile config "$config" '
    def requested_devices: $config[0].devices;
    [$simulators[0].devices | to_entries[] as $runtime | $runtime.value[] | . + {runtime: $runtime.key}] as $known_simulators
    | [($physical[0].result.devices // [])[] | {
        identifier: (.identifier // .hardwareProperties.udid // .deviceProperties.udid // ""),
        name: (.deviceProperties.name // .name // ""),
        model: (.hardwareProperties.marketingName // .hardwareProperties.productType // ""),
        operating_system: (.deviceProperties.osVersionNumber // .deviceProperties.osVersion // "")
      }] as $known_physical
    | [requested_devices | to_entries[]
        | .key as $requested_index
        | .value as $request
        | if $request.type == "simulator" then
            (if $request.id then [$known_simulators[] | select(.udid == $request.id)]
             else [$known_simulators[] | select(.name == $request.name)] end) as $matches
            | if ($matches | length) == 0 then
                {requested_index: $requested_index, type: "simulator", selector: $request, status: "rejected", reason_code: "simulator.not_found"}
              elif ($matches | length) > 1 then
                {requested_index: $requested_index, type: "simulator", selector: $request, status: "rejected", reason_code: "simulator.ambiguous_name"}
              elif ($matches[0].isAvailable // false) != true then
                {requested_index: $requested_index, type: "simulator", selector: $request, device_id: $matches[0].udid, status: "rejected", reason_code: "simulator.unavailable", name: $matches[0].name, runtime: $matches[0].runtime, state: $matches[0].state}
              else
                {requested_index: $requested_index, type: "simulator", selector: $request, device_id: $matches[0].udid, status: "healthy", reason_code: null, name: $matches[0].name, runtime: $matches[0].runtime, state: $matches[0].state, destination: ("platform=iOS Simulator,id=" + $matches[0].udid)}
              end
          else
            (if $request.id then [$known_physical[] | select(.identifier == $request.id)]
             else [$known_physical[] | select(.name == $request.name)] end) as $matches
            | if ($matches | length) == 0 then
                {requested_index: $requested_index, type: "physical", selector: $request, status: "rejected", reason_code: "physical.not_found"}
              elif ($matches | length) > 1 then
                {requested_index: $requested_index, type: "physical", selector: $request, status: "rejected", reason_code: "physical.ambiguous_name"}
              else
                {requested_index: $requested_index, type: "physical", selector: $request, device_id: $matches[0].identifier, status: "healthy", reason_code: null, name: $matches[0].name, model: $matches[0].model, operating_system: $matches[0].operating_system, destination: ("platform=iOS,id=" + $matches[0].identifier)}
              end
          end] as $devices
    | {
        schema_version: "1.0.0",
        devices: $devices,
        healthy_devices: [$devices[] | select(.status == "healthy") | {device_id, type, name, destination}],
        healthy_device_ids: [$devices[] | select(.status == "healthy") | .device_id],
        rejected: [$devices[] | select(.status == "rejected")],
        counts: {
            requested: ($devices | length),
            healthy: ([$devices[] | select(.status == "healthy")] | length),
            simulator: ([$devices[] | select(.status == "healthy" and .type == "simulator")] | length),
            physical: ([$devices[] | select(.status == "healthy" and .type == "physical")] | length)
        }
    }
' > "$output"
