---
name: handoff
description: >-
  Capture the current work session so a fresh session, another agent, or a teammate can resume from cold — update the
  project's living docs (state, decisions, notes) in place, append one short entry to the handoff log (what changed,
  where it stopped), and register it in a well-known pointer so pickup finds it with zero guessing. Use whenever work is
  being paused or handed over, even if nobody says "handoff": wrapping up, running low on context, "I'm about to
  clear/compact", "checkpoint this", "save state before I stop", "note where we are for next time", "write a handoff",
  or closing out a finished project. Pair skill: pickup. Needs git and python3.
argument-hint: "[project-slug] [--next '<one action, ≤80 chars>'] [--close]"
allowed-tools: Bash(git *), Bash(gh pr view *), Bash(mkdir *), Bash(cp *), Bash(mv *), Bash(python3 *), Bash(bash *), Read, Glob, Grep, Write, Edit, AskUserQuestion
metadata:
  version: 3.0.0
---

# Handoff

Leave the project so that a fresh, low-context session can continue without re-deriving anything. Truth lives in the project's living docs, which you update in place. The handoff log gets one short entry that records what changed and where work stopped. The pointer tells pickup where all of it is.

The next reader shares none of your context and pays for every character you write. They also trust what you write. A question you invent or a next step you guess becomes their first task, and it carries forward. **Write nothing to fill a slot.** Every optional line is left out when there is nothing real to put in it.

## The project docs

Each project dir holds four primary docs, prefixed `00-`. Every one carries its own rules in its header, and those rules win over this skill where they are stricter.

| file | holds | how it changes |
|---|---|---|
| `00-state.md` | current truth: aim, known, to verify, unknown, prior work | edited in place, never a history |
| `00-decisions.md` | settled calls, one per line, tagged with who made them | edited in place, `[user]` lines only on the user's word |
| `00-notes.md` | footguns, gotchas, process fixes | edited in place |
| `00-handoff.md` | the session log, newest on top | appended, never edited, rotated to an archive |

Everything else is a numbered doc or dir (`01-architecture.md`, `02-research/`): plans, rationale, research, reference. The `00-` docs point at them instead of repeating them. If the project dir has an `AGENTS.md`, read it before writing anything. The user owns it, so never edit it unless they tell you to.

Fresh copies of all four, plus `AGENTS.md`, live in `templates/` beside this file.

## Scripts

Four scripts ship under `scripts/` beside this file (the skill's base directory is announced when it loads). They are python3 stdlib and bash. They never commit, never touch git state, and never write outside the handoff files (lint's `--snapshot` writes one file to the system temp dir).

| script | does |
|---|---|
| `handoff-fingerprint.sh [repo]` | prints `{branch, head, dirty, now, session}` from git, the clock and the environment |
| `handoff-lint.py <project-dir>` | checks the top entry and the `00-` docs, splits findings into yours (errors) and pre-existing (warnings) |
| `handoff-rotate.py <handoff.md>` | archives old entries once the file passes 180 lines |
| `handoff-pointer.py <HANDOFF.md> upsert\|check\|show\|remove\|prune\|migrate` | the only thing that writes the pointer |
| `handoff-pointer.py locate [--repo <root>] [--slug S \| --branch B]` | finds the pointer, selects the entry, resolves the handoff path in one call |

`session` is the first 8 characters of Claude Code's `CLAUDE_CODE_SESSION_ID`, a short id like a short SHA. It is absent under other agents, and everything that uses it then leaves it out. Never write a full session id.

If a script fails, report the error and stop. Do not hand-edit around it.

---

## Step 1 — resolve where the handoff goes

The handoff is project working material, not skill output, so it lives in a project dir. If a `.context/AGENTS.md` exists, follow it. Resolve the root in this order (pickup resolves the pointer in the same order, so the two stay in sync):

1. The user's instructions declare where generated, non-committed working files go → the project dir goes under that root, the pointer beside it as `HANDOFF.md`.
2. Else, `.context/` exists at the repo root → project dir `.context/projects/<YYYY-MM>/<NN-slug>/`, pointer `.context/HANDOFF.md`.
3. Else, ask once where to save (with a structured question if your tool has one). If you cannot ask, use a `handoff/` dir at the repo root for the project and `HANDOFF.md` at the repo root for the pointer. Say which paths you used.

When a pointer already exists, find it with one call: `handoff-pointer.py locate`. Do not hand-roll the lookup with `ls`/`readlink`/`head`.

## Step 2 — resolve the project dir

Project dirs are grouped by month and numbered within it: `projects/<YYYY-MM>/<NN-slug>/`.

1. The user passed a slug → use it.
2. Else, a project dir under any month already matches the current branch, or is clearly the active effort → **reuse it**, even across a month boundary. A dir whose top entry says the work was superseded or moved elsewhere is not the active effort. Ask rather than resurrecting it.
3. Else, derive a slug from the branch name: drop trailing issue ids, kebab-case, short. On `main`/`master` there is nothing to derive from, so ask.

Creating fresh: under the current month, next `NN` in that month (`01-` if empty). Slugs are lowercase kebab-case. Copy every file from `templates/` into the new dir and write a `CLAUDE.md` holding the single line `@AGENTS.md`, so Claude Code loads the rules too.

**An existing dir without `00-` docs** (an older `handoff.md` / `decisions.md` layout): ask once whether to adopt the `00-` layout. On yes, follow `references/migrate.md` §Project dir. On no, keep the existing file names and apply everything below to them.

## Step 3 — read

Read the real state. The conversation is not it.

- `bash <scripts>/handoff-fingerprint.sh` gives branch, head, dirty, now and session. The first three go in the pointer verbatim. `now` and `session` stamp the entry and any decision you add.
- `git log --oneline -5` and `git status --short` show what landed and what is uncommitted.
- `AGENTS.md` and the four `00-` docs, so your edits fit what is already there.

Read the previous handoff entry for its heading only. **Never copy its lines forward.** An open question or a next step in an old entry was that session's guess. If it still matters, it lives in `00-state.md`, and the docs decide whether it does.

## Step 4 — update the living docs

Make the docs true. Follow each file's header rules:

- **`00-state.md`**: replace what changed. A resolved unknown becomes one known line plus a pointer to where the detail lives. Delete what stopped being true. Tag every fact with its source.
- **`00-decisions.md`**: add a settled call only if it passes the scope gate below. Format `- [who] Decision. — <now> <session8>`, with `now` and `session` from the fingerprint. `<session8>` is left out when the fingerprint has no session.
- **`00-notes.md`**: add a footgun only if a future session would otherwise step on it.
- Anything longer than a line (rationale, research, run records, SHA maps) goes in a numbered doc, with one pointer line in the `00-` doc.

**Open questions.** One goes under Unknown in `00-state.md` only if the user raised it or it blocks a concrete step. A question the docs already answer, or one that came from your own misreading, is not open. Leave it out.

**Scope gate for decisions.** A line qualifies only if it records a settled call about the work: design, scope, process, don't-re-raise items. Never your own workflow or communication preferences, lessons from your own mistakes, or anything that belongs in the user's instruction files. A missing line costs one question. A junk line pollutes every future pickup.

If this session reverses a decision recorded in **another** project's decisions file, mark that line `SUPERSEDED:` there with one clause on why.

## Step 5 — append the handoff entry

The entry is the session's line in the log: what changed and where work stopped. It is history, so it must still make sense after the living docs have moved on.

````markdown
## 2026-11-05 14:30 fcfb4818
```diff
+ known: card not required for trial, verification is non-blocking
- unknown: IP fingerprinting feasibility → 03-research/fingerprint.md
+ decided: tiered onboarding
~ commits: 3f9c2a1..8e1d004
stopped: dashboard spec half-drafted in 02-dashboards.md
next: finish the dashboard spec
```
````

- **Heading**: `## <now> <session8>`, both from the fingerprint, never from memory. `<session8>` is left out when the fingerprint has no session.
- **Body**: one `diff` block and nothing else. The markers render coloured and leave no room for prose.
- `+ <noun>: <fact>` added, `- <noun>: <fact>` removed or resolved, `~ <noun>: <fact>` changed. The noun is a short lowercase label (`known`, `unknown`, `decided`, `commits`, `explored`, `dropped`). The fact is a few words.
- **Restate, never point at a `00-` doc.** Those change, so a pointer into them stops meaning anything. Point only at things that stay put: commits, numbered docs.
- `stopped:` is required, exactly once: where work paused, as a fact.
- `next:` is optional, at most once. Write it only when there is a real next step: one the user asked for, or the obvious continuation of half-done work. Never a question, never "optional …", never a placeholder.
- Write the lines from what this session did, never from the previous entry. A session that changed nothing writes only `stopped:`.
- One running file per project. If the dir already has `handoff.md` or `NN-handoff.md`, keep its name. New entries go on top, older entries stay below a `---` divider, and none is ever edited.

## Step 6 — lint

`python3 <scripts>/handoff-lint.py <project-dir>`. It reports ownership in its last line.

- **Errors are yours**: the entry, the line caps, and every doc line this session wrote (it knows them by the session id in a decision, or by the snapshot pickup took). Fix them and re-run, at most twice. Report any that still stand.
- **Warnings are pre-existing.** Fix one only if you are editing that line anyway.
- **A cap error (C1)** means a file passed the `<!-- max-lines: N -->` on its line 1. Trim first: merge duplicates, delete what stopped being true, move rationale to a numbered doc. If the project genuinely needs more room, ask the user to raise the cap. Never raise it yourself. Lint flags a changed cap line (C2) when pickup took a snapshot.
- Cut or move material. Never split one thought into fragments to satisfy a counter.

## Step 7 — rotate

`python3 <scripts>/handoff-rotate.py <handoff.md>`. Once the file passes 180 lines, it moves every entry but the top two to the `-archive` sibling, verbatim and newest on top. Running it on a small file does nothing, so run it every time.

## Step 8 — write the pointer, last

Only after the docs and the entry are final, so the pointer never names a half-written file. The pointer is a **locator, not a summary**. It holds one block per active project, newest first:

```markdown
<!-- handoff-format: 2 -->
# Active handoffs

## session-cache
- branch: feat-add-session-cache
- head: 3f9c2a1
- dirty: 0
- commits: 2
- state: in-progress
- next: finish the dashboard spec
- handoff: .context/projects/2026-08/03-session-cache/00-handoff.md
- updated: 2026-08-27
```

Write it with the script and nothing else:

```bash
python3 <scripts>/handoff-pointer.py <HANDOFF.md> upsert --slug <slug> \
  --branch <from fingerprint> --head <from fingerprint> --dirty <from fingerprint> \
  --state in-progress [--next "<the entry's next: line>"] --handoff <path from Step 5, relative to the repo root>
```

- `branch`, `head`, `dirty` are the fingerprint values exactly, with nothing appended. Pickup compares them byte for byte.
- `--next` mirrors the entry's `next:` line and is left out when the entry has none. The block then has no `next:` field.
- `commits` (branch commits beyond `origin/main`) is computed by the script, so do not pass it. `0` means planning-only work in uncommitted docs, and pickup skips the merge check for it.
- `state` is one of `in-progress | blocked | review | done | parked | superseded`. If the only remaining work is optional, the state is `done`.
- The script moves this project's block to the top, preserves every other block byte for byte, and refuses a `handoff:` path that does not exist. If it refuses, fix the input. Never edit `HANDOFF.md` by hand.
- If `HANDOFF.md` exists and its first line is not `<!-- handoff-format: 2 -->`, stop and follow `references/migrate.md` §Pointer.
- **`--close`**: the project is finished (merged, superseded, nothing next). Update `00-state.md` to say so, write a final entry whose `stopped:` says what merged or why it ended, then `handoff-pointer.py <HANDOFF.md> remove --slug <slug>`. The history stays in the project dir.
- If a new session continues work on a branch that already has a pointer block, update that block. Pickup resolves by branch and cannot tell two blocks on one branch apart.

## Step 9 — confirm

Tell the user: the slug, the files written, the `state:` and `next:` (or "no next"), and `read: <n> chars across the 00- docs` so the cost of the next pickup is visible. List any lint errors still standing in one line each.

---

## Rules

- Never commit. The roots this writes to are gitignored working material.
- Never check out or change a branch. You only record the branch name.
- Never invent content for an optional line. No next step, no open question, no change → no line.
- Never carry a line forward from an older entry. The docs are the memory, and the entry is the log.
- The pointer is written only by `handoff-pointer.py`, and only after everything else is final.
- A script failure is a stop, not a detour.
