#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <xctestrun> <test-target> <key> <value>" >&2
    exit 64
fi

xctestrun=$1
test_target=$2
key=$3
value=$4

set_value() {
    key_path=$1
    if plutil -extract "$key_path" raw "$xctestrun" >/dev/null 2>&1; then
        plutil -replace "$key_path" -string "$value" "$xctestrun"
    else
        plutil -insert "$key_path" -string "$value" "$xctestrun"
    fi
}

if plutil -extract "$test_target.EnvironmentVariables" json -o - "$xctestrun" >/dev/null 2>&1; then
    set_value "$test_target.EnvironmentVariables.$key"
    exit 0
fi

configuration_count=$(plutil -extract TestConfigurations json -o - "$xctestrun" 2>/dev/null | jq 'length') || {
    echo "Unsupported .xctestrun structure: $xctestrun" >&2
    exit 65
}
matched=0
configuration_index=0
while [ "$configuration_index" -lt "$configuration_count" ]; do
    targets=$(plutil -extract "TestConfigurations.$configuration_index.TestTargets" json -o - "$xctestrun")
    target_count=$(printf '%s' "$targets" | jq 'length')
    target_index=0
    while [ "$target_index" -lt "$target_count" ]; do
        blueprint_name=$(printf '%s' "$targets" | jq -r ".[$target_index].BlueprintName // \"\"")
        if [ "$blueprint_name" = "$test_target" ]; then
            set_value "TestConfigurations.$configuration_index.TestTargets.$target_index.EnvironmentVariables.$key"
            matched=$((matched + 1))
        fi
        target_index=$((target_index + 1))
    done
    configuration_index=$((configuration_index + 1))
done

if [ "$matched" -eq 0 ]; then
    echo "Test target $test_target was not found in $xctestrun" >&2
    exit 65
fi
