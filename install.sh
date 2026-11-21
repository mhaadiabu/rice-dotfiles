#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/home
target=${1:-$HOME}

while IFS= read -r -d '' source; do
    path=${source#"$source_dir"/}
    destination="$target/$path"
    if [[ -e "$destination" || -L "$destination" ]]; then
        if ! cmp -s -- "$source" "$destination"; then
            printf 'Skipped existing %s\n' "$path"
        fi
        continue
    fi
    mkdir -p -- "$(dirname -- "$destination")"
    cp -p -- "$source" "$destination"
    printf 'Installed %s\n' "$path"
done < <(find "$source_dir" -type f -print0 | sort -z)
