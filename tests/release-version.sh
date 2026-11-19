#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$ROOT_DIR/scripts/release-version.sh"

expect_kind() {
    local version="$1" expected="$2" actual
    actual="$("$validator" "$version")"
    [[ "$actual" == "$expected" ]] || {
        printf 'Expected %s for %s, got %s\n' "$expected" "$version" "$actual" >&2
        exit 1
    }
}

expect_invalid() {
    if "$validator" "$1" >/dev/null 2>&1; then
        printf 'Accepted invalid version: %s\n' "$1" >&2
        exit 1
    fi
}

expect_kind v1.2.3 stable
expect_kind v0.1.0-rc.1 prerelease
expect_kind v2.0.0-beta.3 prerelease
expect_kind v0.5.0-alpha.1 prerelease
expect_invalid v01.2.3
expect_invalid v1.2
expect_invalid v1.2.3-rc.0
expect_invalid 1.2.3
printf '%s\n' 'Release version tests passed.'
