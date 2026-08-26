#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <simulator|physical> <device-id> <ui-test-runner-bundle-id> [destination]" >&2
    exit 64
fi

device_type=$1
device_id=$2
runner_bundle_id=$3
destination=${4:-allure-results}

mkdir -p "$destination"
if [ -n "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Destination must be empty to prevent mixing runs: $destination" >&2
    exit 73
fi

case "$device_type" in
    simulator)
        runner_container=$(xcrun simctl get_app_container "$device_id" "$runner_bundle_id" data)
        source_directory="$runner_container/Library/Caches/allure-results"
        if [ ! -d "$source_directory" ]; then
            echo "Allure results not found: $source_directory" >&2
            exit 66
        fi
        cp -R "$source_directory/." "$destination/"
        ;;
    physical)
        staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-device-export.XXXXXX")
        trap 'rm -rf "$staging_directory"' EXIT
        response="$staging_directory/devicectl-response.json"
        xcrun devicectl device copy from \
            --device "$device_id" \
            --source "Library/Caches/allure-results" \
            --destination "$staging_directory/export" \
            --domain-type appDataContainer \
            --domain-identifier "$runner_bundle_id" \
            --json-output "$response"
        source_directory="$staging_directory/export"
        if [ -d "$source_directory/allure-results" ]; then
            source_directory="$source_directory/allure-results"
        fi
        if [ ! -d "$source_directory" ]; then
            echo "Allure results were not copied from physical device $device_id" >&2
            exit 66
        fi
        cp -R "$source_directory/." "$destination/"
        ;;
    *)
        echo "Unsupported device type: $device_type" >&2
        exit 64
        ;;
esac
echo "Exported allure-results to $destination"
