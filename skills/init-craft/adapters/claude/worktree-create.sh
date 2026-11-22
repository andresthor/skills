#!/bin/sh
# init-craft v2
# Claude Code WorktreeCreate hook: decides WHERE a worktree goes; the repo decides WHAT goes into it.
#   where: $INIT_CRAFT_WORKTREE_ROOT/<main checkout path from $HOME>/<name>   (root default: ~/wt)
#   what:  <git-common-dir>/info/craft-worktree, applied by craft-provision (built-in list if absent)
# stdin: JSON with `name` and `cwd`. stdout: the worktree path, alone. Everything else goes to stderr.
# `name@ref` forks from <ref> when it resolves; otherwise the base is origin/HEAD, else HEAD.
# `base_ref` and `branch` are not in the documented input; they are honoured when a caller sends them.
# scripts/machine.sh --worktree-hook links this file into ~/.claude/hooks/ (never copy it: it finds
# provision.sh relative to its own real path).
set -u
say() { echo "worktree-create: $*" >&2; }
die() { say "$*"; exit 1; }

input=$(cat)
command -v node >/dev/null 2>&1 || die "node not on PATH (needed to read the hook input)"
# one value per line; a name or path with a newline in it is refused below
fields=$(printf '%s' "$input" | node -e '
let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
  let j = {}; try { j = JSON.parse(s); } catch {}
  const str = (v) => (typeof v === "string" && !v.includes("\n") ? v : "");
  for (const k of ["name", "cwd", "repo_root", "base_ref", "branch"]) console.log(str(j[k]));
});' 2>/dev/null) || die "cannot read the hook input"
field() { printf '%s\n' "$fields" | sed -n "$1p"; }
name=$(field 1)
cwd=$(field 2)
[ -n "$cwd" ] || cwd=$(field 3)
want_base=$(field 4)
branch=$(field 5)
[ -n "$name" ] || die "no name in the hook input"
[ -n "$cwd" ] || cwd=${CLAUDE_PROJECT_DIR:-$PWD}

common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "not a git repository: $cwd"
# Placement follows the main checkout, so a session started inside a worktree does not nest
main=$(git -C "$cwd" worktree list --porcelain | sed -n '1s/^worktree //p')
[ -d "$main" ] || die "no main checkout for $cwd"

base=''
case $name in
  *@*)
    ref=${name#*@}
    if git -C "$main" rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1; then
      base=$ref; name=${name%%@*}
    else say "base ref '$ref' not found: using the default base"; fi ;;
esac
# The name becomes one path segment under the root
case $name in ''|.|..|*/*) die "unusable worktree name: $name" ;; esac
[ -z "$want_base" ] || base=$want_base
if [ -z "$base" ]; then
  if git -C "$main" rev-parse --verify --quiet origin/HEAD >/dev/null 2>&1; then base=origin/HEAD; else base=HEAD; fi
fi

root=${INIT_CRAFT_WORKTREE_ROOT:-$HOME/wt}
case $main in
  "$HOME"/*) rel=${main#"$HOME"/} ;;
  # Outside $HOME: a separate namespace, so /opt/foo cannot collide with ~/opt/foo
  /*) rel=_abs/${main#/} ;;
  *) die "main checkout path is not absolute: $main" ;;
esac
dir=$root/$rel/$name

if [ -e "$dir" ]; then
  # Re-entering a worktree made earlier under the same name
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$dir exists and is not a worktree"
  say "reusing $dir"
else
  mkdir -p "$(dirname "$dir")" || die "cannot create $(dirname "$dir")"
  if [ -n "$branch" ] && git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add "$dir" "$branch" >&2 </dev/null || die "git worktree add failed"
  elif [ -n "$branch" ]; then
    git -C "$main" worktree add -b "$branch" "$dir" "$base" >&2 </dev/null || die "git worktree add failed"
  else
    # Detached: Claude Code never deletes the branch of a hook-made worktree, so none is created
    git -C "$main" worktree add --detach "$dir" "$base" >&2 </dev/null || die "git worktree add failed"
  fi
fi

# The repo's post-checkout hook has already provisioned when it is installed and core.hooksPath
# does not bypass it. Provisioning never replaces a path, so running it again only fills gaps.
prov=$common/hooks/craft-provision
if [ ! -x "$prov" ]; then
  self=$0; n=0
  while [ -L "$self" ] && [ "$n" -lt 20 ]; do
    l=$(readlink "$self")
    case $l in /*) self=$l ;; *) self=$(dirname "$self")/$l ;; esac
    n=$((n + 1))
  done
  prov=$(cd "$(dirname "$self")/../../scripts" 2>/dev/null && pwd -P)/provision.sh
fi
if [ -f "$prov" ]; then
  (cd "$dir" && sh "$prov" "$dir") </dev/null >&2 || say "provisioning failed; rerun: sh $prov $dir"
else
  say "no craft-provision found; the worktree has tracked files only"
fi

printf '%s\n' "$dir"
