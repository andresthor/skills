---
name: pickup
description: >-
  Resume work from a handoff — read the well-known pointer, check the repo still matches it (branch, head, dirty tree,
  and whether the work already merged), read the project's living docs (state, decisions, notes) and the last handoff
  entry, and give an orientation grounded in those docs plus the next step, if there really is one. Use at the start of
  a session or whenever the user wants to re-enter work in progress: "pick up where I left off", "resume", "what were we
  doing", "catch me up", "where were we", "what's left on this branch", "continue the last session", "load the
  handoff". Pair skill: handoff. Needs git and python3; uses gh when available.
argument-hint: "[project-slug] [--quick — orient from the handoff entry only] [--go — start the next step without asking]"
allowed-tools: Bash(git *), Bash(gh pr view *), Bash(python3 *), Bash(bash *), Read, Glob, Grep, AskUserQuestion
metadata:
  version: 3.0.0
---

# Pickup

Recover a work session that someone (maybe you, maybe another agent) left with `handoff`. This is read-only: you gather and verify context, then give the user an orientation and, if there is one, a proposed next action. You do not start the work until they confirm (`--go` is the one exception, see Rules).

**Read the docs, not just the entry.** The handoff entry is a log line from a session that is gone. Its `next:` and anything that looks like an open question are that session's claims, and they are sometimes wrong. An orientation built from the entry alone repeats those mistakes, and the user then has to ask again. The project's `00-` docs are the truth. Spend the reads.

The scripts live in the handoff skill: `../handoff/scripts/` relative to this file. If a script fails, report it and stop.

---

## Step 1 — find the pointer and select the entry

If the user's instructions declare a root for generated files, take the pointer path from there. Otherwise resolve pointer, entry and handoff path in one call: `handoff-pointer.py locate [--slug <slug> | --branch <branch>]` (default branch: the current one). On success it prints three lines: `pointer <path> <format-line>`, `entry <slug> <fields…>`, and `handoff <repo-relative path> exists|MISSING read:<repo-root-joined path>`. Read files via the `read:` path. It keeps the `.context` symlink intact, where a realpath would collapse it to a target the Read tool may reject. Do not hand-roll the lookup with `ls`/`readlink`/`head`/`show`.

- Non-zero exit (no pointer) → say so and ask which project to pick up. Don't guess.
- The format line is not `<!-- handoff-format: 2 -->` → follow `../handoff/references/migrate.md` §Pointer before continuing. It converts the file once, and the user runs nothing.
- Pointer found but no `entry` line (no block for this slug or branch) → **stop**. The stderr names the slugs the pointer holds. Offer to pick one, open the project's handoff directly if its file exists, or run `/handoff` to write a fresh pointer. Do not audit the other blocks.
- The `handoff` line says `MISSING` → the entry points at a file that is gone. Say so and offer to write a fresh pointer.

Once a block is selected, run `handoff-pointer.py <HANDOFF.md> check --dead` **only if the block's `commits` is not `0`**. A `commits: 0` planning branch has nothing that could have merged. When the check runs, report dead blocks as `dead: <slug> (head in main)` and offer `handoff-pointer.py <HANDOFF.md> prune`. The user confirms before anything is removed. A dead *other* block is a one-line FYI.

## Step 2 — fingerprint check

Compare the block's `branch`, `head`, `dirty` against `bash <scripts>/handoff-fingerprint.sh`. `head` is a prefix match, because the two short SHAs may differ in length.

- **`commits: 0`** → planning-only work. Do not fetch or run the merge check.
- **All three match** → confirm the work has not merged underneath you: `git fetch -q && git merge-base --is-ancestor <head> origin/main` (no origin → say so). If the entry or docs name a PR and `gh` is available, `gh pr view <n> --json state,mergedAt`. A head already in main or a merged PR means the handoff describes finished work. Say "this merged as #N on <date>" and treat it as drift.
- **`commits` absent** (older pointer) → run the merge check as above.
- **Branch mismatch** → do not check out anything. Say "this handoff is for `<X>`, you're on `<Y>`", offer to switch or to continue where you are, and wait.
- **Head or dirty mismatch**, or `updated:` more than 30 days ago → treat it as drift. Step 4 runs.

## Step 3 — read the project

The project dir is the directory of the `read:` path. Read, in this order:

1. `AGENTS.md`, if present. It holds the project's writing rules and overrides this skill where they conflict.
2. The **top entry** of the handoff file, which stops at the first `---`. Never open `*-archive.md`, and open an older entry only if the docs name it.
3. `00-state.md`, `00-decisions.md`, `00-notes.md`, each whole. Their line caps keep this bounded.

**Older layout** (no `00-` docs): read the top entry of `handoff.md` and `decisions.md`. A `notes.md` there is reference material, so name it but do not read it.

**Stop there.** Numbered docs (`01-…`, `02-research/`) and anything else the docs point at are the payload for the next step. Name them in the orientation and read them when work starts.

Then record what the docs look like now, so that handoff can later tell this session's edits apart from older lines: `python3 <scripts>/handoff-lint.py <project-dir> --snapshot`. It writes only to the system temp dir.

**`--quick`** skips this step except the top entry and the snapshot. Use it only when the user passed it in this invocation, and never choose it yourself. Label the orientation "from the handoff entry only, not checked against the docs".

## Step 4 — reconcile

Check the entry against the docs and the repo. This catches the mistakes that otherwise carry from one session to the next.

- **Entry vs docs**: does `00-state.md` already answer something the entry treats as open? Is the entry's `next:` already done, contradicted by a decision, or about a question the docs settle? Drop what the docs answer, and say so in one line.
- **Entry vs repo** (on drift): `git log --oneline -5` and `git status --short`. Did `next:` already land? Is there uncommitted work nothing mentions? Do the paths the docs name still exist?
- **Docs vs repo**: a `[verified]` fact the repo now contradicts is worth one line.

Drift between what was written and what is true is the most valuable thing you can tell the user. Trust the repo over the docs, and the docs over the entry.

## Step 5 — orient

A short summary in plain language, never a paste of the files. Bullets, each under ~15 words:

- **Where things stand**: one or two lines, from `00-state.md`.
- **Branch**: confirmed, or the mismatch and your recommendation.
- **Decisions**: only those that affect the proposed step.
- **Drift**: anything that changed since the handoff, including "merged", and anything Step 4 dropped.
- **Next step**: the entry's `next:` if it survived Step 4, adjusted for drift. With no `next:`, propose one only if the docs make it obvious. Otherwise say there is no recorded next step and ask what the user wants to do.
- **Open questions**: only Unknown items in `00-state.md` that block the proposed step. Leave this bullet out when there are none.
- `read: <n> chars docs / <n> chars entry / <n> chars pointer`, so the cost of this pickup is visible.

Then ask whether to proceed. Let the user redirect before you touch anything.

---

## Rules

- Read-only until the user confirms: no edits, no commits, no branch changes. The two exceptions are pruning dead pointer blocks on an explicit yes, and the lint snapshot in the temp dir.
- `--go`: start the proposed step without asking. Only when passed in this invocation, only when there is a next step, and only with zero drift. A branch mismatch, a merge, staleness, or any drift always stops for the user.
- Never present an open question or a next step only because the entry had one. It reaches the user only if it survives the docs.
- Before starting work (after the user says go), read what the docs point at for that step. A plan doc usually carries the detail, and starting without it re-derives decisions already made.
- The pointer lists several projects. If the one the user wants isn't there, take the slug and open that project's handoff directly.
