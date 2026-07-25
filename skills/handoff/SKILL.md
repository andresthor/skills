---
name: handoff
description: >-
  Capture the current work session as a handoff a fresh session (or a different agent, or a
  teammate) can resume from — state now, next steps, open decisions, key paths — and drop a
  well-known pointer so pickup finds it with zero guessing. Use when wrapping up a session, handing
  off work, running low on context, or when the user says "hand this off", "write a handoff",
  "save state before I stop", or "note where we are for next time". Pair skill: pickup.
argument-hint: "[project-slug] [status note or extra context]"
allowed-tools: Bash(git *), Bash(mkdir *), Read, Glob, Grep, Write, Edit, AskUserQuestion
metadata:
  version: 1.0.0
---

# Handoff

Write down enough state that a fresh, low-context session can pick this work up without re-deriving anything. You produce two things: the **full handoff** (project-scoped, keeps its history) and a tiny **pointer** at a well-known location so the next session finds the handoff without being told where.

The next reader may share none of your context. Assume nothing is in memory — the branch, the paths, the "obvious" next step all have to be on the page.

## What goes in — four tiers

Handoffs are read by agents, not humans. Sort every fact before writing it:

1. **Resume-critical** — state, ordered next steps, open decisions, key paths, active watch-outs. This is the entry. Nothing else is.
2. **Reference** — run records, SHA maps, validation history, rationale. One-line pointer in the entry; the body lives in other project-dir files. Never pasted into the entry.
3. **Dead** — superseded decisions, resolved blockers, stale SHAs. Don't carry them into the new entry. Anything harmful to re-read ("do not re-add X") becomes one line in `decisions.md` (Step 5), not repeated narrative.
4. **Fluff** — narrative, praise, restated context. Never written.

---

## Step 1 — resolve where the handoff goes

handoff.md is project working-material, not skill output, so it lives in a project dir — not an `output/` bucket. Resolve the root in this order, and remember which case applied: pickup resolves the pointer in the same order, so the two stay in sync.

1. If the user's instructions (including their local context file) declare where generated, non-committed working files go — put the project dir under that, and the pointer alongside it as `HANDOFF.md`.
2. Else, if `.context/` exists at the repo root — use the reserved locations: the full handoff goes in `.context/projects/<YYYY-MM>/<NN-slug>/` (see Step 4 for its name), and the pointer is `.context/HANDOFF.md`. Follow `.context/AGENTS.md` if present.
3. Else — no declared root and no `.context/`: ask once where to save (use a structured question dialog if your tool has one). If you cannot ask, fall back to the repo root: `handoff.md` for the full handoff and `HANDOFF.md` for the pointer, side by side. Write the pointer even here — pickup checks the repo root last, so a pointer-less handoff is one nothing can find. Say which paths you used.

## Step 2 — resolve the project folder

Project dirs are grouped by month and numbered within it: `projects/<YYYY-MM>/<NN-slug>/`. Resolve the slug first:

1. If the user passed a slug, use it.
2. Else, if an existing `projects/<YYYY-MM>/<NN-slug>/` already matches the current branch (or one is clearly the active effort), **reuse it** — don't fork a new project dir.
3. Else, derive a slug from the branch name: drop trailing issue-ids, kebab-case, keep it short.
4. If still ambiguous, ask.

Creating fresh: place the dir under the current month (`YYYY-MM`), with the next `NN` in that month (`01-` if the month has no projects yet).

## Step 3 — gather the state

Read the real state; don't rely on what's in the conversation:

- `git rev-parse --abbrev-ref HEAD` — the branch (goes in the pointer).
- `git log --oneline -5` and `git status --short` — recent commits and uncommitted work.
- Skim any existing project-dir material (plan, notes, prior handoff) so the new entry continues the trail instead of repeating it.

## Step 4 — write the full handoff

Find the project's handoff file: one running file per project, appended over time — not a new file per session. Locate it, then name a fresh one:

1. If a handoff file already exists in the project dir (`handoff.md` or an `NN-handoff.md`), use it — keep its existing name.
2. Creating fresh: if the dir already uses `NN-slug` numbering, give it the next number (`NN-handoff.md`); otherwise `handoff.md`.

Append to that file, **newest entry on top**, older entries kept below a `---` divider (history leaves this file only via the archive gate in Step 6). Each entry:

```markdown
## Handoff YYYY-MM-DD

**State now** — what's done, what's committed (with SHAs), working-tree status.

**Next up** — ordered concrete steps; the first one should be startable cold.

**Open decisions / blockers** — anything unresolved, with the options if known.

**Key paths & commits** — files, dirs, commit SHAs the next session needs.

**Watch-outs** — traps, gotchas, things that look done but aren't.
```

Keep it specific and skimmable. The test is whether a stranger could start without asking you a question. "Continue the migration" fails it; "port `users` and `sessions` to the new schema in `db/migrations/004`, then run the backfill against staging" passes.

**Budget: ~30 lines per entry.** Over budget means tier-2 content is pasted where a pointer belongs — demote it, don't grow the entry.

## Step 5 — update decisions.md

Standing decisions and watch-outs that outlive one session live in the project dir's `decisions.md`, not in entries. One line each, updated in place: add new standing items, delete superseded ones. Never re-type a standing item into a handoff entry — pickup reads both files.

**Scope gate — decisions about the project, never about you.** A line qualifies only if it records a settled call about the work itself — design, scope, or process choices and don't-re-raise items — ideally attributed to whoever made it. Never write:

- your own behavior, workflow, or communication preferences ("doc style: concise", "spawn agents from the main session only");
- lessons from your own mistakes or tooling habits ("always fetch before citing a clone");
- anything that belongs in the user's instruction files — adding it there is the user's call.

When in doubt, leave it out: a missing line costs one question; a junk line pollutes every future pickup.

## Step 6 — enforce the size gate

If the handoff file now exceeds ~180 lines, move every entry except the top two to an `-archive` sibling of the handoff file (`handoff-archive.md` or `NN-handoff-archive.md`), newest-on-top, **verbatim** — the archive is cold storage, never rewritten or summarized. This is mandatory, not a judgment call.

## Step 7 — write the pointer LAST

Only after the full handoff is written, update the pointer resolved in Step 1 so it never points at a half-written file. The pointer is the autonomous-flow contract: a fresh session with no memory reads *only* this and recovers everything, so it must be self-sufficient.

The pointer holds an **ordered list of active handoffs** — one per project, newest first. Multiple projects can run concurrently; pickup tries the top entry and falls back to others by branch match. To update: read the existing pointer, drop the entry for *this* project if present, prepend the new entry as `## 1`, renumber the rest. Other projects' entries are preserved — never clobber a handoff you didn't write.

```markdown
# Active handoffs

## 1
- project: <slug>
- branch: <git branch>
- head: <short HEAD sha>
- dirty: no | yes (<n> files)
- status: <one line>
- handoff: <path to the handoff file from Step 4, relative to the repo root>
- updated: YYYY-MM-DD

## 2
- project: <other-slug>
- branch: ...
- head: ...
- dirty: ...
- status: ...
- handoff: ...
- updated: ...
```

`head` + `dirty` are pickup's fast-path fingerprint: if the repo still matches them, pickup skips its reconciliation checks. Fill them from the repo at write time, never from memory.

## Step 8 — confirm

Tell the user the slug, the paths written (incl. decisions/archive if touched), and the one-line status — so they can eyeball it before the session ends.

---

## Rules

- The pointer holds an ordered list of active handoffs (one per project). Writing for an existing project moves its entry to the top; writing for a new project prepends it. Never clobber another project's entry — each project's full history lives in its own project dir.
- Never commit anything — the working roots this writes to (`.context/`, personal output roots) are gitignored.
- Don't auto-checkout or change any branch; you only record the branch name.
