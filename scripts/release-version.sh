#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s vMAJOR.MINOR.PATCH[-alpha.N|-beta.N|-rc.N]\n' "$0" >&2
    exit 2
fi

version="$1"
pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\.[1-9][0-9]*)?$'
if [[ ! "$version" =~ $pattern ]]; then
    printf 'Invalid release version: %s\n' "$version" >&2
    exit 1
fi

if [[ "$version" == *-* ]]; then
    printf 'prerelease\n'
else
    printf 'stable\n'
fi
