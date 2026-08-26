#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output.md>" >&2
    exit 64
fi

repository_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$(jq -r '.version' "$repository_root/release-metadata.json")
output=$1
section=$(awk -v heading="## $version " '
    index($0, heading) == 1 {active=1; next}
    active && /^## / {exit}
    active {print}
' "$repository_root/CHANGELOG.md")
if [ -z "$section" ]; then
    echo "CHANGELOG section not found for $version" >&2
    exit 65
fi

{
    printf '# XCEasy Runner %s\n\n' "$version"
    printf '%s\n' "$section"
    printf '\n## Installation\n\n'
    printf 'Extract the archive and add its `bin` directory to `PATH`:\n\n'
    printf '```bash\n'
    printf 'tar -xzf xceasy-runner-%s-macos-universal.tar.gz\n' "$version"
    printf 'export PATH="$PWD/xceasy-runner-%s/bin:$PATH"\n' "$version"
    printf 'xceasyctl version\n'
    printf '```\n\n'
    printf 'Verify the archive before extraction with the published `.sha256` file.\n'
} > "$output"
