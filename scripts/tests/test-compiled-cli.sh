#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
swift build --package-path "$repository_root" --configuration debug --product xceasyctl >/dev/null
binary_path=$(swift build --package-path "$repository_root" --configuration debug --show-bin-path)
cli="$binary_path/xceasyctl"

"$cli" version | grep -q '^xceasy-runner '
"$cli" validate-config "$repository_root/examples/xceasy-runner.json" >/dev/null
"$cli" help | grep -q '^Usage:'
if "$cli" test --unknown-option >/dev/null 2>&1; then
  echo "Compiled CLI accepted an unknown option" >&2
  exit 1
fi

for option in \
    --config --annotation --require-annotation --exclude-annotation \
    --device --simulator --physical-device --mode --output-directory \
    --state-isolation --test-plan --test-configuration; do
    if "$cli" test "$option" >/dev/null 2>&1; then
        echo "Compiled CLI accepted a missing value for $option" >&2
        exit 1
    fi
done

if "$cli" unknown >/dev/null 2>&1; then
    echo "Compiled CLI accepted an unknown command" >&2
    exit 1
fi
if "$cli" validate-config one two >/dev/null 2>&1; then
    echo "Compiled CLI accepted too many validate-config arguments" >&2
    exit 1
fi

echo "Compiled Swift CLI contract test passed"
