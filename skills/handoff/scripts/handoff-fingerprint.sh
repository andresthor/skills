#!/usr/bin/env bash
# handoff-fingerprint: the pointer's fingerprint fields, read from git — never from memory.
# usage: handoff-fingerprint.sh [repo-dir]   ->  JSON {branch, head, dirty, dirty_files}
set -euo pipefail
cd "${1:-.}"
branch=$(git rev-parse --abbrev-ref HEAD)
head=$(git rev-parse --short HEAD)
dirty=$(git status --short | grep -c . || true)
files=$(git status --short | awk '{printf "%s\"%s\"", (NR>1?",":""), $NF}')
printf '{"branch":"%s","head":"%s","dirty":%s,"dirty_files":[%s]}\n' "$branch" "$head" "$dirty" "$files"
