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
# Preserve macOS download provenance; Gatekeeper decisions belong to the user.
cp -p "$package_root/bin/xceasyctl" "$prefix/bin/xceasyctl"
chmod 755 "$prefix/bin/xceasyctl"
mkdir -p "$prefix/libexec/xceasy-runner"
cp -R "$package_root/libexec/xceasy-runner/." "$prefix/libexec/xceasy-runner/"

echo "Installed xceasyctl to $prefix/bin/xceasyctl"
