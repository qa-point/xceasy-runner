#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <run-directory> <output.json>" >&2
    exit 64
fi

run_directory=$(cd "$1" && pwd)
output=$2
index_jsonl=$(mktemp)
trap 'rm -f "$index_jsonl"' EXIT
script_directory=$(cd "$(dirname "$0")" && pwd)

(
    cd "$run_directory"
    find . -type f \
        ! -path './derived-data/*' \
        ! -path './builds/*' \
        ! -path '*.xcresult/*' \
        ! -name 'artifact-manifest.json' \
        -print | LC_ALL=C sort |
    while IFS= read -r relative_path; do
        normalized_path=${relative_path#./}
        bytes=$(wc -c < "$relative_path" | tr -d ' ')
        sha256=$(shasum -a 256 "$relative_path" | awk '{print $1}')
        case "$normalized_path" in
            *-result.json) kind=allure_result ;;
            *-container.json) kind=allure_container ;;
            *_events.jsonl) kind=diagnostic_events ;;
            *.log) kind=log ;;
            *.json) kind=json ;;
            *.png) kind=screenshot ;;
            *) kind=artifact ;;
        esac
        jq -nc \
            --arg path "$normalized_path" \
            --arg kind "$kind" \
            --arg sha256 "$sha256" \
            --argjson bytes "$bytes" \
            '{path: $path, kind: $kind, bytes: $bytes, sha256: $sha256}'
    done

    find . -type d -name '*.xcresult' \
        ! -path './derived-data/*' \
        ! -path './builds/*' \
        -print | LC_ALL=C sort |
    while IFS= read -r relative_path; do
        normalized_path=${relative_path#./}
        description=$("$script_directory/describe-artifact-directory.sh" "$relative_path")
        jq -nc \
            --arg path "$normalized_path" \
            --argjson bytes "$(printf '%s' "$description" | jq '.bytes')" \
            --arg sha256 "$(printf '%s' "$description" | jq -r '.sha256')" \
            '{path: $path, kind: "xcresult_bundle", bytes: $bytes, sha256: $sha256}'
    done
) > "$index_jsonl"

repository_root=$(cd "$(dirname "$0")/.." && pwd)
git_commit=$(git -C "$repository_root" rev-parse HEAD 2>/dev/null || true)
git_dirty=false
if [ -n "$(git -C "$repository_root" status --porcelain 2>/dev/null || true)" ]; then
    git_dirty=true
fi

jq -n \
    --arg schema_version "1.0.0" \
    --arg git_commit "$git_commit" \
    --argjson git_dirty "$git_dirty" \
    --slurpfile artifacts "$index_jsonl" \
    '{schema_version: $schema_version, git: {commit: $git_commit, dirty: $git_dirty}, artifact_count: ($artifacts | length), artifacts: $artifacts}' \
    > "$output"
