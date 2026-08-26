#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT
mkdir -p "$temporary_directory/source"
jq -n '{uuid:"physical-result",fullName:"Suite/testPhysical()",status:"passed"}' \
  > "$temporary_directory/source/physical-result-result.json"

PATH="$repository_root/scripts/tests/fakes/physical:$PATH" \
XC_EASY_FAKE_PHYSICAL_RESULTS="$temporary_directory/source" \
  "$repository_root/scripts/export-allure-results.sh" \
    physical physical-device-1 example.tests.xctrunner "$temporary_directory/exported" >/dev/null

jq -e '.uuid == "physical-result"' "$temporary_directory/exported/physical-result-result.json" >/dev/null
echo "Physical-device Allure export contract test passed"
