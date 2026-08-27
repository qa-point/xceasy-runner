#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

for dependency in bash jq plutil shasum; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Required command not found: $dependency" >&2
        exit 69
    }
done

find "$repository_root/bin" "$repository_root/scripts" \( -type f -name '*.sh' -o -path "$repository_root/bin/xceasy" \) |
while IFS= read -r script; do
    case "$(head -n 1 "$script")" in
        '#!/bin/bash'*) bash -n "$script" ;;
        *) sh -n "$script" ;;
    esac
done

"$repository_root/scripts/lint-swift.sh"

jq empty "$repository_root/release-metadata.json" "$repository_root"/schemas/*.json "$repository_root"/scripts/*.json
"$repository_root/scripts/validate-docs.sh"
"$repository_root/bin/xceasy" version >/dev/null
"$repository_root/bin/xceasy" validate-config "$repository_root/examples/xceasy-runner.json" >/dev/null

for test_script in "$repository_root"/scripts/tests/test-*.sh; do
    "$test_script"
done

echo "XCEasy Runner checks passed"
