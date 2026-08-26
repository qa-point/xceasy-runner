#!/bin/sh
set -eu

package_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
prefix=${1:-/usr/local}
case "$prefix" in
    /*) ;;
    *) echo "Install prefix must be absolute: $prefix" >&2; exit 64 ;;
esac

[ -x "$package_root/bin/xceasyctl" ] || {
    echo "Packaged bin/xceasyctl is missing" >&2
    exit 66
}
[ -x "$package_root/libexec/xceasy-runner/bin/xceasy" ] || {
    echo "Packaged private runtime is missing" >&2
    exit 66
}

mkdir -p "$prefix/bin" "$prefix/libexec"
install -m 755 "$package_root/bin/xceasyctl" "$prefix/bin/xceasyctl"
mkdir -p "$prefix/libexec/xceasy-runner"
cp -R "$package_root/libexec/xceasy-runner/." "$prefix/libexec/xceasy-runner/"
xattr -dr com.apple.quarantine "$prefix/bin/xceasyctl" "$prefix/libexec/xceasy-runner" 2>/dev/null || true

echo "Installed xceasyctl to $prefix/bin/xceasyctl"
