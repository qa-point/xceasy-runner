#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$repository_root/scripts/lib/environment.sh"
resolve_xcode_developer_dir
version=$(jq -r '.version' "$repository_root/release-metadata.json")
dist="$repository_root/dist"
stage=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-runner-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
package_root="$stage/xceasy-runner-$version"

"$repository_root/scripts/build-cli.sh" release >/dev/null
binary_path=$(swift build --package-path "$repository_root" --configuration release --show-bin-path --arch arm64 --arch x86_64)
mkdir -p "$package_root/bin" "$package_root/libexec/xceasy-runner/bin" \
  "$package_root/libexec/xceasy-runner/scripts/lib" "$package_root/libexec/xceasy-runner/schemas" "$dist"
install -m 755 "$binary_path/xceasyctl" "$package_root/bin/xceasyctl"
codesign --force --sign "${XC_EASY_CODESIGN_IDENTITY:--}" "$package_root/bin/xceasyctl"
install -m 755 "$repository_root/bin/xceasy" "$package_root/libexec/xceasy-runner/bin/xceasy"
find "$repository_root/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.json' \) -exec install -m 755 {} "$package_root/libexec/xceasy-runner/scripts/" \;
find "$repository_root/scripts/lib" -maxdepth 1 -type f -exec install -m 755 {} "$package_root/libexec/xceasy-runner/scripts/lib/" \;
find "$repository_root/schemas" -maxdepth 1 -type f -name '*.json' -exec install -m 644 {} "$package_root/libexec/xceasy-runner/schemas/" \;
install -m 644 "$repository_root/release-metadata.json" "$package_root/libexec/xceasy-runner/release-metadata.json"
install -m 755 "$repository_root/packaging/install-release.sh" "$package_root/install.sh"

archive="$dist/xceasy-runner-$version-macos-universal.tar.gz"
tar -C "$stage" -czf "$archive" "xceasy-runner-$version"
(CDPATH= cd -- "$dist" && shasum -a 256 "$(basename "$archive")") > "$archive.sha256"
echo "$archive"
