#!/bin/sh

# Selects a complete Xcode without changing the machine-wide xcode-select value.
resolve_xcode_developer_dir() {
    if [ -n "${DEVELOPER_DIR:-}" ] && [ -d "$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform" ]; then
        return
    fi

    selected_developer_dir=$(xcode-select -p 2>/dev/null || true)
    if [ -n "$selected_developer_dir" ] && [ -d "$selected_developer_dir/Platforms/iPhoneSimulator.platform" ]; then
        DEVELOPER_DIR=$selected_developer_dir
        export DEVELOPER_DIR
        return
    fi

    for xcode_app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
        candidate_developer_dir="$xcode_app/Contents/Developer"
        if [ -d "$candidate_developer_dir/Platforms/iPhoneSimulator.platform" ]; then
            DEVELOPER_DIR=$candidate_developer_dir
            export DEVELOPER_DIR
            return
        fi
    done

    echo "A full Xcode installation with iOS platform support is unavailable." >&2
    echo "Set DEVELOPER_DIR or install Xcode in /Applications." >&2
    exit 69
}
