#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <run-directory> <artifact-manifest.json>" >&2
    exit 64
fi

run_directory=$(cd "$1" && pwd)
manifest=$2
jq -e '.schema_version == "1.0.0" and (.artifacts | type == "array") and .artifact_count == (.artifacts | length)' "$manifest" >/dev/null

jq -c '.artifacts[]' "$manifest" |
while IFS= read -r artifact; do
    path=$(printf '%s' "$artifact" | jq -r '.path')
    kind=$(printf '%s' "$artifact" | jq -r '.kind')
    expected_bytes=$(printf '%s' "$artifact" | jq -r '.bytes')
    expected_sha256=$(printf '%s' "$artifact" | jq -r '.sha256')
    file="$run_directory/$path"
    if [ "$kind" = "xcresult_bundle" ]; then
        if [ ! -d "$file" ]; then
            echo "Manifest artifact missing: $path" >&2
            exit 65
        fi
        description="$(dirname "$0")/describe-artifact-directory.sh"
        actual=$("$description" "$file")
        actual_bytes=$(printf '%s' "$actual" | jq '.bytes')
        actual_sha256=$(printf '%s' "$actual" | jq -r '.sha256')
    else
        if [ ! -f "$file" ]; then
            echo "Manifest artifact missing: $path" >&2
            exit 65
        fi
        actual_bytes=$(wc -c < "$file" | tr -d ' ')
        actual_sha256=$(shasum -a 256 "$file" | awk '{print $1}')
    fi
    if [ "$actual_bytes" -ne "$expected_bytes" ] || [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "Manifest integrity mismatch: $path" >&2
        exit 65
    fi
done

echo "Validated artifact manifest: $manifest"
