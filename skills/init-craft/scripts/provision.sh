#!/bin/sh
# init-craft v2
# Gives a linked worktree the main checkout's untracked agent layer and installs deps.
# Installed as <common-dir>/hooks/craft-provision (local copy, not tracked).
# Rules: never replaces an existing path, never writes a tracked path, never writes through a
# symlinked parent; link targets are absolute paths into the main checkout (computed, not stored).
# Output goes to stderr only; exit 0 always, except usage errors (2) and no repo (1).
usage() {
  cat >&2 <<'USAGE'
usage: craft-provision [--dry-run] <worktree>...      provision these worktrees
       craft-provision [--dry-run] --all              every linked worktree (backfill)
       craft-provision [--dry-run] --install-only <worktree>...
       craft-provision --defaults                     print the built-in entry list
       craft-provision --detect <dir>                 print the package manager `install` would use
       craft-provision --help
Config: <common-dir>/info/craft-worktree  (link <glob> | copy <glob> | install | run <command>)
  install        the frozen install for the lockfile found: pnpm, npm, yarn, bun or uv
  run <command>  any other setup, run once per worktree with sh, in the worktree
Without that file the built-in list applies; it has no `install` line, so no dependencies are installed.
USAGE
}
# One list for every consumer: hooks.sh writes a repo's first craft-worktree from it, status.sh
# audits against it, and a repo with no craft-worktree is provisioned from it.
defaults() {
  cat <<'LIST'
link CLAUDE.local.md
link AGENTS.local.md
link .context
link .claude/skills/*
link .claude/agents/*
copy .claude/settings.local.json
copy .env
copy .env.*
copy .mcp.json
LIST
}
set -u
dry=0 all=0 instonly=0 detectonly=0 n=0
for a; do
  case $a in
    --help|-h) usage; exit 0 ;;
    --dry-run) dry=1 ;;
    --all) all=1 ;;
    --install-only) instonly=1 ;;
    --defaults) defaults; exit 0 ;;
    --detect) detectonly=1 ;;
    -*) echo "fail option $a unknown" >&2; usage; exit 2 ;;
    *) n=$((n+1)) ;;
  esac
done
if [ "$all" = 0 ] && [ "$n" = 0 ]; then usage; exit 2; fi

# Which frozen install a checkout needs, from its lockfile; empty when none is known.
# Go and Rust need none: their module caches are shared by every worktree.
detect() { # $1 dir
  if [ -f "$1/pnpm-lock.yaml" ]; then echo pnpm
  elif [ -f "$1/package-lock.json" ]; then echo npm
  elif [ -f "$1/yarn.lock" ]; then echo yarn
  elif [ -f "$1/bun.lock" ] || [ -f "$1/bun.lockb" ]; then echo bun
  elif [ -f "$1/uv.lock" ]; then echo uv
  fi
}

if [ "$detectonly" = 1 ]; then for d; do case $d in -*) ;; *) detect "$d" ;; esac; done; exit 0; fi

common=$(git rev-parse --path-format=absolute --git-common-dir) || exit 1
conf="$common/info/craft-worktree"
main=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
[ -d "$main" ] && [ "$(git -C "$main" rev-parse --is-bare-repository)" = false ] || { echo "fail provision no main checkout" >&2; exit 1; }
say() { echo "$*" >&2; }
nl='
'

exclude() { # $1 rel path; slash-less, root-anchored so it also matches a symlink
  grep -qxF "/$1" "$common/info/exclude" 2>/dev/null && return 0
  if [ "$dry" = 1 ]; then say "would exclude $1 $common/info/exclude"; return 0; fi
  mkdir -p "$common/info"
  if [ -s "$common/info/exclude" ] && [ -n "$(tail -c1 "$common/info/exclude")" ]; then printf '\n' >> "$common/info/exclude"; fi
  printf '/%s\n' "$1" >> "$common/info/exclude"
}

parent_ok() { # refuse when any existing ancestor of $2 inside $1 is a symlink
  d=$(dirname "$2")
  while [ "$d" != . ]; do
    [ -L "$1/$d" ] && return 1
    d=$(dirname "$d")
  done
  return 0
}

place() { # $1 mode, $2 worktree, $3 rel
  src="$main/$3" dst="$2/$3"
  [ -e "$src" ] || [ -L "$src" ] || return 0
  if [ -e "$dst" ] || [ -L "$dst" ]; then return 0; fi
  if [ -n "$(git -C "$2" ls-files -- "$3" | head -n1)" ]; then say "skip $3 tracked"; return 0; fi
  parent_ok "$2" "$3" || { say "skip $3 a parent is a symlink"; return 0; }
  if [ "$dry" = 1 ]; then
    say "would $1 $3 $dst"
    exclude "$3"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  case $1 in
    link) ln -s "$src" "$dst" ;;
    copy) cp -Rp "$src" "$dst" ;;
  esac || { say "fail $1 $3 failed"; return 0; }
  say "wrote $1 $3"
  git -C "$2" check-ignore -q --no-index -- "$3" || exclude "$3"
}

installed() { # $1 dir, $2 package manager: the directory its install creates
  case $2 in uv) [ -d "$1/.venv" ] ;; *) [ -d "$1/node_modules" ] ;; esac
}

# A frozen-lockfile install fetches only what the main checkout already resolved
install() { # $1 worktree
  pm=$(detect "$1")
  [ -n "$pm" ] || return 0
  installed "$1" "$pm" && return 0
  if [ "$dry" = 1 ]; then say "would install deps $pm $1"; return 0; fi
  command -v "$pm" >/dev/null 2>&1 || { say "warn install $pm not on PATH; dependencies not installed in $1"; return 0; }
  case $pm in
    pnpm) (cd "$1" && pnpm install --frozen-lockfile --prefer-offline --ignore-scripts) ;;
    npm) (cd "$1" && npm ci --prefer-offline --ignore-scripts --no-audit --no-fund) ;;
    yarn) (cd "$1" && yarn install --frozen-lockfile --prefer-offline --ignore-scripts) ;;
    bun) (cd "$1" && bun install --frozen-lockfile --ignore-scripts) ;;
    uv) (cd "$1" && uv sync --frozen) ;;
  esac </dev/null >&2 || say "warn install dependency install failed in $1 (gates will fail until it runs)"
}

# `run` lines are the repo's own setup commands; a stamp in the worktree's git dir keeps a
# second provisioning of the same worktree from running them again.
run_lines() { # $1 worktree
  case "$nl$entries" in *"${nl}run "*) ;; *) return 0 ;; esac
  stamp=$(git -C "$1" rev-parse --path-format=absolute --git-dir 2>/dev/null)/craft-run-done
  [ -e "$stamp" ] && return 0
  ok=1
  while read -r mode cmd || [ -n "$mode" ]; do
    [ "$mode" = run ] && [ -n "$cmd" ] || continue
    if [ "$dry" = 1 ]; then say "would run $cmd"; continue; fi
    if (cd "$1" && sh -c "$cmd") </dev/null >&2; then say "wrote run $cmd"
    else say "warn run failed in $1: $cmd"; ok=0; fi
  done <<LIST
$entries
LIST
  if [ "$dry" = 0 ] && [ "$ok" = 1 ]; then : > "$stamp"; fi
}

provision() { # $1 worktree
  [ "$(cd "$1" 2>/dev/null && pwd -P)" = "$(cd "$main" && pwd -P)" ] && return 0
  [ -d "$1" ] || { say "skip $1 not a directory"; return 0; }
  if [ -f "$conf" ]; then entries=$(cat "$conf"); else entries=$(defaults); fi
  # the here-document keeps the loop in this shell, and the patterns unexpanded until used
  while read -r mode pat || [ -n "$mode" ]; do
    case $mode in link|copy) ;; *) continue ;; esac
    # expand the pattern against the main checkout (no glob → literal)
    for s in "$main"/$pat; do
      place "$mode" "$1" "${s#"$main"/}"
    done
  done <<LIST
$entries
LIST
  case "$nl$entries$nl" in *"${nl}install$nl"*) install "$1" ;; esac
  run_lines "$1"
  return 0
}

if [ "$all" = 1 ]; then
  git worktree list --porcelain | sed -n 's/^worktree //p' | while read -r w || [ -n "$w" ]; do
    [ -d "$w" ] || continue
    if [ "$instonly" = 1 ]; then
      [ "$(cd "$w" && pwd -P)" = "$(cd "$main" && pwd -P)" ] || install "$w"
    else provision "$w"; fi
  done
elif [ "$instonly" = 1 ]; then
  for w; do case $w in -*) ;; *) install "$w" ;; esac; done
else
  for w; do case $w in -*) ;; *) provision "$w" ;; esac; done
fi
exit 0
