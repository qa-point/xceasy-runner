#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

jq -n '{devices:{"runtime":[
  {udid:"simulator-1",name:"QA Simulator",state:"Shutdown",isAvailable:true}
]}}' > "$temporary_directory/simulators.json"
jq -n '{
  schema_version:"1.0.0", mode:"shard", workspace:"Fake.xcworkspace", scheme:"Fake",
  test_target:"FakeUITests", runner_bundle_id:"example.fake.xctrunner", output_directory:"artifacts",
  devices:[
    {type:"simulator",name:"QA Simulator"},
    {type:"physical",id:"physical-device-1"},
    {type:"physical",name:"Missing iPhone"}
  ]
}' > "$temporary_directory/config.json"

"$repository_root/scripts/build-device-health-report.sh" \
  "$temporary_directory/simulators.json" \
  "$repository_root/tests/fixtures/devicectl-devices.json" \
  "$temporary_directory/config.json" \
  "$temporary_directory/health.json"

jq -e '
  .schema_version == "1.0.0" and
  .counts == {requested:3,healthy:2,simulator:1,physical:1} and
  (.healthy_devices | map(.type) | sort) == ["physical","simulator"] and
  .rejected == [{requested_index:2,type:"physical",selector:{type:"physical",name:"Missing iPhone"},status:"rejected",reason_code:"physical.not_found"}]
' "$temporary_directory/health.json" >/dev/null

echo "Mixed simulator/physical preflight contract tests passed"
