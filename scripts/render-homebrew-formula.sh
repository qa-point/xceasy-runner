#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <release-archive.tar.gz> <output.rb>" >&2
    exit 64
fi

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
archive=$1
output=$2
version=$(jq -r '.version' "$repository_root/release-metadata.json")
[ -f "$archive" ] || { echo "Release archive not found: $archive" >&2; exit 66; }
checksum=$(shasum -a 256 "$archive" | awk '{print $1}')

sed \
    -e "s/@VERSION@/$version/g" \
    -e "s/@SHA256@/$checksum/g" \
    "$repository_root/packaging/homebrew/xceasyctl.rb.template" > "$output"

echo "$output"
