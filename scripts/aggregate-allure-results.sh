#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <destination> <shard-directory>..." >&2
    exit 64
fi

destination=$1
shift

mkdir -p "$destination"
if [ -n "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Destination must be empty to prevent mixing runs: $destination" >&2
    exit 73
fi

service_files="executor.json categories.json environment.properties"

for shard in "$@"; do
    if [ ! -d "$shard" ]; then
        echo "Shard directory not found: $shard" >&2
        exit 66
    fi
    for source in "$shard"/*; do
        [ -f "$source" ] || continue
        name=$(basename "$source")
        destination_file="$destination/$name"
        case " $service_files " in
            *" $name "*)
                if [ ! -f "$destination_file" ]; then
                    cp "$source" "$destination_file"
                fi
                ;;
            *)
                if [ -e "$destination_file" ]; then
                    echo "Artifact collision while aggregating: $name" >&2
                    exit 65
                fi
                cp "$source" "$destination_file"
                ;;
        esac
    done
done

echo "Aggregated $# shard(s) into $destination"
