#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <test-binary> <test-target> <output.txt>" >&2
    exit 64
fi

binary=$1
test_target=$2
output=$3

for dependency in nm xcrun; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Required command not found: $dependency" >&2
        exit 69
    }
done
[ -f "$binary" ] || { echo "Test binary not found: $binary" >&2; exit 66; }

temporary_output=$(mktemp "${TMPDIR:-/tmp}/xceasy-tests.XXXXXX")
trap 'rm -f "$temporary_output"' EXIT
escaped_target=$(printf '%s' "$test_target" | sed 's/[&/]/\\&/g')

nm -gj "$binary" \
    | xcrun swift-demangle \
    | sed -nE "s/^[^.]+\\.([A-Za-z_][A-Za-z0-9_]*)\\.(test[A-Za-z0-9_]+)\\(\\) -> \\(\\)$/${escaped_target}\/\\1\/\\2()/p" \
    | LC_ALL=C sort -u > "$temporary_output"

if [ ! -s "$temporary_output" ]; then
    echo "No Swift XCTest methods were found in $binary" >&2
    exit 65
fi

mv "$temporary_output" "$output"
