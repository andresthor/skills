#!/bin/sh
# init-craft v2
# Apply machine-level wiring, each piece only if absent:
#   - global instructions links for every Pi profile, OpenCode and Claude
#   - claude-compat.ts links in each Pi profile's extensions/
#   - "CLAUDE.local.md" in `instructions` of ~/.config/opencode/opencode.json
#   - with --worktree-hook, only: the Claude Code WorktreeCreate hook (link + ~/.claude/settings.json entry)
# Never replaces an existing different target (reports `warn ... differs`). Never prints a config file.
set -u

usage() {
  cat <<'EOF'
usage: machine.sh [--dry-run] [--worktree-hook]

  --worktree-hook  install the Claude Code WorktreeCreate hook and nothing else. It puts every
                   worktree Claude Code creates under $INIT_CRAFT_WORKTREE_ROOT (default ~/wt).
                   Opt-in: it changes where worktrees go for every repo on this machine.

Global instructions: $INIT_CRAFT_GLOBAL_INSTRUCTIONS, default ~/.agents/AGENTS.md; skipped if missing.
Pi profiles: ~/.pi/agent plus each dir in $INIT_CRAFT_PI_PROFILES (colon-separated).
Output lines: <state> <what> <detail>, state = ok | would | wrote | skip | warn | fail
EOF
}

DRY=0 WTHOOK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --worktree-hook) WTHOOK=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $a" >&2; usage >&2; exit 2 ;;
  esac
done

# Skill dir: resolve $0 through symlinks, then ..
self=$0
while [ -L "$self" ]; do
  d=$(cd "$(dirname "$self")" && pwd -P)
  l=$(readlink "$self")
  case "$l" in /*) self=$l ;; *) self="$d/$l" ;; esac
done
SKILL=$(cd "$(dirname "$self")/.." && pwd -P)
ADAPTER="$SKILL/adapters/pi/claude-compat.ts"
CANON=${INIT_CRAFT_GLOBAL_INSTRUCTIONS:-$HOME/.agents/AGENTS.md}
WTSRC="$SKILL/adapters/claude/worktree-create.sh"
WTDST="$HOME/.claude/hooks/worktree-create/worktree-create.sh"

short() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }
say() { printf '%s %s %s\n' "$1" "$2" "$3"; }

# link TARGET LINKPATH: symlink LINKPATH -> TARGET if absent
link() {
  _t=$1 _p=$2
  if [ -L "$_p" ]; then
    _cur=$(readlink "$_p")
    if [ "$_cur" = "$_t" ]; then say ok "$(short "$_p")" "-> $(short "$_t")"
    else say warn "$(short "$_p")" "differs: -> $(short "$_cur") (expected $(short "$_t"), left as is)"; fi
  elif [ -e "$_p" ]; then
    say warn "$(short "$_p")" "differs: exists and is not a symlink (left as is)"
  elif [ "$DRY" = 1 ]; then
    say would "$(short "$_p")" "-> $(short "$_t")"
  else
    mkdir -p "$(dirname "$_p")" && ln -s "$_t" "$_p" && say wrote "$(short "$_p")" "-> $(short "$_t")" \
      || say fail "$(short "$_p")" "could not create link"
  fi
}

# Claude Code WorktreeCreate hook: its own run, so a yes to it is not a yes to the links below
MERGE_HOOK_JS=$(cat <<'JS'
// usage: node -e ... <file> <command> <dry:0|1>; prints one status word + detail, never file content
const fs = require("fs");
const [file, command, dry] = process.argv.slice(1);
const out = (s, d) => console.log(`${s} ${d}`);
let raw = "{}\n", cfg = {};
if (fs.existsSync(file)) {
  try { raw = fs.readFileSync(file, "utf8"); cfg = JSON.parse(raw); } catch { out("warn", "differs: not valid JSON, left as is"); process.exit(0); }
}
const obj = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
if (!obj(cfg) || (cfg.hooks !== undefined && !obj(cfg.hooks))) { out("warn", "differs: unexpected shape, left as is"); process.exit(0); }
const cur = cfg.hooks?.WorktreeCreate;
if (cur !== undefined && !Array.isArray(cur)) { out("warn", "differs: hooks.WorktreeCreate is not a list, left as is"); process.exit(0); }
const cmds = (cur || []).flatMap((g) => (Array.isArray(g?.hooks) ? g.hooks : [])).map((h) => h?.command);
if (cmds.includes(command)) { out("ok", "hooks.WorktreeCreate runs the hook"); process.exit(0); }
// Claude Code takes the worktree path from one hook; a second one would compete for it
if (cmds.length) { out("warn", "differs: hooks.WorktreeCreate already runs another command, left as is"); process.exit(0); }
if (dry === "1") { out("would", "add hooks.WorktreeCreate"); process.exit(0); }
cfg.hooks = { ...(cfg.hooks || {}), WorktreeCreate: [{ hooks: [{ type: "command", command }] }] };
const m = raw.match(/\n([ \t]+)\S/);
fs.mkdirSync(require("path").dirname(file), { recursive: true });
fs.writeFileSync(file, JSON.stringify(cfg, null, m ? m[1] : 2) + "\n");
out("wrote", "added hooks.WorktreeCreate");
JS
)
CSET="$HOME/.claude/settings.json"
if [ "$WTHOOK" = 1 ]; then
  if [ ! -f "$WTSRC" ]; then say warn worktree-hook "missing $WTSRC; not installed"
  elif ! command -v node >/dev/null 2>&1; then say warn worktree-hook "node not found; the hook needs it"
  else
    link "$WTSRC" "$WTDST"
    # register only once the link is right, so settings never point at a missing or foreign script
    if [ "$DRY" = 1 ] || { [ -L "$WTDST" ] && [ "$(readlink "$WTDST")" = "$WTSRC" ]; }; then
      # the literal $HOME is expanded by the shell Claude Code runs the hook in
      r=$(node -e "$MERGE_HOOK_JS" "$CSET" '"$HOME/.claude/hooks/worktree-create/worktree-create.sh"' "$DRY" 2>/dev/null) || r="fail node error"
      say "${r%% *}" "$(short "$CSET")" "${r#* }"
    else
      say skip "$(short "$CSET")" "hook link not in place; settings left as is"
    fi
  fi
  exit 0
fi


HAVE_CANON=1
[ -e "$CANON" ] || { HAVE_CANON=0; say skip "$(short "$CANON")" "no global instructions file; links skipped"; }
HAVE_ADAPTER=1
[ -f "$ADAPTER" ] || { HAVE_ADAPTER=0; say warn adapter "missing $ADAPTER; extension links skipped"; }

# Pi profiles
PROFILES="$HOME/.pi/agent"
EXTRA=${INIT_CRAFT_PI_PROFILES-}
OLDIFS=$IFS; IFS=:
for e in $EXTRA; do [ -n "$e" ] && PROFILES="$PROFILES:$e"; done
for p in $PROFILES; do
  IFS=$OLDIFS
  if [ ! -d "$p" ]; then say skip "$(short "$p")" "pi profile dir not found"; IFS=:; continue; fi
  [ "$HAVE_CANON" = 1 ] && link "$CANON" "$p/AGENTS.md"
  [ "$HAVE_ADAPTER" = 1 ] && link "$ADAPTER" "$p/extensions/claude-compat.ts"
  IFS=:
done
IFS=$OLDIFS

# Claude
[ "$HAVE_CANON" = 1 ] && link "$CANON" "$HOME/.claude/CLAUDE.md"

# OpenCode
if ! command -v opencode >/dev/null 2>&1; then
  say skip opencode "not on PATH"
  exit 0
fi
OCDIR="$HOME/.config/opencode"
[ "$HAVE_CANON" = 1 ] && link "$CANON" "$OCDIR/AGENTS.md"

ver=$(opencode --version 2>/dev/null | sed -n 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | sed -n 1p)
if [ -z "$ver" ]; then say warn opencode-version "cannot determine version (need >= 2.1.0 for instructions)"
else
  ok=$(printf '%s\n2.1.0\n' "$ver" | awk -F. 'NR==1{a=$1*1000000+$2*1000+$3} NR==2{b=$1*1000000+$2*1000+$3} END{print (a>=b)?1:0}')
  if [ "$ok" = 1 ]; then say ok opencode-version "$ver >= 2.1.0"
  else say warn opencode-version "$ver < 2.1.0; 'instructions' is ignored (run: opencode upgrade)"; fi
fi

CONF="$OCDIR/opencode.json"
if [ ! -f "$CONF" ]; then
  say skip "$(short "$CONF")" "not found"
  exit 0
fi
command -v node >/dev/null 2>&1 || { say warn "$(short "$CONF")" "node not found; cannot edit"; exit 0; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/init-craft.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/merge.js" <<'JS'
// usage: node merge.js <file> <dry:0|1>; prints one status word + detail, never file content
const fs = require("fs");
const [file, dry] = process.argv.slice(2);
const ENTRY = "CLAUDE.local.md";
const out = (s, d) => console.log(`${s} ${file} ${d}`);
let raw, cfg;
try { raw = fs.readFileSync(file, "utf8"); cfg = JSON.parse(raw); } catch { out("warn", "differs: not valid JSON, left as is"); process.exit(0); }
if (cfg === null || typeof cfg !== "object" || Array.isArray(cfg)) { out("warn", "differs: not a JSON object, left as is"); process.exit(0); }
if (cfg.instructions !== undefined && !Array.isArray(cfg.instructions)) { out("warn", "differs: instructions is not a list, left as is"); process.exit(0); }
if ((cfg.instructions || []).includes(ENTRY)) { out("ok", `instructions has ${ENTRY}`); process.exit(0); }
if (dry === "1") { out("would", `add ${ENTRY} to instructions`); process.exit(0); }
cfg.instructions = [...(cfg.instructions || []), ENTRY];
const m = raw.match(/\n([ \t]+)\S/);
const indent = m ? m[1] : 2;
// writeFileSync on the existing path truncates in place: mode and symlink are kept
fs.writeFileSync(file, JSON.stringify(cfg, null, indent) + (raw.endsWith("\n") ? "\n" : ""));
out("wrote", `added ${ENTRY} to instructions`);
JS
out=$(node "$TMP/merge.js" "$CONF" "$DRY" 2>/dev/null) || out="fail $CONF node error"
# rewrite the path as ~/... in the first field pair
printf '%s\n' "$out" | while IFS= read -r line; do
  st=${line%% *}; rest=${line#* }; f=${rest%% *}; det=${rest#* }
  say "$st" "$(short "$f")" "$det"
done
