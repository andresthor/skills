---
name: pickup
description: >-
  Resume work from a handoff — read the well-known pointer, open the project's handoff entry, check
  the repo still matches it (branch, head, dirty tree, and whether the work already merged), and give
  a short orientation plus the next concrete step. Use at the start of a session or whenever the user
  wants to re-enter work in progress: "pick up where I left off", "resume", "what were we doing",
  "catch me up", "where were we", "what's left on this branch", "continue the last session", "load the
  handoff". Pair skill: handoff. Needs git and python3; uses gh when available.
argument-hint: "[project-slug] [--go — start the next step without asking]"
allowed-tools: Bash(git *), Bash(gh pr view *), Bash(python3 *), Bash(bash *), Read, Glob, Grep, AskUserQuestion
metadata:
  version: 2.2.1
---

# Pickup

Recover a work session someone (maybe you, maybe another agent) wrote down with `handoff`. This is read-only: you gather and verify context, then hand the user a short orientation and a proposed next action. You do not start the work until they confirm (`--go` is the one exception — see Rules).

The scripts live in the handoff skill: `../handoff/scripts/` relative to this file. If a script fails, report it and stop.

---

## Step 1 — find the pointer and select the entry

Resolve the pointer exactly as handoff's Step 1 does — the user's declared root for generated files, else `.context/HANDOFF.md`, else `HANDOFF.md` at the repo root. Answer the first case from the instructions already in your context; take the first location that resolves and move on. If none resolves, say so and ask which project to pick up; don't guess.

If the pointer's first line is not `<!-- handoff-format: 2 -->`, it was written by an older handoff. Read `../handoff/references/migrate.md` and follow it before continuing — it converts the file once, by you, and the user runs nothing.

Select the block with the script, never by reading the whole file:

- A slug was passed → `handoff-pointer.py <HANDOFF.md> show --slug <slug>`.
- Else → `show --branch "$(git rev-parse --abbrev-ref HEAD)"`. If the branch matches more than one block, list them and ask.

If the selection is empty (no block for this slug or branch), **stop here** — do not run `check --dead`, do not investigate other blocks. The pointer has no entry for this project. List the slugs the pointer does hold (one compact `show`, no filter) and ask the user one of: pick an existing slug, open the project's handoff directly if a `handoff.md` exists for it under `.context/projects/`, or run `/handoff` to write a fresh pointer for the current branch. A dangling handoff (project dir exists, pointer block missing) is common after a botched migration or a stray `remove`; it is not a reason to audit the rest of the pointer.

Only once a block is selected, run `handoff-pointer.py <HANDOFF.md> check --dead`. It reports structural problems and, using `git merge-base --is-ancestor <head> origin/main` per block, any block whose work is already in main. A block with `commits: 0` is skipped by the dead check — a branch with no commits of its own cannot have merged, so a planning-only branch never lands on the dead list. Report dead blocks as `dead: <slug> (head in main since …)` and offer `handoff-pointer.py <HANDOFF.md> prune`; the user confirms before anything is removed. Run the dead check scoped to your concern — you selected one project; a dead *other* block is a one-line FYI, not an investigation.

## Step 2 — read the handoff

Open the file named by `handoff:`. Read the **top entry only** — stop at the first `---`. Older entries are history, not state; open one only if the top entry names it by date. Never open `*-archive.md`. Then read `decisions.md` in the same dir if present; standing decisions and traps live there, not in the entry.

## Step 3 — fingerprint check

Compare the block's `branch`, `head`, `dirty` against `bash <scripts>/handoff-fingerprint.sh`. `head` is a prefix match — the two were produced by `git rev-parse --short` at different times and may differ in length.

- **`commits: 0` (planning branch)** → the branch has no commits of its own; the work lives in uncommitted docs. Do not fetch, do not run `check --dead`, do not run `merge-base — the repo cannot have merged work that does not exist. Skip to the orientation, report `read:` cost, ask to proceed. This is the fast path, and it is the common case for planning that runs for weeks before the first commit.
- **All three match** → also confirm the work has not merged underneath you: `git fetch -q && git merge-base --is-ancestor <head> origin/main` (no origin → say so and take the full flow). Skip this when the block is `commits: 0` — that case is handled above. If the entry names a PR and `gh` is available, `gh pr view <n> --json state,mergedAt`. A head already in main or a PR in state MERGED means the handoff is describing finished work: say "this merged as #N on <date>", and treat it as a mismatch below. Otherwise the repo provably hasn't moved: skip Step 4, orient in two lines, ask to proceed.
- **`commits` absent (old pointer)** → run the merge check as above. The first `/handoff` on the project adds the field; until then the check is the fallback.
- **Branch mismatch** (a slug was passed, or the user chose a project on another branch) → do not check out anything. Say "this handoff is for `<X>`, you're on `<Y>`", offer to switch or to continue where you are, and wait.
- **Head or dirty mismatch, merged, or stale** (`updated:` more than 30 days ago → say "stale — verify before trusting") → full flow, Step 4.

## Step 4 — reconcile with reality (mismatch only)

The handoff is a snapshot; the repo may have moved. Cross-check the cheap things: `git log --oneline -5` and `git status --short` — did Next up item 1 already land? Is there uncommitted work the entry doesn't mention? Do the key paths still exist? Drift between what the entry claims and what the repo shows is the most valuable thing you can tell the user.

## Step 5 — orient

A short summary, never a paste of the file. Bullets, each under ~15 words:

- **Where things stand** — one or two lines.
- **Branch** — confirmed, or the mismatch and your recommendation.
- **Standing decisions** — only those that affect the proposed step.
- **Drift** — anything that changed since the handoff, including "merged".
- **Ops** — only if a `linear-ops.md` sits in the project dir: run `python3 ~/.agents/skills/scope-it/scripts/ops.py <file> show --due` and report its first line plus any due item. A due item makes `/scope-it sync` the proposed step unless Next up item 1 outranks it (a due *event* means "ask what happened", not "do it").
- **Proposed next step** — Next up item 1, adjusted for drift, as a concrete action you're ready to take.
- `read: <n> chars entry / <n> chars decisions / <n> chars pointer` — the cost of this pickup, so bloat is visible where it is paid.

Then ask whether to proceed. Let the user redirect before you touch anything.

---

## Rules

- Read-only until the user confirms — no edits, no commits, no branch changes. Pruning dead pointer blocks is the one write, and only on an explicit yes.
- `--go`: start the proposed step without asking — only when passed this invocation, and only on the fast path or a full flow with zero drift. A branch mismatch, a merge, staleness, or any drift always stops for the user.
- Before starting work, read what the entry points at: a `plan.md` in the project dir usually carries the detail the entry only names, and starting without it re-derives decisions already made.
- Trust the repo over the handoff when they conflict, and report the conflict rather than acting on the stale claim.
- The pointer lists several projects; if the one the user wants isn't there, take the slug and open that project's handoff directly.
