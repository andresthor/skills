---
name: handoff
description: >-
  Capture the current work session as a handoff a fresh session, another agent, or a teammate can
  resume from cold — state now, the next concrete step, open decisions, key paths — and register it
  in a well-known pointer so pickup finds it with zero guessing. Use whenever work is being paused
  or handed over, even if nobody says "handoff": wrapping up, running low on context, "I'm about to
  clear/compact", "checkpoint this", "save state before I stop", "note where we are for next time",
  "write a handoff", or closing out a finished project. Pair skill: pickup. Needs git and python3.
argument-hint: "[project-slug] [--next '<one action, ≤80 chars>'] [--close]"
allowed-tools: Bash(git *), Bash(gh pr view *), Bash(mkdir *), Bash(python3 *), Bash(bash *), Read, Glob, Grep, Write, Edit, AskUserQuestion
metadata:
  version: 2.2.0
---

# Handoff

Write down enough state that a fresh, low-context session can pick this work up without re-deriving anything. You produce two things: the **handoff entry** (in the project's running `handoff.md`) and a **pointer entry** (in the well-known `HANDOFF.md`) that tells pickup where the handoff is and what one thing to do next.

The next reader shares none of your context and pays for every character you write. The writer is always at the end of a session with everything in mind; the reader is always at the start of one with nothing. Write for the reader.

## Scripts

Four scripts ship with this skill under `scripts/` beside this file (the skill's base directory is announced when it loads). They are python3 stdlib and bash; they never commit, never touch git state, and never write outside the handoff files.

| script | does |
|---|---|
| `handoff-fingerprint.sh [repo]` | prints `{branch, head, dirty}` from git |
| `handoff-lint.py <handoff.md> [--decisions decisions.md]` | checks the top entry against the limits below |
| `handoff-rotate.py <handoff.md>` | archives old entries once the file passes 180 lines |
| `handoff-pointer.py <HANDOFF.md> upsert\|check\|show\|remove\|prune\|migrate` | the only thing that writes the pointer |

If a script fails, report the error and stop — do not hand-edit around it. The mechanics these scripts own (renumbering, rotating, validating fields) are exactly the ones that went wrong when done by hand.

## What goes in — four tiers

Handoffs are read by agents, not humans. Sort every fact before writing it:

1. **Resume-critical** — state, the ordered next steps, open decisions, key paths, new watch-outs. This is the entry. Nothing else is.
2. **Reference** — run records, SHA maps, validation history, rationale. Goes in `notes.md` in the project dir (create it if absent); the entry gets one line naming the file. Never pasted into the entry.
3. **Dead** — superseded decisions, resolved blockers, stale SHAs. Not carried into the new entry. A standing "do not re-add X" is one line in `decisions.md` (Step 5), not narrative.
4. **Fluff** — session narrative ("we did X, then found Y"), agent rosters and phase counts, tool failures, scratchpad paths, praise, restated context, anything in the first person. Never written.

---

## Step 1 — resolve where the handoff goes

The handoff is project working material, not skill output, so it lives in a project dir. If a `.context/AGENTS.md` exists, follow it. Resolve the root in this order — pickup resolves the pointer in the same order, so the two stay in sync:

1. The user's instructions (including their local context file) declare where generated, non-committed working files go → the project dir goes under that root, the pointer beside it as `HANDOFF.md`.
2. Else, `.context/` exists at the repo root → project dir `.context/projects/<YYYY-MM>/<NN-slug>/`, pointer `.context/HANDOFF.md`.
3. Else, ask once where to save (with a structured question if your tool has one). If you cannot ask, fall back to a `handoff/` directory at the repo root for the project files and `HANDOFF.md` at the repo root for the pointer — two different names, because `handoff.md` and `HANDOFF.md` collide on case-insensitive filesystems. Say which paths you used.

## Step 2 — resolve the project folder

Project dirs are grouped by month and numbered within it: `projects/<YYYY-MM>/<NN-slug>/`.

1. The user passed a slug → use it.
2. Else, a project dir under any month already matches the current branch, or is clearly the active effort → **reuse it**, even across a month boundary. A dir whose top entry says the work was superseded or moved elsewhere is not the active effort — ask rather than resurrecting it.
3. Else, derive a slug from the branch name: drop trailing issue ids, kebab-case, short. On `main`/`master` there is nothing to derive from — ask.

Creating fresh: under the current month, next `NN` in that month (`01-` if empty). Slugs are lowercase kebab-case; the pointer script rejects anything else.

## Step 3 — gather the state

Read the real state; the conversation is not it:

- `bash <scripts>/handoff-fingerprint.sh` — branch, head, dirty count. These go in the pointer verbatim.
- `git log --oneline -5` and `git status --short` — what landed, what is uncommitted.
- The top entry of the project's existing `handoff.md` and its `decisions.md`, if they exist — so the new entry continues the trail instead of repeating it. Do not read older entries; they are history, and each entry must stand alone.

## Step 4 — write the handoff entry

One running file per project, appended over time — not a file per session. If a handoff file already exists in the project dir (`handoff.md` or `NN-handoff.md`), keep its name; creating fresh, use `NN-handoff.md` if the dir uses `NN-` numbering, else `handoff.md`. The new entry goes on top, older entries stay below a `---` divider.

**Limits.** An entry is at most 1,800 characters, no line over 160. One fact per line, at most one sentence. No `;`, no `·`, no inline `(1) … (2)` lists, at most one parenthetical, no em-dash except the label's own. A second clause is a second bullet, or it is cut. These are measured in characters because a line budget is met by unwrapping — the entry gets shorter in lines and longer in every way that matters. The lint in Step 6 counts; you do not have to.

Use this template exactly — five labels, nothing added, no sub-headings. The values are placeholders showing the register; replace every one:

```markdown
## Handoff 2026-08-27
**State now** — feat-add-session-cache @ 3f9c2a1, tree clean, cache layer done, backfill script written but not yet run.
**Next up**
1. `npm run backfill -- --env staging`
2. Compare row counts with the baseline in `notes.md`
**Open decisions** — none
**Key paths & commits**
- `src/cache/session.ts` — cache layer
- `3f9c2a1` — backfill script
**Watch-outs** — none new
```

- **State now** — where things are, not how they got there: branch @ sha, tree clean or dirty, what exists on disk. One line. SHAs beyond the head go in Key paths.
- **Next up** — numbered, 1–5 items. Item 1 is the one step a stranger runs first: a command, a slash-command, or `ask — <question>` when the next step is a decision. One action per item; later items may point at `plan.md`.
- **Open decisions** — `none`, or up to 4 bullets with the options if known.
- **Key paths & commits** — `path or sha — ≤6 words`, no sentences.
- **Watch-outs** — `none new`, or up to 4 bullets that are new this session. Standing traps live in `decisions.md`; never re-type them here.

The heading is the date only, `## Handoff YYYY-MM-DD`; a second entry the same day adds ` HH:MM`. The test is whether a stranger could start without asking you a question — and stop reading the moment they can. "Continue the migration" fails; "port `users` to the new schema in `db/migrations/004`, then run the backfill against staging" passes.

## Step 5 — update decisions.md

Standing decisions and standing watch-outs that outlive one session live in the project dir's `decisions.md`, not in entries. Shape: a flat bullet list, one decision per bullet, one physical line under 160 characters, no headings except the title, no nesting, no strikethrough, no "corrected by" trailers — edit in place or delete. Keep it under 40 lines; rationale longer than a line goes in `notes.md` with a one-line verdict here pointing at it.

**Scope gate — decisions about the project, never about you.** A line qualifies only if it records a settled call about the work: design, scope, process, don't-re-raise items, ideally attributed. Never your own workflow or communication preferences, lessons from your own mistakes, or anything that belongs in the user's instruction files. A missing line costs one question; a junk line pollutes every future pickup.

If this session reverses a decision recorded in **another** project's `decisions.md`, mark that line `SUPERSEDED:` there with one clause on why. That is maintaining the record, not clobbering another project.

## Step 5b — update the ops file, if one exists

If the project dir holds a `linear-ops.md`, it is the project's durable contract with Linear and it must not fall behind the session. Record every change through the script — never by hand: `python3 ~/.agents/skills/scope-it/scripts/ops.py <file> …` with `add` for a newly scheduled event or due action, `resolve <n>` for anything that happened, `decision answered` for a decision that was answered, `map set` for a new identifier. Then run `… check`; a non-zero exit is reported in Step 9, not fixed by editing the file. The entry's Next up may point at `/scope-it sync` but never repeats the ops file's contents.

## Step 6 — lint the entry

`python3 <scripts>/handoff-lint.py <handoff.md> --decisions <decisions.md>`. Fix every error and re-run, at most twice, then continue regardless — the lint informs the handoff, it never blocks it. When a line is too long or too dense, cut it or move the material to `notes.md` and leave one pointer line; do not split one thought into fragments to satisfy the counter. Warnings and any errors still standing are reported in Step 9.

## Step 7 — rotate

`python3 <scripts>/handoff-rotate.py <handoff.md>`. Once the file passes 180 lines it moves every entry but the top two to the `-archive` sibling, verbatim and newest on top. Running it on a small file is a no-op, so run it every time. Never add a "see archive" line to the entry — pickup never reads archives.

## Step 8 — write the pointer, last

Only after the handoff file is final, so the pointer never names a half-written file. The pointer is a **locator, not a summary**: it tells pickup which entry is this project's, where the handoff file is, and the one action to take next. Everything else lives in the entry. It holds one block per active project, newest first:

```markdown
<!-- handoff-format: 2 -->
# Active handoffs

## session-cache
- branch: feat-add-session-cache
- head: 3f9c2a1
- dirty: 0
- state: in-progress
- next: run the backfill against staging
- handoff: .context/projects/2026-08/03-session-cache/handoff.md
- updated: 2026-08-27
```

Write it with the script and nothing else:

```bash
python3 <scripts>/handoff-pointer.py <HANDOFF.md> upsert --slug <slug> \
  --branch <from fingerprint> --head <from fingerprint> --dirty <from fingerprint> \
  --state in-progress --next "<one action, ≤80 chars>" --handoff <path from Step 4, relative to the repo root>
```

- `branch`, `head`, `dirty` are the fingerprint values exactly — no annotations, no merge notes, no file names. Pickup compares them byte-for-byte; anything appended breaks the comparison and belongs in the entry.
- `state` is one of `in-progress | blocked | review | done | parked | superseded`. `next` is one action, no `;`, never "optional …" — if the only remaining work is optional, the state is `done`.
- The script moves this project's block to the top, preserves every other block byte-for-byte, and refuses a `handoff:` path that does not exist or is not a handoff file. If it refuses, fix the input; never edit `HANDOFF.md` by hand.
- If `HANDOFF.md` exists and its first line is not `<!-- handoff-format: 2 -->`, stop and read `references/migrate.md` beside this file; it walks you through converting the pointer once. The user runs nothing.
- **`--close`**: the project is finished (merged, superseded, nothing next). Write a terminal entry (`state: done`: what merged, where the report is, one don't-retry line), then `handoff-pointer.py <HANDOFF.md> remove --slug <slug>`. Its history stays in the project dir.
- If a new session continues work on a branch that already has a pointer block, update that block — pickup resolves by branch and cannot tell two blocks on one branch apart.

## Step 9 — confirm

Tell the user: the slug, the paths written (handoff, decisions, archive if rotated, pointer), the `state:` and `next:` line, and `read: <n> chars entry / <n> chars decisions` so the cost of the next pickup is visible. List any lint findings still standing in one line each.

---

## Rules

- Never commit; the roots this writes to are gitignored working material.
- Never check out or change a branch; you only record the branch name.
- Each entry stands alone: pickup reads only the top one, so nothing may depend on an older entry or an archive.
- The pointer is written only by `handoff-pointer.py`, and only after the handoff file is final.
- A script failure is a stop, not a detour.
