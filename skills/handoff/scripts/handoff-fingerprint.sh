#!/usr/bin/env bash
# handoff-fingerprint: the pointer's fingerprint fields, read from git — never from memory.
# usage: handoff-fingerprint.sh [repo-dir]   ->  JSON {branch, head, dirty, dirty_files}
set -euo pipefail
cd "${1:-.}"
branch=$(git rev-parse --abbrev-ref HEAD)
head=$(git rev-parse --short HEAD)
git -c core.quotepath=false status --porcelain=v1 -z | python3 -c '
import json, sys
raw = sys.stdin.buffer.read().decode("utf-8", "replace").split("\0")
files = [r[3:] for r in raw if len(r) > 3]
print(json.dumps({"branch": sys.argv[1], "head": sys.argv[2], "dirty": len(files), "dirty_files": files}))
' "$branch" "$head"
