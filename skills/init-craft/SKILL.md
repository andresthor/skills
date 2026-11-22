---
name: init-craft
description: >-
  Set up, check or repair a repo's agent layer on this machine: repo skills and a review agent under
  `.claude/`, a per-repo craft skill written from templates, git commit gates that run the repo's
  own checks in any language,
  worktree provisioning so every new worktree gets the untracked local files, and the per-machine
  wiring that lets Claude Code, Pi and OpenCode see the same files. Use whenever a repo is new,
  cloned or moved and needs its agent setup, when a worktree is missing its skills, env files or
  local instructions, or when asked "set up this repo for agents", "check this repo's agent setup",
  "why doesn't Pi see the skill", "add commit gates", "write a craft skill for this repo", "put
  Claude Code worktrees in one place", or to audit what each tool can see. Hands the `.context`
  workspace and the local instruction files to init-context. Safe to re-run; it reports before it
  writes.
argument-hint: "[repo-root] [check]"
allowed-tools: Bash(sh *init-craft/scripts/*), Bash(git *), Read, Edit, Write
metadata:
  version: 1.1.0
---

# init-craft

A repo's agent layer lives in Claude Code's layout: `.claude/skills/`, `.claude/agents/`, the local instruction files, and a tracked `AGENTS.md` if the repo has shared instructions. Other tools reach those files through one adapter per machine, never through extra copies in the repo. `coverage.tsv` lists every concept and how each tool gets it. `status.sh` prints that table with `✓` (works), `✗` (should work, does not), `-` (not in use here), `?` (cannot tell) or `none` (deliberately unsupported), so a gap is never hidden.

Scripts live in `scripts/` next to this file. The skill directory is usually a symlink, so resolve its absolute path first and run the scripts with `sh`. They never prompt. Ask the user, with your question tool, only for what the repo cannot tell you.

## Requirements

- `git` 2.31 or later and `node` on `PATH`. The scripts read and edit JSON with `node`.
- No language is assumed. The gate is whatever command the repo checks itself with. `install` knows the lockfiles of pnpm, npm, yarn, bun and uv; any other setup is a `run <command>` line. Go and Rust need neither, because their module caches are shared by every worktree.
- The scripts and `craft-check` run on `node` in every kind of repo. The repo itself needs no `package.json`.
- The `.context` workspace and the local instruction files come from the **init-context** skill. Without it, write those files by hand or leave them out; `status.sh` reports them as `warn`, not `fail`.
- Pi and OpenCode are optional. A tool that is not installed shows as `none` or is skipped.

## Steps

1. **Status.** `sh <skill>/scripts/status.sh <repo>`. Read every line. This is also the whole audit: if the user only asked to check, report the table and the `✗`, `fail` and `warn` lines and stop.
2. **Machine.** If a machine-level cell is `✗` (global instructions links, Pi adapter links, OpenCode `instructions` entry or version), run `sh <skill>/scripts/machine.sh --dry-run`, show the `would` lines, and apply on a yes. OpenCode below 2.1.0 ignores `instructions`: tell the user to run `opencode upgrade`; do not run it yourself.
3. **Backup** before changing anything in an existing repo: `sh <skill>/scripts/backup.sh <repo>`. Confirm the archive path it prints.
4. **Context and local instructions.** If status reports `.context` or `CLAUDE.local.md` missing, run the init-context skill for the repo and come back. The local instruction files are the user's. Add only what is missing: a line telling agents to load the repo's craft skill before code work, if the repo has one. Show the diff, confirm, write.
5. **Gates.** These files are tracked, so they go through the repo's own review and commit rules.
   - `bin/hooks/pre-commit` is a short `sh` script that runs the checks the repo already has and stops at the first failure: for example `pnpm typecheck && pnpm lint`, `uv run ruff check . && uv run pyright`, `go vet ./... && go test ./...`, `cargo clippy -- -D warnings`. Take the commands from where the repo defines them (package scripts, a Makefile or justfile, the CI workflow). Do not invent checks the repo does not run. Put the faster check first, unless one check installs something the other needs.
   - Add `bin/hooks/commit-msg` only if the repo checks messages. A repo with nothing to check gets no gate; status then shows `-` for the gates and one `warn`.
   - Copy `templates/hooks/install` to `bin/hooks/install`. It wires the gate into a fresh clone. Call it from whatever the repo already runs after cloning: the `prepare` script in `package.json` (`sh bin/hooks/install || true`, replacing any `git config core.hooksPath ...`), a `setup` target in the Makefile or justfile, or one line in the README.
   - Commit this before step 6. In a Node repo whose `prepare` still sets `core.hooksPath`, any dependency install sets it again and silently disables the local hooks.
6. **Hooks and worktrees.** `sh <skill>/scripts/hooks.sh <repo> --dry-run`, then for real. Show the generated `.git/info/craft-worktree` and ask about repo-specific additions (a gitignored config file, more env files, `link node_modules` to share one install, a `run` line for setup the lockfile does not cover). Then run `sh <skill>/scripts/provision.sh --all` from inside the repo to fill the worktrees that already exist.
7. **Clean up leftovers** that the status lines name: `.pi/skills` or `.pi/agents` copies (they shadow the adapter in Pi without a warning), dangling symlinks, whole-directory `.claude` symlinks or stray copies in worktrees. Only after the backup, only what status names, and confirm each deletion with the user.
8. **Verify.** Re-run status: every cell is `✓`, `none` or `-`, and no line is `fail`. Then probe one tool for real, for example `pi -p "List your skills and quote the first line of CLAUDE.local.md"` (leave tools on: Pi lists skills only with a read tool active). Create a throwaway worktree, re-run status, remove the worktree. Report what changed, what you verified, and every remaining `warn`.

## Worktrees

Two mechanisms, one list. The list says **what** a new worktree gets. The optional hook says **where** Claude Code puts it.

**What: `.git/info/craft-worktree`.** One file per repo, local to the machine, shared by all worktrees, never committed. Each line is `link <glob>`, `copy <glob>`, `install` or `run <command>`:

```
link CLAUDE.local.md
link .context
link .claude/skills/*
copy .env
install
run make generate
```

- `link` makes a symlink to the main checkout's file, so an edit shows up everywhere. `copy` makes a snapshot the worktree can change. `install` runs the frozen install for the lockfile it finds (pnpm, npm, yarn, bun, uv) and does nothing when there is none. `run` runs any other command with `sh` inside the new worktree, once per worktree.
- `hooks.sh` writes the first version from the built-in list (`provision.sh --defaults`), keeping the entries that match something in the main checkout and adding `install` when it knows the lockfile. After that the file is the user's.
- The `post-checkout` git hook applies the list on every `git worktree add`, whoever runs it: the user, Claude Code, Pi or a script. Provisioning never replaces an existing path and never writes a tracked path, so it is safe to run again.
- Each linked or copied path is added to `.git/info/exclude` unless git already ignores it.

**Where: the Claude Code `WorktreeCreate` hook.** Opt-in and per machine, because it changes where Claude Code creates worktrees for every repo. Without it, Claude Code makes worktrees in `<repo>/.claude/worktrees/<name>` and the `post-checkout` hook still fills them.

- Install: `sh <skill>/scripts/machine.sh --worktree-hook --dry-run`, show the `would` lines, apply on a yes. It links `~/.claude/hooks/worktree-create/worktree-create.sh` to `adapters/claude/worktree-create.sh` and adds a `hooks.WorktreeCreate` entry to `~/.claude/settings.json`. It leaves a different script or a different registered command alone and reports `warn ... differs`; moving the old one aside is the user's call.
- Placement: `~/wt/<main checkout path from $HOME>/<name>`, so `~/code/app` with the name `fix-login` goes to `~/wt/code/app/fix-login`. A repo outside `$HOME` goes under `~/wt/_abs/`. `INIT_CRAFT_WORKTREE_ROOT` replaces `~/wt`; set it where Claude Code's environment will see it.
- The worktree is created detached at `origin/HEAD`, or at `HEAD` when there is no such ref. The name `<name>@<ref>` starts from `<ref>` instead.
- The hook then runs the same provisioning from the same list. This also covers a repo where `core.hooksPath` bypasses `.git/hooks`, and a repo this skill never set up: with no `craft-worktree` file the built-in list applies, without `install`.
- With a `WorktreeCreate` hook in place, Claude Code does not read `.worktreeinclude`. The `craft-worktree` list replaces it.
- Claude Code removes the worktree itself when the session ends. It keeps the worktrees it made for subagents, so prune `~/wt` from time to time with `git worktree remove`.

## New repo with no craft skill yet

Do steps 1 to 6. If the repo has code, offer to write `.claude/skills/<repo>-craft/` (how to write and review code here) and `.claude/agents/craft-review.md`. Derive both from what you investigated: the stack, the scripts, what the code runs inside, the pinned dependency that is the source of truth. Ask what you cannot infer. Start from `templates/craft/`:

- `skill/` goes to `.claude/skills/<repo>-craft/` and `agent/craft-review.md` to `.claude/agents/`. Fill every `{{placeholder}}` and `<!-- fill -->` note from the investigation, then delete the notes.
- `bin/craft-check.mjs` with its `.d.mts` (the engine, owned by the template) and `bin/craft-check.config.mjs` (the repo's choice of rules, scan roots and file extensions) go to `bin/`. `test/craft-check.test.ts` goes with the repo's tests. Add `node bin/craft-check.mjs` to the gate. In a TypeScript repo the test needs `"type": "module"` and `types: ["node"]` to typecheck; in any other repo run it with `node --test`.
- The templates give examples for several languages. Keep the ones for this repo's languages and delete the rest.
- Fill the "Checked mechanically" list in `references/review.md` with exactly the rules the config enables.

With no code yet, skip the craft skill until the first real feature. Rules written before there are mistakes to learn from are guesses.

## Script reference

| Script | Does | Writes |
| --- | --- | --- |
| `status.sh [repo]` | The audit: coverage table plus check lines. Exit 1 on any `✗` or `fail`. | nothing |
| `machine.sh [--dry-run] [--worktree-hook]` | Links the global instructions file and the Pi adapter, and adds `CLAUDE.local.md` to OpenCode's `instructions`. With the flag it installs the `WorktreeCreate` hook and does nothing else. | `~/.claude`, `~/.pi/agent`, `~/.config/opencode` |
| `backup.sh [repo]` | Archives the untracked agent layer, `.git/hooks` and `.git/info/exclude`. | one `.tgz` in the backup directory |
| `hooks.sh [--dry-run] [--force] [repo]` | Installs `pre-commit`, `commit-msg`, `post-checkout` and `craft-provision` into `.git/hooks` and writes the first `craft-worktree`. | `.git/hooks`, `.git/info` |
| `provision.sh [--dry-run] <worktree>... \| --all \| --install-only <worktree>... \| --defaults \| --detect <dir>` | Applies the `craft-worktree` list. Installed into the repo as `.git/hooks/craft-provision`. | the worktree, `.git/info/exclude` |

Every output line is `<state> <what> <detail>`. The states are `ok`, `would` (dry run), `wrote`, `skip`, `warn` (left alone, needs a decision) and `fail`.

Environment variables, all optional:

- `INIT_CRAFT_GLOBAL_INSTRUCTIONS`: the one global instructions file that each tool's own global file links to. Default `~/.agents/AGENTS.md`. When the file does not exist, the concept is not in use and nothing is linked.
- `INIT_CRAFT_PI_PROFILES`: more Pi profile directories, separated by colons. `~/.pi/agent` is always included.
- `INIT_CRAFT_PI_READS_CLAUDE_AGENTS=1`: declares that a Pi extension loads `.claude/agents`. Pi has no agent loader of its own, so without this the cell is `none`.
- `INIT_CRAFT_WORKTREE_ROOT`: where the `WorktreeCreate` hook puts worktrees. Default `~/wt`.
- `INIT_CRAFT_BACKUP_DIR`: where `backup.sh` writes. Default `~/.local/state/init-craft/backups`, or under `$XDG_STATE_HOME` when that is set.
- `INIT_CRAFT_OPENCODE_VERSION`: the OpenCode version, when status cannot read it from OpenCode's log.

## Rules

- Never overwrite or delete without showing it first. The scripts report `warn ... differs` and leave the file.
- Never commit the personal layer (`CLAUDE.local.md`, `AGENTS.local.md`, `.context`, untracked `.claude/*`). The tracked parts (`bin/hooks/*`, `prepare`, a craft skill the user wants shared) go through the repo's commit flow.
- Never print `~/.config/opencode/opencode.json`, `~/.claude/settings.json` or auth files. They can hold secrets.
- Changing `~/.claude/settings.json` or installing the `WorktreeCreate` hook affects every repo on the machine. Show the dry run and wait for a yes each time.
- A worktree `post-checkout` hook must never fail `git worktree add`. If provisioning misbehaves, fix `provision.sh`; do not remove the exit-0 guard.
