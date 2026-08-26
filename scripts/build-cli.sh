#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$repository_root/scripts/lib/environment.sh"
resolve_xcode_developer_dir
configuration=${1:-release}
case "$configuration" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 64 ;; esac

if [ "$configuration" = "release" ]; then
    swift build --package-path "$repository_root" --configuration release --product xceasyctl --arch arm64 --arch x86_64
    binary_path=$(swift build --package-path "$repository_root" --configuration release --show-bin-path --arch arm64 --arch x86_64)
else
    swift build --package-path "$repository_root" --configuration debug --product xceasyctl
    binary_path=$(swift build --package-path "$repository_root" --configuration debug --show-bin-path)
fi
echo "$binary_path/xceasyctl"
