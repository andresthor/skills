---
name: pickup
description: >-
  Resume work from a handoff — read the well-known pointer, open the full handoff, verify you're on
  the right branch, and summarize where things stand plus the next concrete step. Use at the start
  of a session, or when the user says "pick up where I left off", "resume", "what were we doing",
  "continue the last session", or "load the handoff". Pair skill: handoff.
argument-hint: "[project-slug] [go — start the next step without asking]"
allowed-tools: Bash(git *), Read, Glob, Grep, AskUserQuestion
metadata:
  version: 1.0.0
---

# Pickup

Recover a work session someone (maybe you, maybe another agent) wrote down with `handoff`. This is read-only: you gather and verify context, then hand the user a short orientation and a proposed next action. You do not start the work until they confirm (`go` is the one exception — see Rules).

---

## Step 1 — find the handoff

If the user passed a slug, skip the pointer: find the project dir under `projects/<YYYY-MM>/` whose `<NN-slug>` matches it (newest month first) and read its handoff file (`handoff.md` or an `NN-handoff.md` — there's one running file per project).

Otherwise, find the pointer. Check these locations in order — the same order `handoff` uses when deciding where to write, so the two stay in sync:

1. If the user's instructions (including their local context file) declare a root for generated, non-committed working files — look for `HANDOFF.md` there.
2. Else, if `.context/` exists at the repo root — read `.context/HANDOFF.md`.
3. Else, check the repo root for `HANDOFF.md` — the fallback `handoff` uses when it could not ask where to write.

Answer 1 from the instructions already in your context; don't go searching for them. Most repos that declare a root declare `.context/` anyway, so 1 and 2 name the same file — take the first one that resolves and move on rather than checking all three.

If none of those resolve, say so and ask which project to pick up. Don't guess.

Once you have the pointer, it holds an ordered list of active handoffs. Pick the entry by branch match:

- Check the current branch (`git rev-parse --abbrev-ref HEAD`).
- If it matches the top entry's `branch`, use that entry.
- If it doesn't, scan the remaining entries for a matching `branch`. If found, use that entry and tell the user: "top handoff is for `<X>`, but you're on `<Y>` — using `<Y>`'s handoff."
- If no entry's branch matches, list the slugs and ask which project to pick up. Don't guess.

Read the **first 120 lines** of the handoff file — it's newest-on-top. Also read `decisions.md` in the project dir if present — standing decisions and watch-outs live there, not in entries. Do NOT read `*-archive.md` files unless the top entry or `decisions.md` points into them.

## Step 2 — fingerprint check

Compare the selected entry's `branch`, `head`, and `dirty` lines against the repo (`git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD`, `git status --short`):

- **All three match** → the repo provably hasn't moved since the handoff was written. Skip Step 3; orient in two lines (where things stand + proposed next step) and ask to proceed.
- **Branch mismatch** (only when a slug was passed or the user chose a project whose branch differs from the current one) → **do not auto-checkout.** Surface it plainly: "this handoff is for `<X>`, you're on `<Y>`." Offer to switch (`git checkout <X>`) or to continue where you are, and wait for the call.
- **Head or dirty mismatch, or the entry has no `head:` line** (older format) → full flow, continue to Step 3.

## Step 3 — reconcile with reality (fingerprint mismatch only)

The handoff is a snapshot; the repo may have moved. Cross-check the cheap things:

- `git log --oneline -5` and `git status --short` — did the "next up" step already land? Is there uncommitted work the handoff didn't mention?
- Confirm the key paths the handoff names still exist.

Note any drift between what the handoff claims and what the repo shows — that's the highest-value thing you can tell the user.

## Step 4 — orient the user

Give a short summary, not a paste of the file. Short bullet points and sentences under ~15 words:

- **Where things stand** — one or two lines.
- **Branch** — confirmed match, or the mismatch and what you recommend.
- **Standing decisions** — only the ones that affect the proposed step (from `decisions.md`).
- **Drift** — anything that changed since the handoff was written.
- **Proposed next step** — the handoff's first "next up" item, adjusted for any drift, phrased as a concrete action you're ready to take.

Then ask whether to proceed with that step. Let the user redirect before you touch anything.

---

## Rules

- Read-only until the user confirms — no edits, no commits, no branch changes without an explicit yes (branch-switch offered in Step 2).
- `go` argument: start the proposed next step without asking — but only when explicitly passed this invocation, and only when nothing is off (fast path, or full flow with zero drift). A branch mismatch or any drift always stops for the user, `go` or not.
- Before starting any work — whether the user confirmed or `go` was passed — read the supporting material the handoff points at. A `plan.md` or `spec.md` in the project dir usually carries the detail the entry only summarizes, and starting without it means re-deriving decisions that were already made.
- Trust the repo over the handoff when they conflict; report the conflict rather than acting on the stale claim.
- Multiple projects can run concurrently — the pointer holds a list. If the user needs a project that isn't in the pointer, take the slug and read that project's handoff directly.
