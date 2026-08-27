#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
version=$(jq -r '.version' "$repository_root/release-metadata.json")
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-release-contract.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

"$repository_root/scripts/verify-release.sh" "v$version" >/dev/null
if "$repository_root/scripts/verify-release.sh" "v0.0.0-invalid" >/dev/null 2>&1; then
    echo "Release verification unexpectedly accepted a mismatched tag" >&2
    exit 1
fi

notes="$temporary_directory/release-notes.md"
"$repository_root/scripts/build-release-notes.sh" "$notes"
grep -q "^# XCEasy Runner $version$" "$notes"
grep -q "xceasyctl version" "$notes"

grep -q 'gh release create' "$repository_root/.github/workflows/release.yml"
if grep -q 'Run real two-simulator acceptance' "$repository_root/.github/workflows/release.yml"; then
    echo "Release workflow must not run hosted UI acceptance" >&2
    exit 1
fi
grep -q 'Verify published release' "$repository_root/.github/workflows/release.yml"

archive="$temporary_directory/xceasy-runner-$version-macos-universal.tar.gz"
printf 'release contract fixture\n' > "$archive"
formula="$temporary_directory/xceasyctl.rb"
"$repository_root/scripts/render-homebrew-formula.sh" "$archive" "$formula" >/dev/null
grep -q "releases/download/v$version/" "$formula"
grep -q "$(shasum -a 256 "$archive" | awk '{print $1}')" "$formula"

echo "Release contract test passed"
