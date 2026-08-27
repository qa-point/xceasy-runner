#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$repository_root"

command -v mise >/dev/null 2>&1 || {
    echo "Required command not found: mise" >&2
    exit 69
}
command -v rg >/dev/null 2>&1 || {
    echo "Required command not found: rg" >&2
    exit 69
}

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

rg --files -0 -g '*.swift' -g '!**/.build/**' |
    xargs -0 mise exec -- swiftlint lint --strict --quiet --config "$repository_root/.swiftlint.yml"

echo "SwiftLint passed"
