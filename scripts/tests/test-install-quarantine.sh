#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/xceasy-install-privacy.XXXXXX")
trap 'rm -rf "$stage"' EXIT
package="$stage/package"
prefix="$stage/prefix with spaces"
mkdir -p "$package/bin" "$package/libexec/xceasy-runner/bin"
cp "${XC_EASY_TEST_INSTALLER:-$repository_root/packaging/install-release.sh}" "$package/install.sh"
printf '#!/bin/sh\nexit 0\n' > "$package/bin/xceasyctl"
printf '#!/bin/sh\nexit 0\n' > "$package/libexec/xceasy-runner/bin/xceasy"
chmod +x "$package/bin/xceasyctl" "$package/libexec/xceasy-runner/bin/xceasy"
quarantine='0081;00000000;XCEasyInstallTest;'
/usr/bin/xattr -w com.apple.quarantine "$quarantine" "$package/bin/xceasyctl"
/usr/bin/xattr -w com.apple.quarantine "$quarantine" "$package/libexec/xceasy-runner/bin/xceasy"
sh "$package/install.sh" "$prefix" >/dev/null
for executable in "$prefix/bin/xceasyctl" "$prefix/libexec/xceasy-runner/bin/xceasy"; do
    actual=$(/usr/bin/xattr -p com.apple.quarantine "$executable")
    [ -n "$actual" ] || {
        echo "Installation removed quarantine: $executable" >&2
        exit 1
    }
done
if sh "$package/install.sh" relative-prefix >/dev/null 2>&1; then
    echo 'Installer accepted a relative prefix' >&2
    exit 1
fi
echo 'Installer preserves quarantine and handles prefixes with spaces'
