#!/bin/sh
# init-craft v2
# status.sh [repo] — read-only audit: coverage table (concept x tool) + check lines.
# Never writes anything. Exit 1 on any cell ✗ or `fail` line.
#   status.sh            audit the repo containing the cwd
#   status.sh <repo>     audit that repo
# Env: INIT_CRAFT_PI_PROFILES  colon-separated extra Pi profile dirs (~/.pi/agent is always checked)
#      INIT_CRAFT_GLOBAL_INSTRUCTIONS  the one global instructions file (default ~/.agents/AGENTS.md)
#      INIT_CRAFT_PI_READS_CLAUDE_AGENTS  set to 1 when a Pi extension loads .claude/agents
#      INIT_CRAFT_OPENCODE_VERSION  opencode version override; otherwise read from the last
#      "cli starting version=" line of opencode's log (running opencode would append to it)

case ${1-} in
  -h|--help)
    sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac

EXPECT_VER=2
nl='
'
tab=$(printf '\t')
FAILS=0

# ---------- helpers ----------

physical() { # resolve symlinks (any depth) and print the physical path; nonexistent leaf allowed
  p=$1; n=0
  while [ -L "$p" ] && [ "$n" -lt 20 ]; do
    t=$(readlink "$p")
    case $t in /*) p=$t ;; *) p=$(dirname "$p")/$t ;; esac
    n=$((n + 1))
  done
  if [ -d "$p" ]; then
    (cd -P "$p" 2>/dev/null && pwd)
  else
    d=$(cd -P "$(dirname "$p")" 2>/dev/null && pwd) || return 1
    printf '%s/%s\n' "$d" "$(basename "$p")"
  fi
}

xp() { # expand <global>, leading ~/ and <profile>
  case $1 in
    "<global>") printf '%s' "$CANON" ;;
    "~/"*) printf '%s' "$HOME/${1#"~/"}" ;;
    "<profile>"*) printf '%s' "$CUR_PROFILE${1#"<profile>"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

short() { case $1 in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }

emit() { # state check detail
  case $1 in fail) FAILS=$((FAILS + 1)) ;; esac
  printf '%s %s %s\n' "$1" "$2" "$3"
}

join() { # newline list -> ", " list
  printf '%s' "$1" | sed '/^$/d' | tr '\n' ',' | sed 's/,$//; s/,/, /g'
}

tracked() { # $1 dir $2 rel : any tracked file at/below rel
  [ -n "$(git -C "$1" ls-files -- "$2" 2>/dev/null | head -n 1)" ]
}

has_entries() { # $1 dir: dir with at least one entry
  for e in "$1"/*; do [ -e "$e" ] || [ -L "$e" ] && return 0; done
  return 1
}

json_has() { # file key value  (node reads JSON; contents are never printed)
  [ -f "$1" ] || return 1
  command -v node >/dev/null 2>&1 || return 1
  node -e "$JSON_HAS_JS" "$1" "$2" "$3" 2>/dev/null
}
JSON_HAS_JS=$(cat <<'EOF'
const fs = require("fs");
const [file, key, val] = process.argv.slice(1);
const j = JSON.parse(fs.readFileSync(file, "utf8"));
const v = j[key];
process.exit(Array.isArray(v) && v.includes(val) ? 0 : 1);
EOF
)

json_scalar() { # file key -> prints value of a top-level scalar key (empty if absent)
  [ -f "$1" ] || return 0
  node -e "$JSON_SCALAR_JS" "$1" "$2" 2>/dev/null
}
JSON_SCALAR_JS=$(cat <<'EOF'
const fs = require("fs");
const [file, key] = process.argv.slice(1);
try {
  const v = JSON.parse(fs.readFileSync(file, "utf8"))[key];
  if (typeof v === "string" || typeof v === "number" || typeof v === "boolean") console.log(String(v));
} catch {}
EOF
)

TRUST_JS=$(cat <<'EOF'
// exit 0 when the path or an ancestor is saved as trusted (value true)
const fs = require("fs");
const [file, ...paths] = process.argv.slice(1);
const j = JSON.parse(fs.readFileSync(file, "utf8"));
for (let p of paths) for (;;) {
  if (j[p] === true) process.exit(0);
  const up = require("path").dirname(p);
  if (up === p) break;
  p = up;
}
process.exit(1);
EOF
)

HOOK_JS=$(cat <<'EOF'
// prints "registered" when hooks.WorktreeCreate runs the given command, "other" when it runs something else
const fs = require("fs");
const [file, command] = process.argv.slice(1);
try {
  const cur = JSON.parse(fs.readFileSync(file, "utf8")).hooks?.WorktreeCreate;
  const cmds = (Array.isArray(cur) ? cur : []).flatMap((g) => (Array.isArray(g?.hooks) ? g.hooks : [])).map((h) => h?.command);
  if (cmds.includes(command)) console.log("registered"); else if (cmds.length) console.log("other");
} catch {}
EOF
)

# ---------- locate things ----------

SELF=$0
n=0
while [ -L "$SELF" ] && [ "$n" -lt 20 ]; do
  t=$(readlink "$SELF")
  case $t in /*) SELF=$t ;; *) SELF=$(dirname "$SELF")/$t ;; esac
  n=$((n + 1))
done
SKILL=$(cd -P "$(dirname "$SELF")/.." && pwd)
COVERAGE=$SKILL/coverage.tsv
ADAPTER=$SKILL/adapters/pi/claude-compat.ts
CANON=${INIT_CRAFT_GLOBAL_INSTRUCTIONS:-$HOME/.agents/AGENTS.md}
[ -f "$COVERAGE" ] || { echo "fail coverage missing $COVERAGE"; exit 1; }

target=${1:-.}
repo=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null) || { echo "fail repo not a git repository: $target"; exit 1; }
repo=$(cd -P "$repo" && pwd)
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "fail git needs >= 2.31 (rev-parse --path-format)"; exit 1; }
wtlist=$(git -C "$repo" worktree list --porcelain 2>/dev/null)
main=$(printf '%s\n' "$wtlist" | sed -n '1s/^worktree //p')
[ -n "$main" ] || main=$repo

# worktree paths (all) and prunable paths
WT_ALL=''
WT_PRUNABLE=''
cur=''
IFS=$nl
set -f
for line in $wtlist; do
  case $line in
    "worktree "*) cur=${line#worktree }; WT_ALL=$WT_ALL$cur$nl ;;
    prunable*) WT_PRUNABLE=$WT_PRUNABLE$cur$nl ;;
  esac
done
set +f
unset IFS

# Pi profiles
PROFILES=''
add_profile() {
  [ -d "$1" ] || return 0
  pp=$(physical "$1") || return 0
  case "$nl$PROFILES" in *"$nl$pp$nl"*) return 0 ;; esac
  PROFILES=$PROFILES$pp$nl
}
add_profile "$HOME/.pi/agent"
extra=${INIT_CRAFT_PI_PROFILES-}
IFS=:
set -f
for d in $extra; do [ -n "$d" ] && add_profile "$d"; done
set +f
unset IFS

profile_label() {
  b=$(basename "$1")
  if [ "$b" = agent ]; then
    par=$(basename "$(dirname "$1")")
    [ "$par" = .pi ] || b=$par
  fi
  printf '%s' "$b"
}

HOOKS_PATH=$(git -C "$repo" config --get core.hooksPath 2>/dev/null)
CHECKS=$(awk -F'\t' 'NR > 1 { print $1 "|" $3 "|" $5 }' "$COVERAGE")
HAVE_OC=0
command -v opencode >/dev/null 2>&1 && HAVE_OC=1
OC_VER=''
if [ "$HAVE_OC" = 1 ]; then
  if [ -n "${INIT_CRAFT_OPENCODE_VERSION-}" ]; then OC_VER=$INIT_CRAFT_OPENCODE_VERSION
  elif [ -f "$HOME/.local/share/opencode/log/opencode.log" ]; then
    OC_VER=$(grep 'message="cli starting" version=' "$HOME/.local/share/opencode/log/opencode.log" 2>/dev/null | tail -n 1 | sed -n 's/.* version=\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
  fi
fi

version_ge() { # $1 >= $2 (dotted numeric)
  [ -n "$1" ] || return 1
  a1=${1%%.*}; r=${1#*.}; a2=${r%%.*}; a3=${r#*.}; a3=${a3%%[!0-9]*}
  b1=${2%%.*}; r=${2#*.}; b2=${r%%.*}; b3=${r#*.}; b3=${b3%%[!0-9]*}
  [ "${a1:-0}" -gt "$b1" ] && return 0; [ "${a1:-0}" -lt "$b1" ] && return 1
  [ "${a2:-0}" -gt "$b2" ] && return 0; [ "${a2:-0}" -lt "$b2" ] && return 1
  [ "${a3:-0}" -ge "$b3" ]
}

# ---------- coverage checks (return 0 ok, 1 fail, 2 n/a, 3 none, 4 unknown) ----------

chk_none() { return 3; }

chk_native() {
  case $CUR_CONCEPT in
    repo-instructions) tracked "$repo" AGENTS.md || return 2 ;;
    repo-skills) has_entries "$repo/.claude/skills" || return 2 ;;
    review-agent) has_entries "$repo/.claude/agents" || return 2 ;;
  esac
  return 0
}

chk_link_to() { # link target
  [ -e "$2" ] || return 2 # no canonical file: the concept is not in use
  [ -L "$1" ] && [ -e "$1" ] || return 1
  [ "$(physical "$1")" = "$(physical "$2")" ]
}

chk_json_list_has() { json_has "$1" "$2" "$3"; }

chk_min_version() { # tool version
  if [ "$1" = opencode ]; then
    v=$OC_VER
    [ -n "$v" ] || return 4 # unknown without running opencode
  else
    command -v "$1" >/dev/null 2>&1 || return 1
    v=$("$1" --version 2>/dev/null | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)
  fi
  version_ge "$v" "$2"
}

chk_adapter_linked() { # profile dir
  l=$1/extensions/claude-compat.ts
  [ -L "$l" ] && [ -e "$l" ] || return 1
  [ "$(physical "$l")" = "$(physical "$ADAPTER")" ]
}

chk_file_excluded() { # rel path in repo
  [ -e "$repo/$1" ] || [ -L "$repo/$1" ] || return 2
  git -C "$repo" check-ignore -q --no-index -- "$1"
}

chk_git_hook_installed() { # hook names; shims live in <common>/hooks and only run when core.hooksPath is unset
  tracked "$repo" bin/hooks/pre-commit || tracked "$repo" bin/hooks/commit-msg || return 2 # no gate to run
  [ -z "$HOOKS_PATH" ] || return 1
  for h in "$@"; do
    [ -f "$common/hooks/$h" ] && [ -x "$common/hooks/$h" ] || return 1
  done
  return 0
}

chk_craft_worktree_present() { [ -f "$common/info/craft-worktree" ]; }

# Pi has no agent loader of its own; an extension that reads .claude/agents is declared by the user.
chk_pi_agents() {
  has_entries "$repo/.claude/agents" || return 2
  has_entries "$repo/.pi/agents" && return 0
  [ "${INIT_CRAFT_PI_READS_CLAUDE_AGENTS-}" = 1 ] || return 3
}

pointer_in() { [ -f "$1" ] && grep -Eq '(^|[^@])\.context/AGENTS\.md' "$1"; }

# The local text reaches a tool that only reads AGENTS.md when that file sends it to AGENTS.local.md.
agents_local_wired() {
  [ -f "$repo/AGENTS.local.md" ] && [ -f "$repo/AGENTS.md" ] && grep -q 'AGENTS\.local\.md' "$repo/AGENTS.md"
}

chk_local_instructions() { # tool [profile]
  [ -e "$repo/CLAUDE.local.md" ] || [ -e "$repo/AGENTS.local.md" ] || return 2
  case $1 in
    claude)
      [ -e "$repo/CLAUDE.local.md" ] || return 1
      git -C "$repo" check-ignore -q --no-index -- CLAUDE.local.md ;;
    opencode)
      agents_local_wired && return 0
      chk_json_list_has "$HOME/.config/opencode/opencode.json" instructions CLAUDE.local.md && chk_min_version opencode 2.1.0 ;;
    pi)
      agents_local_wired && return 0
      [ -e "$repo/CLAUDE.local.md" ] && chk_adapter_linked "$2" ;;
  esac
}

chk_context_present() {
  [ -d "$repo/.context" ] || return 1
  pointer_in "$repo/AGENTS.local.md" || pointer_in "$repo/CLAUDE.local.md"
}

run_check() { # $1 check string
  rest=$1
  while [ -n "$rest" ]; do
    case $rest in
      *' && '*) seg=${rest%%' && '*}; rest=${rest#*' && '} ;;
      *) seg=$rest; rest='' ;;
    esac
    set -f
    # shellcheck disable=SC2086
    set -- $seg
    set +f
    case $1 in
      link-to) fn=link_to ;; json-list-has) fn=json_list_has ;; min-version) fn=min_version ;;
      adapter-linked) fn=adapter_linked ;; file-excluded) fn=file_excluded ;;
      git-hook-installed) fn=git_hook_installed ;; craft-worktree-present) fn=craft_worktree_present ;;
      context-present) fn=context_present ;; pi-agents) fn=pi_agents ;; local-instructions) fn=local_instructions ;;
      native) fn=native ;; none) fn=none ;;
      *) return 1 ;;
    esac
    shift
    cnt=$#; i=0
    while [ "$i" -lt "$cnt" ]; do
      a=$(xp "$1"); shift
      set -- "$@" "$a"
      i=$((i + 1))
    done
    "chk_$fn" "$@"
    rc=$?
    [ "$rc" -eq 0 ] || return "$rc"
  done
  return 0
}

cell() { # concept tool profile -> prints symbol
  unset IFS; set +f
  CUR_CONCEPT=$1; CUR_PROFILE=$3
  chk=''
  IFS=$nl; set -f
  for row in $CHECKS; do
    case $row in "$1|$2|"*) chk=${row#*|*|}; break ;; esac
  done
  unset IFS; set +f
  [ -n "$chk" ] || { printf '%s' '-'; return; }
  if [ "$2" = opencode ] && [ "$HAVE_OC" = 0 ]; then printf '%s' none; return; fi
  run_check "$chk"
  case $? in
    0) printf '%s' '✓' ;;
    2) printf '%s' '-' ;;
    3) printf '%s' none ;;
    4) printf '%s' '?' ;;
    *) printf '%s' '✗' ;;
  esac
}

vlen() { case $1 in '✓'|'✗') echo 1 ;; *) printf '%s' "$1" | wc -c | tr -d ' ' ;; esac; }

pad() { # text width
  l=$(vlen "$1")
  printf '%s' "$1"
  while [ "$l" -lt "$2" ]; do printf ' '; l=$((l + 1)); done
}

print_table() {
  cols="claude|claude|$nl""opencode|opencode|$nl"
  IFS=$nl
  set -f
  for p in $PROFILES; do cols=$cols"pi:$(profile_label "$p")|pi|$p$nl"; done
  set +f
  unset IFS
  concepts=$(awk -F'\t' 'NR > 1 && !s[$1]++ { print $1 }' "$COVERAGE")
  pad concept 20
  IFS=$nl; set -f
  for c in $cols; do lab=${c%%|*}; w=$(vlen "$lab"); pad "$lab" $((w + 2)); done
  printf '\n'
  for k in $concepts; do
    pad "$k" 20
    for c in $cols; do
      lab=${c%%|*}; r=${c#*|}; tool=${r%%|*}; prof=${r#*|}
      sym=$(cell "$k" "$tool" "$prof")
      [ "$sym" = '✗' ] && CELLFAIL=1
      pad "$sym" $(($(vlen "$lab") + 2))
    done
    printf '\n'
  done
  set +f; unset IFS
}

CELLFAIL=0
printf 'init-craft status: %s\n' "$(short "$repo")"
# The table loop runs in the main shell so CELLFAIL propagates.
print_table
printf '\n'
[ "$CELLFAIL" = 1 ] && FAILS=$((FAILS + 1))

# ---------- check lines ----------

# 2. instructions
if [ -e "$CANON" ]; then emit ok global-instructions "$(short "$CANON") present"
else emit ok global-instructions "no $(short "$CANON") (optional: one global instructions file linked into every tool)"; fi

if [ "$HAVE_OC" = 1 ]; then
  if [ -n "$OC_VER" ]; then emit ok opencode "version $OC_VER"
  else emit warn opencode "version unknown (no opencode log; set INIT_CRAFT_OPENCODE_VERSION)"; fi
fi

CL=$repo/CLAUDE.local.md
AL=$repo/AGENTS.local.md
if [ ! -f "$CL" ]; then
  emit warn instructions "CLAUDE.local.md missing; fix: the init-context skill"
else
  if git -C "$repo" check-ignore -q --no-index -- CLAUDE.local.md; then emit ok instructions "CLAUDE.local.md present and ignored"
  else emit warn instructions "CLAUDE.local.md not excluded (would show in git status)"; fi
  if [ -f "$AL" ]; then
    if grep -Eq '^@(\./)?AGENTS\.local\.md[[:space:]]*$' "$CL"; then emit ok instructions "CLAUDE.local.md imports AGENTS.local.md"
    else emit warn instructions "CLAUDE.local.md does not import AGENTS.local.md (Claude Code never reads that file itself)"; fi
    if git -C "$repo" check-ignore -q --no-index -- AGENTS.local.md; then emit ok instructions "AGENTS.local.md present and ignored"
    else emit warn instructions "AGENTS.local.md not excluded (would show in git status)"; fi
    if agents_local_wired; then emit ok instructions "AGENTS.md sends other agents to AGENTS.local.md"
    else emit warn instructions "AGENTS.md does not mention AGENTS.local.md (agents other than Claude Code will not read it)"; fi
  else
    emit ok instructions "no AGENTS.local.md (CLAUDE.local.md only: other tools need the Pi adapter or OpenCode's instructions entry)"
  fi
  if pointer_in "$AL" || pointer_in "$CL"; then emit ok instructions "local instructions point at .context/AGENTS.md in plain text"
  elif grep -q '@\.context/AGENTS\.md' "$CL"; then emit warn instructions "CLAUDE.local.md only has @.context/AGENTS.md (only Claude Code expands @ imports); add a plain-text pointer"
  else emit warn instructions "local instructions have no pointer to .context/AGENTS.md"; fi
fi
if tracked "$repo" AGENTS.md; then emit ok instructions "tracked AGENTS.md present"
else emit ok instructions "no tracked AGENTS.md (optional)"; fi

# 3. skills / agents
dangling=''
for root in .claude .pi .agents; do
  [ -d "$repo/$root" ] || continue
  found=$(find "$repo/$root" -type l 2>/dev/null)
  IFS=$nl; set -f
  for l in $found; do
    [ -e "$l" ] || dangling=$dangling${l#"$repo"/}$nl
  done
  set +f; unset IFS
done
if [ -n "$dangling" ]; then emit fail skills "dangling symlink(s): $(join "$dangling")"
else emit ok skills "no dangling symlinks under .claude .pi .agents"; fi

names() { # $1 skills dir -> entry names
  for e in "$1"/*; do [ -e "$e" ] || [ -L "$e" ] || continue; basename "$e"; done
}
cn=$(names "$repo/.claude/skills"); pn=$(names "$repo/.pi/skills"); an=$(names "$repo/.agents/skills")
coll=''
IFS=$nl; set -f
for nm in $cn; do
  w=''
  case "$nl$pn$nl" in *"$nl$nm$nl"*) w=$w' .pi/skills' ;; esac
  case "$nl$an$nl" in *"$nl$nm$nl"*) w=$w' .agents/skills' ;; esac
  [ -n "$w" ] && coll=$coll"$nm (also in$w)$nl"
done
for nm in $pn; do
  case "$nl$an$nl" in *"$nl$nm$nl"*) coll=$coll"$nm (in .pi/skills and .agents/skills)$nl" ;; esac
done
set +f; unset IFS
if [ -n "$coll" ]; then emit fail skills "name collision: $(join "$coll")"
else emit ok skills "no skill-name collisions across .claude/.pi/.agents"; fi

if has_entries "$repo/.claude/agents"; then
  if has_entries "$repo/.pi/agents"; then emit ok agents ".claude/agents visible to Pi through .pi/agents"
  elif [ "${INIT_CRAFT_PI_READS_CLAUDE_AGENTS-}" = 1 ]; then emit ok agents "a Pi extension reads .claude/agents (INIT_CRAFT_PI_READS_CLAUDE_AGENTS=1)"
  else emit ok agents ".claude/agents is for Claude Code only (Pi and OpenCode have no loader for it)"; fi
else
  emit ok agents "no .claude/agents in repo"
fi

# 4. hooks
hp=$HOOKS_PATH
if [ -n "$hp" ]; then emit fail hooks "core.hooksPath=$hp (bypasses $(short "$common")/hooks shims); fix: hooks.sh"
else emit ok hooks "core.hooksPath unset"; fi
if [ -f "$repo/package.json" ] && command -v node >/dev/null 2>&1; then
  prep=$(node -e 'try{const s=require(require("path").resolve(process.argv[1])).scripts||{};console.log([s.prepare,s.postinstall,s.prepublish].filter(Boolean).join(" ; "))}catch{}' "$repo/package.json" 2>/dev/null)
  case $prep in
    *hooksPath*) emit fail hooks "package.json prepare sets core.hooksPath (re-set on every install): $prep" ;;
    *) emit ok hooks "package.json prepare does not set core.hooksPath" ;;
  esac
fi
for h in pre-commit commit-msg post-checkout craft-provision; do
  f=$common/hooks/$h
  if [ ! -f "$f" ]; then emit fail hooks "$h missing in $(short "$common")/hooks"; continue; fi
  m=$(sed -n 2p "$f")
  case $m in
    "# init-craft v"*|"# craft-provision v"*)
      v=${m##* v}
      if [ "$v" = "$EXPECT_VER" ]; then emit ok hooks "$h installed (marker v$v)"
      else emit warn hooks "$h marker v$v, skill expects v$EXPECT_VER; rerun hooks.sh" ; fi ;;
    *) emit warn hooks "$h present without init-craft marker (not managed)" ;;
  esac
done

# 5. gates
pc=bin/hooks/pre-commit
if tracked "$repo" "$pc"; then
  # a gate is whatever the repo runs; only an empty one is wrong
  if grep -Ev '^[[:space:]]*(#|$)' "$repo/$pc" 2>/dev/null | grep -q .; then emit ok gates "tracked $pc"
  else emit fail gates "$pc has no commands"; fi
  if [ -f "$repo/tsconfig.json" ]; then
    if grep -Eq 'typecheck|tsc' "$repo/$pc"; then emit ok gates "$pc runs typecheck"
    else emit warn gates "$pc does not run typecheck/tsc in a TypeScript repo"; fi
  fi
else
  emit warn gates "no tracked $pc: commits in this repo are not checked"
fi
if tracked "$repo" bin/hooks/commit-msg; then emit ok gates "tracked bin/hooks/commit-msg"
elif tracked "$repo" bin/commit-msg; then emit ok gates "tracked bin/commit-msg (move to bin/hooks/commit-msg)"
else emit ok gates "no tracked commit-msg hook (optional: only for a repo that checks messages)"; fi

# 6/7. worktrees + excludes
conf=$common/info/craft-worktree
if [ -f "$conf" ]; then
  conf_lines=$(sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$conf" | sed '/^$/d')
  emit ok worktrees "info/craft-worktree present ($(printf '%s\n' "$conf_lines" | wc -l | tr -d ' ') entries)"
else
  conf_lines=$(sh "$SKILL/scripts/provision.sh" --defaults)
  emit warn worktrees "no info/craft-worktree; checking the built-in entries"
fi

ENTRIES=''
IFS=$nl; set -f
for ln in $conf_lines; do
  mode=${ln%% *}; arg=${ln#* }
  case $mode in link|copy) ;; *) continue ;; esac
  set +f
  found=$(cd "$main" 2>/dev/null && for p in $arg; do { [ -e "$p" ] || [ -L "$p" ]; } && printf '%s %s\n' "$mode" "$p"; done)
  set -f
  for fl in $found; do
    rel=${fl#* }
    tracked "$main" "$rel" || ENTRIES=$ENTRIES$fl$nl
  done
done
set +f; unset IFS

# excludes in the main checkout
links_main=''
IFS=$nl; set -f
for fl in $ENTRIES; do links_main=$links_main${fl#* }$nl; done
unset IFS
notign=''
for rel in $links_main; do
  git -C "$main" check-ignore -q --no-index -- "$rel" || notign=$notign$rel$nl
done
set +f
if [ -n "$notign" ]; then emit warn excludes "not ignored in main checkout: $(join "$notign")"
else emit ok excludes "all linked/copied paths ignored in main checkout"; fi
slashy=''
if [ -f "$common/info/exclude" ]; then
  for rel in $links_main; do
    top=${rel%%/*}
    esc=$(printf '%s' "$top" | sed 's/[.[\*^$]/\\&/g')
    # a slash-less line also covers the path, so an extra legacy `name/` line is harmless
    grep -qxE "/?$esc" "$common/info/exclude" && continue
    if grep -qxE "/?$esc/" "$common/info/exclude"; then
      slashy=$slashy$top/$nl
    fi
  done
  slashy=$(printf '%s' "$slashy" | sort -u)
fi
if [ -n "$slashy" ]; then emit warn excludes "trailing-slash exclude does not match symlinks in worktrees: $(join "$slashy"); use slash-less /<name>"
else emit ok excludes "no trailing-slash excludes for linked paths"; fi

wt_short() { short "$1"; }

IFS=$nl; set -f
first=1
for wt in $WT_ALL; do
  if [ "$first" = 1 ]; then first=0; continue; fi
  nm=$(wt_short "$wt")
  case "$nl$WT_PRUNABLE" in *"$nl$wt$nl"*) emit warn worktrees "$nm prunable (missing dir); fix: git worktree prune"; continue ;; esac
  [ -d "$wt" ] || { emit warn worktrees "$nm directory missing"; continue; }
  missing=''; wrong=''; real=''; nsl=0; nok=0; symlinks=''
  for fl in $ENTRIES; do
    mode=${fl%% *}; rel=${fl#* }
    # skip entries below a symlinked parent (reported as whole-dir link below)
    d=$(dirname "$rel"); skip=0
    while [ "$d" != . ]; do [ -L "$wt/$d" ] && skip=1; d=$(dirname "$d"); done
    [ "$skip" = 1 ] && continue
    if [ "$mode" = link ]; then
      if [ -L "$wt/$rel" ]; then
        t=$(readlink "$wt/$rel")
        case $t in /*) ;; *) t=$(dirname "$wt/$rel")/$t ;; esac
        symlinks=$symlinks$rel$nl
        if [ -e "$wt/$rel" ] && [ "$(physical "$t")" = "$(physical "$main/$rel")" ]; then nok=$((nok + 1))
        else wrong=$wrong$rel$nl; fi
      elif [ -e "$wt/$rel" ]; then
        tracked "$wt" "$rel" && nok=$((nok + 1)) || real=$real$rel$nl
      else missing=$missing$rel$nl; fi
    else
      if [ -e "$wt/$rel" ] || [ -L "$wt/$rel" ]; then nok=$((nok + 1)); else missing=$missing$rel$nl; fi
    fi
  done
  msg=''
  [ -n "$missing" ] && msg="$msg missing: $(join "$missing");"
  [ -n "$wrong" ] && msg="$msg wrong target: $(join "$wrong");"
  [ -n "$real" ] && msg="$msg real copy instead of link: $(join "$real");"
  if [ -n "$msg" ]; then emit fail worktrees "$nm$msg"; else emit ok worktrees "$nm $nok entries present"; fi
  whole=''
  for w in .claude .pi .agents; do [ -L "$wt/$w" ] && whole="$whole $w"; done
  [ -n "$whole" ] && emit fail worktrees "$nm whole-dir symlink:$whole (replace by per-entry links)"
  stray=''
  for s in agents hooks skills settings.json; do
    if [ -e "$wt/$s" ] || [ -L "$wt/$s" ]; then tracked "$wt" "$s" || stray=$stray$s$nl; fi
  done
  [ -n "$stray" ] && emit warn worktrees "$nm stray untracked root files: $(join "$stray") (copies of .claude content?)"
  wpm=$(sh "$SKILL/scripts/provision.sh" --detect "$wt")
  case $wpm in '') depdir='' ;; uv) depdir=.venv ;; *) depdir=node_modules ;; esac
  if [ -n "$depdir" ] && [ ! -d "$wt/$depdir" ]; then emit warn worktrees "$nm $depdir missing; fix: provision.sh --install-only"; fi
  if [ -n "$symlinks" ]; then
    set +f
    # shellcheck disable=SC2086
    ign=$(IFS=$nl; set -f; git -C "$wt" check-ignore --no-index -- $symlinks 2>/dev/null)
    set -f
    ni=''
    for s in $symlinks; do
      case "$nl$ign$nl" in *"$nl$s$nl"*) ;; *) ni=$ni$s$nl ;; esac
    done
    [ -n "$ni" ] && emit warn excludes "$nm symlinks not ignored: $(join "$ni")"
  fi
done
set +f; unset IFS
[ -z "$WT_PRUNABLE" ] && emit ok worktrees "no prunable worktrees"

# 8. context
ctx=$repo/.context
if [ -d "$ctx" ]; then
  emit ok context ".context present"
  if [ -L "$ctx/CLAUDE.md" ]; then
    [ "$(readlink "$ctx/CLAUDE.md")" = AGENTS.md ] && emit ok context ".context/CLAUDE.md -> AGENTS.md" || emit warn context ".context/CLAUDE.md links to $(readlink "$ctx/CLAUDE.md"), expected AGENTS.md"
  elif [ -e "$ctx/CLAUDE.md" ]; then emit warn context ".context/CLAUDE.md is a regular file, expected symlink to AGENTS.md"
  else emit warn context ".context/CLAUDE.md missing"; fi
  [ -f "$ctx/AGENTS.md" ] || emit warn context ".context/AGENTS.md missing"
  bad=''; nlinks=0
  for e in "$ctx"/*; do
    [ -L "$e" ] || continue
    nlinks=$((nlinks + 1))
    [ -e "$e" ] || bad=$bad$(basename "$e")$nl
  done
  if [ -n "$bad" ]; then emit fail context "dangling vault link(s): $(join "$bad")"
  elif [ "$nlinks" -gt 0 ]; then emit ok context "$nlinks symlink(s) in .context resolve"
  else emit ok context "no vault links (real directories)"; fi
else
  emit warn context ".context missing; fix: the init-context skill"
fi

# 9. Pi trust (warn only)
has_proj=0
{ has_entries "$repo/.pi" || has_entries "$repo/.agents/skills"; } && has_proj=1
IFS=$nl; set -f
for p in $PROFILES; do
  lab=$(profile_label "$p")
  tv=$(json_scalar "$p/settings.json" defaultProjectTrust)
  covered=0
  [ -f "$p/trust.json" ] && node -e "$TRUST_JS" "$p/trust.json" "$repo" "$main" 2>/dev/null && covered=1
  if [ "$tv" = always ] || [ "$covered" = 1 ]; then emit ok pi-trust "$lab: project trust granted (${tv:-trust.json})"
  elif [ "$has_proj" = 1 ]; then emit warn pi-trust "$lab: defaultProjectTrust=${tv:-unset}; repo .pi/.agents resources need trust (adapter skills do not)"
  else emit ok pi-trust "$lab: defaultProjectTrust=${tv:-unset}; nothing in the repo needs trust"; fi
done
set +f; unset IFS

# 10. Claude Code WorktreeCreate hook (optional, per machine)
wtsrc=$SKILL/adapters/claude/worktree-create.sh
wtdst=$HOME/.claude/hooks/worktree-create/worktree-create.sh
reg=''
[ -f "$HOME/.claude/settings.json" ] && command -v node >/dev/null 2>&1 \
  && reg=$(node -e "$HOOK_JS" "$HOME/.claude/settings.json" '"$HOME/.claude/hooks/worktree-create/worktree-create.sh"' 2>/dev/null)
linked=0
[ -L "$wtdst" ] && [ -e "$wtdst" ] && [ "$(physical "$wtdst")" = "$(physical "$wtsrc")" ] && linked=1
case $reg:$linked in
  registered:1) emit ok claude-hook "WorktreeCreate hook installed (worktrees go under $(short "${INIT_CRAFT_WORKTREE_ROOT:-$HOME/wt}"))" ;;
  registered:0) emit warn claude-hook "settings.json runs $(short "$wtdst"), which is not this skill's hook; fix: machine.sh --worktree-hook" ;;
  other:*) emit warn claude-hook "hooks.WorktreeCreate runs another command; that command alone decides what a new worktree gets" ;;
  *:1) emit warn claude-hook "hook linked but not registered in ~/.claude/settings.json; fix: machine.sh --worktree-hook" ;;
  *) emit ok claude-hook "no WorktreeCreate hook (optional; Claude Code makes worktrees in .claude/worktrees and git post-checkout fills them)" ;;
esac
# The hook reads each repo's info/craft-worktree only; a per-machine list beside it is dead weight
[ -f "$HOME/.claude/hooks/worktree-create/config.json" ] \
  && emit warn claude-hook "~/.claude/hooks/worktree-create/config.json is not read; move each repo's entries into its info/craft-worktree"

# 11. craft drift
tpl=$SKILL/templates/craft/skill/references
if [ -d "$tpl" ]; then
  drift=''
  for f in "$repo"/.claude/skills/*-craft/references/*.md; do
    [ -f "$f" ] || continue
    t=$tpl/$(basename "$f")
    [ -f "$t" ] || continue
    ha=$(grep '^## ' "$f" 2>/dev/null); hb=$(grep '^## ' "$t" 2>/dev/null)
    [ "$ha" = "$hb" ] || drift=$drift$(basename "$f")$nl
  done
  if [ -n "$drift" ]; then emit warn craft-drift "headings differ from template: $(join "$drift")"
  else emit ok craft-drift "headings match template"; fi
else
  emit ok craft-drift "no template"
fi

# 12. tooling
if command -v node >/dev/null 2>&1; then emit ok tooling "node $(node --version 2>/dev/null)"
else emit fail tooling "node not on PATH"; fi
pm=$(sh "$SKILL/scripts/provision.sh" --detect "$repo")
if [ -n "$pm" ]; then
  if command -v "$pm" >/dev/null 2>&1; then emit ok tooling "$pm available (matches lockfile)"
  else emit fail tooling "$pm not on PATH but the repo's lockfile needs it"; fi
elif [ -f "$repo/package.json" ]; then emit warn tooling "package.json without a lockfile"; fi
gv=$(git --version 2>/dev/null | sed -n 's/^git version \([0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}\).*/\1/p')
case $gv in *.*.*) ;; *) gv=$gv.0 ;; esac
if version_ge "$gv" 2.31.0; then emit ok tooling "git $gv (>= 2.31)"
else emit fail tooling "git $gv < 2.31"; fi

[ "$FAILS" -gt 0 ] && exit 1
exit 0
