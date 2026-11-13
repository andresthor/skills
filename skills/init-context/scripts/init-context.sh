#!/bin/sh
# init-context v1
# Scaffold a repo's .context/ workspace and the instruction files that point agents at it.
# Never overwrites or deletes anything; re-running is safe and only fills gaps.
set -eu

usage() {
  cat <<'EOF'
usage: init-context.sh [repo-root] [--name NAME] [--vault work|self|none] [--slug SLUG] [--dry-run]

  repo-root   default: git toplevel of the cwd, else the cwd
  --name      project name written into new instruction files (default: basename of repo-root)
  --vault     work: <vault>/work, projects/ -> projects/<slug>
              self: <vault>/self, projects/ -> plans/<slug>
              none: real directories inside .context/, no symlinks
              default: work under ~/corti or ~/projects/corti, self under ~/projects, else required
  --slug      vault folder name for projects/ and output/ (default: basename of repo-root)
  --dry-run   print what would change, change nothing

<vault> is $INIT_CONTEXT_VAULT, default ~/.vault. A missing vault falls back to real directories.

Output lines: <state> <what> <detail>, state = ok | would | wrote | skip | warn
EOF
}

ROOT="" NAME="" KIND="" SLUG="" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || { usage >&2; exit 2; }; NAME="$2"; shift 2 ;;
    --vault) [ $# -ge 2 ] || { usage >&2; exit 2; }; KIND="$2"; shift 2 ;;
    --slug) [ $# -ge 2 ] || { usage >&2; exit 2; }; SLUG="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }
ROOT=$(cd "$ROOT" && pwd -P)
SLUG=${SLUG:-$(basename "$ROOT")}
NAME=${NAME:-$(basename "$ROOT")}
VAULT_ROOT=${INIT_CONTEXT_VAULT:-$HOME/.vault}

# Physical paths, since ROOT is resolved with pwd -P
under() { [ -d "$1" ] && case "$ROOT/" in "$(cd "$1" && pwd -P)"/*) return 0 ;; esac; return 1; }
if [ -z "$KIND" ]; then
  # The work roots are tested first: one of them sits inside ~/projects
  if under "$HOME/corti" || under "$HOME/projects/corti"; then KIND=work
  elif under "$HOME/projects"; then KIND=self
  else echo "cannot tell work from self for $ROOT; pass --vault work|self|none" >&2; exit 2; fi
fi
case "$KIND" in
  work) PLANS=projects ;;
  self) PLANS=plans ;;
  none) PLANS="" ;;
  *) echo "unknown --vault: $KIND (expected work, self or none)" >&2; exit 2 ;;
esac
VAULT="$VAULT_ROOT/$KIND"

# Skill dir: resolve $0 through symlinks, then ..
self=$0
while [ -L "$self" ]; do
  d=$(cd "$(dirname "$self")" && pwd -P)
  l=$(readlink "$self")
  case "$l" in /*) self=$l ;; *) self="$d/$l" ;; esac
done
TEMPLATES="$(cd "$(dirname "$self")/../templates" && pwd -P)"
CTX="$ROOT/.context"

say() { printf '%s %s %s\n' "$1" "$2" "$3"; }
# act LABEL WHAT DETAIL CMD...: run CMD and report, or only report "would" on --dry-run
act() {
  _l=$1 _w=$2 _d=$3; shift 3
  if [ "$DRY" = 1 ]; then say would "$_w" "$_d"; else "$@"; say "$_l" "$_w" "$_d"; fi
}
dangling() { [ -L "$1" ] && [ ! -e "$1" ]; }

# render TEMPLATE: the template with {{name}} filled in
render() {
  _n=$(printf '%s' "$NAME" | sed 's/[&|\\]/\\&/g')
  sed "s|{{name}}|$_n|g" "$TEMPLATES/$1"
}
write_new() { render "$1" > "$2"; }
# append_body TEMPLATE FILE: add the template minus its H1, keeping what the file already holds
append_body() {
  if [ -s "$2" ] && [ -n "$(tail -c1 "$2")" ]; then printf '\n' >> "$2"; fi
  { [ ! -s "$2" ] || printf '\n'; render "$1" | sed '1{/^# /d;}' | sed '1{/^$/d;}'; } >> "$2"
}
append_line() {
  if [ -s "$2" ] && [ -n "$(tail -c1 "$2")" ]; then printf '\n' >> "$2"; fi
  { [ ! -s "$2" ] || printf '\n'; printf '%s\n' "$1"; } >> "$2"
}

say ok repo "$ROOT"
say ok name "$NAME"
if [ "$KIND" = none ]; then HAVE_VAULT=0; say ok vault "none: real directories in .context/"
elif [ -d "$VAULT" ]; then HAVE_VAULT=1; say ok vault "$VAULT"
else HAVE_VAULT=0; say warn "no vault" "($VAULT missing) using real directories in .context/"; fi

ensure_dir() { # $1 path, $2 label
  if [ -d "$1" ]; then say ok "$2" "exists"; else act wrote "$2" "mkdir" mkdir -p "$1"; fi
}

if dangling "$CTX"; then say warn .context "dangling symlink (left as is), nothing else done"; exit 0; fi
if [ -e "$CTX" ] && [ ! -d "$CTX" ]; then say warn .context "exists and is not a directory, nothing else done"; exit 0; fi
ensure_dir "$CTX" .context

# ---------- .context/{projects,output,research,notes} ----------

link() { # $1 name, $2 target
  name=$1 target=$2 path="$CTX/$1"
  if [ -L "$path" ]; then
    cur=$(readlink "$path")
    if [ "${cur%/}" = "${target%/}" ]; then say ok ".context/$name" "-> $cur"
    else say warn ".context/$name" "differs: -> $cur (expected $target, left as is)"; fi
  elif [ -e "$path" ]; then
    say skip ".context/$name" "exists and is not a symlink"
  else
    act wrote ".context/$name" "-> $target" ln -s "$target" "$path"
  fi
}

realdir() { # $1 name
  path="$CTX/$1"
  if [ -e "$path" ] || [ -L "$path" ]; then say ok ".context/$1" "exists"
  else act wrote ".context/$1" "mkdir" mkdir -p "$path"; fi
}

if [ "$HAVE_VAULT" = 1 ]; then
  ensure_dir "$VAULT/$PLANS/$SLUG" "vault/$PLANS/$SLUG"
  ensure_dir "$VAULT/output/$SLUG" "vault/output/$SLUG"
  link projects "$VAULT/$PLANS/$SLUG"
  link output   "$VAULT/output/$SLUG"
  # research and notes are shared across repos, so a missing one is not created here
  for n in research notes; do
    if [ -d "$VAULT/$n" ]; then link "$n" "$VAULT/$n"
    else say skip ".context/$n" "$VAULT/$n missing"; fi
  done
else
  for n in projects output research notes; do realdir "$n"; done
fi

# ---------- .context/{AGENTS,CLAUDE,HANDOFF}.md ----------

if dangling "$CTX/AGENTS.md"; then say warn ".context/AGENTS.md" "dangling symlink (left as is)"
elif [ -e "$CTX/AGENTS.md" ]; then say ok ".context/AGENTS.md" "exists"
else act wrote ".context/AGENTS.md" "from template" write_new context/AGENTS.md "$CTX/AGENTS.md"; fi

if [ -L "$CTX/CLAUDE.md" ]; then
  cur=$(readlink "$CTX/CLAUDE.md")
  if [ "$cur" = AGENTS.md ]; then say ok ".context/CLAUDE.md" "-> AGENTS.md"
  else say warn ".context/CLAUDE.md" "differs: -> $cur (expected AGENTS.md, left as is)"; fi
elif [ -e "$CTX/CLAUDE.md" ]; then
  say warn ".context/CLAUDE.md" "differs: regular file, not a symlink to AGENTS.md (left as is)"
else
  act wrote ".context/CLAUDE.md" "-> AGENTS.md" ln -s AGENTS.md "$CTX/CLAUDE.md"
fi

if dangling "$CTX/HANDOFF.md"; then say warn ".context/HANDOFF.md" "dangling symlink (left as is)"
elif [ -e "$CTX/HANDOFF.md" ]; then say ok ".context/HANDOFF.md" "exists"
else act wrote ".context/HANDOFF.md" "empty pointer" write_new context/HANDOFF.md "$CTX/HANDOFF.md"; fi

# ---------- root instruction files ----------

# ensure_file NAME TEMPLATE PATTERN HOW DETAIL
#   absent: write TEMPLATE. Present without PATTERN (a grep -E expression): HOW decides —
#   body = append the template minus its H1, line:<text> = append one line, warn = report only.
ensure_file() {
  _f=$1 _tpl=$2 _pat=$3 _how=$4 _detail=$5 _path="$ROOT/$1"
  if dangling "$_path"; then
    say warn "$_f" "dangling symlink (left as is)"
  elif [ ! -e "$_path" ]; then
    act wrote "$_f" "from template" write_new "$_tpl" "$_path"
  elif grep -qE -- "$_pat" "$_path"; then
    say ok "$_f" "$_detail"
  elif [ "$_how" = warn ]; then
    say warn "$_f" "missing: $_detail (left as is)"
  elif [ -L "$_path" ]; then
    say warn "$_f" "symlink, missing: $_detail (not written through)"
  else
    case "$_how" in
      body) act wrote "$_f" "appended: $_detail" append_body "$_tpl" "$_path" ;;
      line:*) act wrote "$_f" "appended: $_detail" append_line "${_how#line:}" "$_path" ;;
    esac
  fi
}

ensure_file AGENTS.local.md root/AGENTS.local.md '\.context/AGENTS\.md' body \
  "pointer to .context/AGENTS.md"
ensure_file CLAUDE.local.md root/CLAUDE.local.md '^@(\./)?AGENTS\.local\.md[[:space:]]*$' "line:@AGENTS.local.md" \
  "import of AGENTS.local.md"
ensure_file AGENTS.md root/AGENTS.md 'AGENTS\.local\.md' body \
  "instruction to read AGENTS.local.md"

# A CLAUDE.md that is AGENTS.md itself (symlink) already carries the instruction
if [ -e "$ROOT/CLAUDE.md" ] && [ -e "$ROOT/AGENTS.md" ] && [ "$ROOT/CLAUDE.md" -ef "$ROOT/AGENTS.md" ]; then
  say ok CLAUDE.md "same file as AGENTS.md"
else
  ensure_file CLAUDE.md root/CLAUDE.md '^@(\./)?AGENTS\.md[[:space:]]*$' warn \
    "import of AGENTS.md"
fi

# ---------- git excludes ----------

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  say skip exclude "not a git repo, no excludes written"
  exit 0
fi

# --git-path resolves the shared exclude file correctly inside worktrees
EXCLUDE=$(cd "$ROOT" && git rev-parse --path-format=absolute --git-path info/exclude)
[ "$DRY" = 1 ] || { mkdir -p "$(dirname "$EXCLUDE")"; [ -e "$EXCLUDE" ] || : > "$EXCLUDE"; }
for pat in /.context /CLAUDE.local.md /AGENTS.local.md; do
  if [ -e "$EXCLUDE" ] && grep -qxF -- "$pat" "$EXCLUDE"; then say ok exclude "$pat"
  elif [ "$DRY" = 1 ]; then say would exclude "$pat"
  else
    if [ -s "$EXCLUDE" ] && [ -n "$(tail -c1 "$EXCLUDE")" ]; then printf '\n' >> "$EXCLUDE"; fi
    printf '%s\n' "$pat" >> "$EXCLUDE"; say wrote exclude "$pat"
  fi
done

tracked=$(git -C "$ROOT" ls-files -- .context CLAUDE.local.md AGENTS.local.md 2>/dev/null | tr '\n' ' ')
[ -z "$tracked" ] || say warn tracked "exclude has no effect on: $tracked"
exit 0
