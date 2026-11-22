#!/bin/sh
# init-craft v2
# Installs the init-craft git hooks into <common>/hooks and writes the default info/craft-worktree.
usage() {
  cat >&2 <<'USAGE'
usage: hooks.sh [--dry-run] [--force] [repo]
Installs pre-commit, commit-msg, post-checkout and craft-provision into <git-common-dir>/hooks,
writes <common>/info/craft-worktree if absent, unsets core.hooksPath if it is bin/hooks.
A differing hook is replaced only when it carries an older '# init-craft vN' marker; any other
differing hook is kept (warn) unless --force (then saved as <name>.pre-init-craft). Output on stderr: <state> <what> <detail>.
USAGE
}
set -u
dry=0 force=0 repo=.
for a; do
  case $a in
    --help|-h) usage; exit 0 ;;
    --dry-run) dry=1 ;;
    --force) force=1 ;;
    -*) echo "fail option $a unknown" >&2; usage; exit 2 ;;
    *) repo=$a ;;
  esac
done
say() { echo "$*" >&2; }
self=$0
while [ -L "$self" ]; do
  l=$(readlink "$self")
  case $l in /*) self=$l ;; *) self=$(dirname "$self")/$l ;; esac
done
skill=$(cd "$(dirname "$self")/.." && pwd -P)
tpl="$skill/templates/hooks"

common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { say "fail repo $repo is not a git repository"; exit 1; }
main=$(git -C "$repo" worktree list --porcelain | sed -n '1s/^worktree //p')
[ -d "$main" ] || { say "fail repo no main checkout (bare?)"; exit 1; }
hooks="$common/hooks"
rc=0

install_file() { # $1 source, $2 name in hooks dir
  src=$1 dst="$hooks/$2"
  [ -f "$src" ] || { say "fail $2 missing template $src"; rc=1; return; }
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then say "ok $2 $dst"; return; fi
  if [ -e "$dst" ]; then
    dv=$(sed -n 's/^# init-craft v\([0-9][0-9]*\).*/\1/p' "$dst" | sed -n 1p)
    sv=$(sed -n 's/^# init-craft v\([0-9][0-9]*\).*/\1/p' "$src" | sed -n 1p)
    # marked with an older version: safe to upgrade without asking
    if grep -q '# init-craft' "$dst" && [ "${dv:-0}" -lt "${sv:-0}" ]; then :
    else
    if [ "$force" = 0 ]; then say "warn $2 differs from the template (use --force; $dst)"; return; fi
    if [ "$dry" = 1 ]; then say "would backup $2 $dst.pre-init-craft"
    else cp -p "$dst" "$dst.pre-init-craft" || { say "fail $2 backup failed"; rc=1; return; }; fi
    fi
  fi
  if [ "$dry" = 1 ]; then say "would write $2 $dst"; return; fi
  mkdir -p "$hooks"
  cp "$src" "$dst.tmp.$$" && chmod +x "$dst.tmp.$$" && mv "$dst.tmp.$$" "$dst" \
    && say "wrote $2 $dst" || { rm -f "$dst.tmp.$$"; say "fail $2 write failed"; rc=1; }
}

install_file "$tpl/delegate" pre-commit
install_file "$tpl/delegate" commit-msg
install_file "$tpl/post-checkout" post-checkout
install_file "$skill/scripts/provision.sh" craft-provision

# default craft-worktree
conf="$common/info/craft-worktree"
if [ -e "$conf" ]; then
  say "ok craft-worktree $conf"
else
  tmp=$(mktemp "${TMPDIR:-/tmp}/craft-wt.XXXXXX") || { say "fail craft-worktree mktemp"; exit 1; }
  echo "# init-craft: worktree layer (link <glob> | copy <glob> | install | run <command>)" > "$tmp"
  # keep only the built-in entries that match something in the main checkout
  sh "$skill/scripts/provision.sh" --defaults | while read -r mode pat; do
    for s in "$main"/$pat; do
      if [ -e "$s" ] || [ -L "$s" ]; then echo "$mode $pat" >> "$tmp"; break; fi
    done
  done
  [ -n "$(sh "$skill/scripts/provision.sh" --detect "$main")" ] && echo install >> "$tmp"
  if [ "$dry" = 1 ]; then say "would write craft-worktree $conf"
  else
    mkdir -p "$common/info" && cp "$tmp" "$conf" && say "wrote craft-worktree $conf" \
      || { say "fail craft-worktree write failed"; rc=1; }
  fi
  rm -f "$tmp"
fi

# core.hooksPath
hp=$(git -C "$main" config --local core.hooksPath 2>/dev/null || true)
if [ -z "$hp" ]; then say "ok hooksPath unset"
elif [ "$hp" = bin/hooks ]; then
  if [ "$dry" = 1 ]; then say "would unset core.hooksPath (was bin/hooks)"
  else git -C "$main" config --local --unset core.hooksPath && say "wrote hooksPath unset (was bin/hooks)" || { say "fail hooksPath unset failed"; rc=1; }; fi
else say "warn hooksPath set to $hp (git ignores .git/hooks while it is set)"
fi
exit $rc
