#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-enumeration-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT
mkdir -p "$temporary_directory/bin"

printf 'fixture\n' > "$temporary_directory/test-binary"
cp "$repository_root/scripts/tests/fakes/nm" "$temporary_directory/bin/nm"
cp "$repository_root/scripts/tests/fakes/xcrun" "$temporary_directory/bin/xcrun"
chmod +x "$temporary_directory/bin/nm" "$temporary_directory/bin/xcrun"

PATH="$temporary_directory/bin:$PATH" \
    "$repository_root/scripts/enumerate-swift-tests.sh" \
        "$temporary_directory/test-binary" StressUITests "$temporary_directory/tests.txt"

test "$(wc -l < "$temporary_directory/tests.txt" | tr -d ' ')" -eq 100
grep -qx 'StressUITests/StressSuite/test0()' "$temporary_directory/tests.txt"
grep -qx 'StressUITests/StressSuite/test99()' "$temporary_directory/tests.txt"

echo "Static Swift XCTest enumeration contract passed"
