#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$repository_root/scripts/lib/environment.sh"
resolve_xcode_developer_dir
prefix=${1:-/usr/local}
case "$prefix" in /*) ;; *) echo "Install prefix must be absolute: $prefix" >&2; exit 64 ;; esac

"$repository_root/scripts/build-cli.sh" release >/dev/null
binary_path=$(swift build --package-path "$repository_root" --configuration release --show-bin-path --arch arm64 --arch x86_64)
libexec="$prefix/libexec/xceasy-runner"

mkdir -p "$prefix/bin" "$libexec/bin" "$libexec/scripts" "$libexec/schemas"
install -m 755 "$binary_path/xceasyctl" "$prefix/bin/xceasyctl"
install -m 755 "$repository_root/bin/xceasy" "$libexec/bin/xceasy"
find "$repository_root/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.json' \) -exec install -m 755 {} "$libexec/scripts/" \;
mkdir -p "$libexec/scripts/lib"
find "$repository_root/scripts/lib" -maxdepth 1 -type f -exec install -m 755 {} "$libexec/scripts/lib/" \;
find "$repository_root/schemas" -maxdepth 1 -type f -name '*.json' -exec install -m 644 {} "$libexec/schemas/" \;
install -m 644 "$repository_root/release-metadata.json" "$libexec/release-metadata.json"

echo "Installed compiled CLI: $prefix/bin/xceasyctl"
echo "Installed private engine: $libexec"
