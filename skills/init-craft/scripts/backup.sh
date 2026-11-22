#!/bin/sh
# init-craft v2
# Archives the untracked agent layer of a repo before init-craft changes it.
usage() {
  cat <<'USAGE'
usage: backup.sh [repo]
Writes <backup-dir>/<repo>-<YYYYmmdd-HHMMSS>.tgz with (those that exist, symlinks kept,
never followed): .claude .pi CLAUDE.local.md AGENTS.local.md .context/AGENTS.md .context/CLAUDE.md,
each linked worktree's untracked .claude .pi CLAUDE.local.md AGENTS.local.md and stray root agents hooks skills
settings.json (under worktrees/<basename>/), <common>/info/exclude, <common>/hooks, plus git-state.txt (git config --local -l and
git status --porcelain --ignored per worktree).
<backup-dir> is $INIT_CRAFT_BACKUP_DIR, default ${XDG_STATE_HOME:-~/.local/state}/init-craft/backups.
USAGE
}
set -u
repo=.
for a; do
  case $a in
    --help|-h) usage; exit 0 ;;
    -*) echo "fail option $a unknown" >&2; usage >&2; exit 2 ;;
    *) repo=$a ;;
  esac
done
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "fail repo $repo is not a git repository"; exit 1; }
main=$(git -C "$repo" worktree list --porcelain | sed -n '1s/^worktree //p')
[ -d "$main" ] || { echo "fail repo no main checkout"; exit 1; }
name=$(basename "$main")
out=${INIT_CRAFT_BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/init-craft/backups}
ts=$(date +%Y%m%d-%H%M%S)
arc="$out/$name-$ts.tgz"
stage=$(mktemp -d "${TMPDIR:-/tmp}/init-craft-bk.XXXXXX") || { echo "fail backup mktemp"; exit 1; }
trap 'rm -rf "$stage"' EXIT
mkdir -p "$out" || { echo "fail backup cannot create $out"; exit 1; }

# stage tree: main-relative files under main/, git files under git/
mkdir -p "$stage/main" "$stage/git"
{
  echo "# git config --local -l"
  git -C "$main" config --local -l
  git -C "$main" worktree list --porcelain | sed -n 's/^worktree //p' | while read -r w; do
    echo; echo "# git -C $w status --porcelain --ignored"
    git -C "$w" status --porcelain --ignored 2>&1
  done
} > "$stage/git-state.txt" 2>&1

: > "$stage/list"
for p in .claude .pi CLAUDE.local.md AGENTS.local.md .context/AGENTS.md .context/CLAUDE.md; do
  if [ -e "$main/$p" ] || [ -L "$main/$p" ]; then echo "$p" >> "$stage/list"; fi
done
# copy with cp -RP (symlinks preserved, never followed) into the stage tree
while read -r p; do
  mkdir -p "$stage/main/$(dirname "$p")"
  cp -RP "$main/$p" "$stage/main/$p"
done < "$stage/list"
# linked worktrees: only what git does not track (untracked or ignored), never .context
mkdir -p "$stage/worktrees"
git -C "$main" worktree list --porcelain | sed -n 's/^worktree //p' | sed 1d | while read -r w || [ -n "$w" ]; do
  [ -d "$w" ] || continue
  for p in .claude .pi CLAUDE.local.md AGENTS.local.md agents hooks skills settings.json; do
    { [ -e "$w/$p" ] || [ -L "$w/$p" ]; } || continue
    [ -n "$(git -C "$w" status --porcelain --ignored -- "$p" 2>/dev/null)" ] || continue
    mkdir -p "$stage/worktrees/$(basename "$w")"
    cp -RP "$w/$p" "$stage/worktrees/$(basename "$w")/$p"
  done
done
[ -e "$common/info/exclude" ] && { mkdir -p "$stage/git/info"; cp -P "$common/info/exclude" "$stage/git/info/exclude"; }
[ -d "$common/hooks" ] && cp -RP "$common/hooks" "$stage/git/hooks"
tar -czf "$arc" -C "$stage" git-state.txt main git worktrees || { echo "fail backup tar failed"; exit 1; }
n=$(tar -tzf "$arc" | wc -l | tr -d ' ') || { echo "fail backup unreadable $arc"; exit 1; }
echo "wrote backup $arc"
echo "ok backup $n entries (main/ = checkout files, git/ = info/exclude + hooks, git-state.txt)"
