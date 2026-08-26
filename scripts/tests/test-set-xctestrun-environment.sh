#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

cp "$repository_root/tests/fixtures/test-plan-format-2.xctestrun" "$temporary_directory/plan.xctestrun"
plutil -convert xml1 "$temporary_directory/plan.xctestrun"
"$repository_root/scripts/set-xctestrun-environment.sh" \
  "$temporary_directory/plan.xctestrun" SampleUITests XC_EASY_RUN_ID plan-run
[ "$(plutil -extract TestConfigurations.0.TestTargets.0.EnvironmentVariables.XC_EASY_RUN_ID raw "$temporary_directory/plan.xctestrun")" = "plan-run" ]

jq -n '{SampleUITests:{EnvironmentVariables:{XC_EASY_RUN_ID:"old"}}}' > "$temporary_directory/legacy.xctestrun"
plutil -convert xml1 "$temporary_directory/legacy.xctestrun"
"$repository_root/scripts/set-xctestrun-environment.sh" \
  "$temporary_directory/legacy.xctestrun" SampleUITests XC_EASY_RUN_ID legacy-run
[ "$(plutil -extract SampleUITests.EnvironmentVariables.XC_EASY_RUN_ID raw "$temporary_directory/legacy.xctestrun")" = "legacy-run" ]

echo ".xctestrun legacy/format-2 environment injection contract passed"
