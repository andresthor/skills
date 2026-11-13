---
name: init-context
description: >-
  Scaffold a repo's `.context/` workspace and the instruction files that point agents at it, and
  nothing else: `.context/{AGENTS,CLAUDE,HANDOFF}.md`, the `.context/{projects,output,research,notes}`
  symlinks into the vault, an untracked `AGENTS.local.md` + `CLAUDE.local.md` carrying the project
  name and a pointer to `.context/AGENTS.md`, and a root `AGENTS.md` + `CLAUDE.md` that make every
  agent pick the local files up. Use whenever a repo or a fresh directory needs its context
  workspace — "init context", "set up .context here", "scaffold the context dir", "wire this repo
  into the vault", "add the local instruction files", "this repo has no CLAUDE.local.md" — or when
  `.context` is missing, half-built or has broken links. This is the light setup: no git hooks,
  commit gates, repo skills, review agents or worktree provisioning (that is init-craft). Safe to
  re-run; it reports before it writes and never overwrites.
argument-hint: "[repo-root] [--name <project name>] [--vault work|self|none]"
allowed-tools: Bash(sh *init-context.sh *), Read, Edit
metadata:
  version: 1.0.0
---

# init-context

One script does all the writing: `scripts/init-context.sh`, next to this file. The skill directory is usually a symlink, so resolve its absolute path first and run the script with `sh`. It never prompts, never overwrites and never deletes, so a second run only fills gaps. Your part is the three things it cannot decide: the project name, the vault, and what to do about the lines it reports as `warn`.

## What gets set up

```
<repo>/
├── AGENTS.md          tracked    tells agents to read AGENTS.local.md if it exists
├── CLAUDE.md          tracked    @AGENTS.md
├── AGENTS.local.md    untracked  project name + pointer to .context/AGENTS.md
├── CLAUDE.local.md    untracked  project name + @AGENTS.local.md
└── .context/          untracked
    ├── AGENTS.md      conventions for everything in this directory
    ├── CLAUDE.md      -> AGENTS.md
    ├── HANDOFF.md     empty handoff pointer
    ├── projects/      -> <vault>/<work|self>/<projects|plans>/<slug>
    ├── output/        -> <vault>/<work|self>/output/<slug>
    ├── research/      -> <vault>/<work|self>/research   (shared across repos)
    └── notes/         -> <vault>/<work|self>/notes      (shared across repos)
```

The files are wired this way because the tools load instructions differently, and the wiring is what makes one set of text reach all of them:

- Claude Code loads `CLAUDE.md` and `CLAUDE.local.md` by itself. It never reads `AGENTS.local.md`, and once a `CLAUDE.local.md` exists it stops reading `AGENTS.md` directly. So `CLAUDE.md` imports `AGENTS.md`, and `CLAUDE.local.md` imports `AGENTS.local.md`.
- Other agents read `AGENTS.md` and have no import syntax and no notion of a local file. So `AGENTS.md` tells them in words to read `AGENTS.local.md` when it exists.
- `AGENTS.local.md` is therefore the one place the local text lives. `CLAUDE.local.md` holds only the import plus anything meant for Claude alone.

## Steps

1. **Settle the inputs.** The repo root defaults to the git toplevel of the cwd. The project name defaults to the directory name. Pass `--name` when the user gave a name or the repo states a better one (`package.json` name, README title). The vault kind is inferred from the path. When the script exits with `cannot tell work from self`, ask the user which vault this repo belongs to, or whether to keep everything local (`--vault none`).
2. **Dry run.** `sh <skill>/scripts/init-context.sh <repo> [--name "…"] [--vault …] --dry-run`. Show the user the `would` and `warn` lines. Leave the `ok` lines out unless they ask.
3. **Confirm, then apply.** The run creates folders in the vault and may append to a tracked `AGENTS.md`, so wait for a yes. Then run the same command without `--dry-run`. If the dry run printed no `would` line, there is nothing to apply. Say so and go to step 4.
4. **Handle the `warn` lines.** The script leaves these alone on purpose, because each one needs a decision:
   - `CLAUDE.md missing: import of AGENTS.md` — an existing `CLAUDE.md` does not pull in `AGENTS.md`, so Claude Code will not see the shared instructions. Offer to add `@AGENTS.md` as its first line. If the two files hold the same text, say so and let the user choose which one to keep.
   - `differs: -> …` on a `.context` link — it points somewhere other than the vault path. Report both paths. Do not repoint it yourself.
   - `.context/CLAUDE.md … regular file` — the user has a separate file there. Leave it.
   - `tracked` — a file that should be personal is committed, so the exclude does nothing. Tell the user. Removing it from the index is their call.
   - `no vault` — it used real directories inside `.context/`. Say so, so the user is not surprised by missing links.
5. **Verify.** Run the script once more and check that every line is `ok` or a `warn` you already raised. Report what was created, what was already there, and what is still open.

## Script reference

```
init-context.sh [repo-root] [--name NAME] [--vault work|self|none] [--slug SLUG] [--dry-run]
```

- `--slug` sets the vault folder name for `projects/` and `output/`. It defaults to the repo directory name. Use it when two repos would collide, or when the vault already holds a folder for this repo under another name.
- `INIT_CONTEXT_VAULT` overrides the vault root (default `~/.vault`).
- Each output line is `<state> <what> <detail>`. The states are `ok` (already right), `would` (dry run), `wrote`, `skip` (not applicable) and `warn` (left alone, needs a decision).
- For a file that already exists, the script appends only the missing piece: the import line to `CLAUDE.local.md`, the pointer section to `AGENTS.local.md`, the local-instructions section to `AGENTS.md`. It never rewrites what is there.
- In a git repo it adds `/.context`, `/CLAUDE.local.md` and `/AGENTS.local.md` to `.git/info/exclude`. That file is shared by all worktrees and is not committed. Outside git it skips this.

## Rules

- Never edit `.context/HANDOFF.md` by hand. The handoff tooling owns it, and the scaffold is the empty state that tooling expects.
- Never commit `.context/`, `AGENTS.local.md` or `CLAUDE.local.md`. The root `AGENTS.md` and `CLAUDE.md` are meant to be tracked. Leave committing them to the user and the repo's own commit flow.
- Stay inside this scope. When the user also wants hooks, commit gates, a craft skill or worktree provisioning, tell them that is init-craft and stop here.
