#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")" && pwd)
profiles=("$@")

if [ ${#profiles[@]} -eq 0 ]; then
    profiles=(php ext go)
fi

for profile in "${profiles[@]}"; do
    case "$profile" in
        php|ext|go) ;;
        *)
            echo "usage: $0 [php|ext|go]..." >&2
            exit 2
            ;;
    esac
done

for profile in "${profiles[@]}"; do
    "$repo_root/$profile/build.sh"
done
