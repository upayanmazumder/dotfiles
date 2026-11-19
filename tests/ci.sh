#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

printf '%s\n' '== Shell syntax =='
find . \( -path './.git' -o -path './.apply-backups' \) -prune -o -type f -name '*.sh' -print0 \
    | xargs -0 -r -n1 bash -n
printf '%s\n' '== Python tests =='
python3 -B -m unittest discover -s scripts/sync -p 'test_*.py' -v

printf '%s\n' '== Plymouth unit tests =='
bash plymouth-obsidian/tests/unit_tests.sh
