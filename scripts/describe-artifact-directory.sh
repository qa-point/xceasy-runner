#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>" >&2
    exit 64
fi

directory=$(cd "$1" && pwd)
entries=$(mktemp)
trap 'rm -f "$entries"' EXIT

find "$directory" -type f -print | LC_ALL=C sort |
while IFS= read -r file; do
    relative_path=${file#"$directory"/}
    bytes=$(wc -c < "$file" | tr -d ' ')
    sha256=$(shasum -a 256 "$file" | awk '{print $1}')
    jq -nc \
        --arg path "$relative_path" \
        --arg sha256 "$sha256" \
        --argjson bytes "$bytes" \
        '{path: $path, bytes: $bytes, sha256: $sha256}'
done > "$entries"

total_bytes=$(jq -s 'map(.bytes) | add // 0' "$entries")
directory_sha256=$(shasum -a 256 "$entries" | awk '{print $1}')
jq -nc \
    --argjson bytes "$total_bytes" \
    --arg sha256 "$directory_sha256" \
    '{bytes: $bytes, sha256: $sha256}'
