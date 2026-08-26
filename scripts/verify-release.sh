#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$(jq -r '.version' "$repository_root/release-metadata.json")
tag=${1:-}
[ "$tag" = "v$version" ] || {
    echo "Tag $tag does not match release-metadata version v$version" >&2
    exit 65
}
[ -f "$repository_root/schemas/execution-config-$(jq -r '.config_schema_version' "$repository_root/release-metadata.json").schema.json" ] || {
    echo "Declared config schema is missing" >&2
    exit 66
}
grep -q "^## $version " "$repository_root/CHANGELOG.md" || {
    echo "CHANGELOG section is missing for $version" >&2
    exit 65
}
echo "Release metadata verified for $tag"
