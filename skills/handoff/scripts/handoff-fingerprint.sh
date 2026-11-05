#!/usr/bin/env bash
# handoff-fingerprint: the pointer's fingerprint fields, read from git — never from memory.
# usage: handoff-fingerprint.sh [repo-dir]   ->  JSON {branch, head, dirty, dirty_files, now[, session]}
# session = first 8 chars of CLAUDE_CODE_SESSION_ID, omitted when unset. Never the bridge/cloud id:
# its first 8 chars are "session_" for every session.
# now = local "YYYY-MM-DD HH:MM", the stamp for entry headings and decision suffixes.
set -euo pipefail
cd "${1:-.}"
branch=$(git rev-parse --abbrev-ref HEAD)
head=$(git rev-parse --short HEAD)
session="${CLAUDE_CODE_SESSION_ID:-}"
session="${session:0:8}"
now=$(date "+%Y-%m-%d %H:%M")
git -c core.quotepath=false status --porcelain=v1 -z | python3 -c '
import json, re, sys
raw = sys.stdin.buffer.read().decode("utf-8", "replace").split("\0")
files = [r[3:] for r in raw if len(r) > 3]
out = {"branch": sys.argv[1], "head": sys.argv[2], "dirty": len(files), "dirty_files": files, "now": sys.argv[4]}
if re.fullmatch(r"[0-9a-f]{8}", sys.argv[3]):
    out["session"] = sys.argv[3]
print(json.dumps(out))
' "$branch" "$head" "$session" "$now"
