#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-runner-cli-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

jq -n --arg output "$temporary_directory/artifacts" '{
    schema_version: "1.0.0",
    mode: "replicate",
    workspace: "Fake.xcworkspace",
    scheme: "Stress",
    test_target: "StressUITests",
    runner_bundle_id: "example.stress.xctrunner",
    output_directory: $output,
    devices: [{type: "simulator", id: "original-device"}]
}' > "$temporary_directory/config.json"

PATH="$repository_root/scripts/tests/fakes:$PATH" \
XC_EASY_EXPECT_TEST_PLAN="UIKit Regression" \
XC_EASY_EXPECT_TEST_CONFIGURATION="English" \
    "$repository_root/bin/xceasy" test \
        --config "$temporary_directory/config.json" \
        --mode shard \
        --device device-1 \
        --device device-2 \
        --annotation smoke \
        --require-annotation smoke \
        --exclude-annotation Debug \
        --output-directory "$temporary_directory/override-artifacts" \
        --state-isolation app-reset-hook \
        --test-plan "UIKit Regression" \
        --test-configuration English \
        --no-recovery \
        --plan-only >/dev/null

plan=$(find "$temporary_directory/override-artifacts" -name execution-plan.json -print -quit)
jq -e '
    .mode == "shard" and
    .test_plan == {name: "UIKit Regression", configuration: "English"} and
    .recovery_policy.retry_missing_tests == false and
    (.assignments | length) == 2 and
    .selection.policy.include_any == ["smoke"] and
    .selection.policy.include_all == ["smoke"] and
    .selection.policy.exclude == ["Debug"]
' "$plan" >/dev/null

if PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/bin/xceasy" test --config "$temporary_directory/config.json" \
    --mode invalid --plan-only >/dev/null 2>&1; then
    echo "CLI accepted an invalid mode override" >&2
    exit 1
fi

if PATH="$repository_root/scripts/tests/fakes:$PATH" \
    "$repository_root/bin/xceasy" test --config "$temporary_directory/config.json" \
    --state-isolation reinstall --plan-only >/dev/null 2>&1; then
    echo "CLI accepted an invalid state-isolation override" >&2
    exit 1
fi

echo "CLI override and marker-selection contract passed"
