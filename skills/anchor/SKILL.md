---
name: anchor
description: >-
  Distill the current conversation's hard-won mental model(s) it can be what you just discussed
  or if no argument is given, the whole session context. When a topic is named, the named
  argument only — into a one-line-bullet cheat sheet the user can skim to reload context fast
  ("cliff notes for executive-function loading"). Use whenever the user says "anchor this", "add
  this to the cheat sheet", "write down these mental models", "make me cliff notes", "capture
  this so I don't have to re-derive it", or after a long clarifying discussion asks to save the
  understanding somewhere. Also reach for it when the user says a concept finally clicked and
  they want it kept. With arguments, focus on the named topics; with no arguments, judge what
  carried the most cognitive load in the recent conversation.
argument-hint: "[topics to anchor — omit to judge from the conversation]"
metadata:
  version: 1.1.0
---

# anchor

Re-deriving a mental model that was already built once is expensive; skimming ten one-line bullets is cheap. Your job: capture the identified model (argument) or models built in this conversation so the *next* session — or the user walking into a meeting cold — can "reload" the concept or concepts in under a minute.

This is NOT a summary of the conversation. It is a distillation of the **understanding** of one or more concepts — the things that were confusing until they weren't.

## What to capture

### INVARIANT — Argument sets the scope

**Arguments set the scope.** If the user named a topic or pointed at a thing ("that diagram",
"the yes/no path"), anchor **that argument only** — the unit is the argument, not the session.
Do not widen to cover the session: other topics, today's facts (ids, dates, numbers,
incidents), and who-said-what stay out **even when they feel load-bearing** — they belong in
the project's fact/doc files, not here. The scan list below applies only to grounding the
named argument.

**Argument-scoped sheets are SHORT.** A named argument typically needs 1 section and 2–5
bullets — if your draft exceeds that, you are smuggling in session material; cut it.

### No argument given

Only when NO argument is given: scan the recent conversation for moments where clarity was
expensive to reach:

- **Distinctions that resolved confusion** — "X and Y are two different moments, don't blend them". These are the highest-value anchors; if one distinction organizes everything else, lead the whole sheet with it.
- **Cardinalities and mappings** — 1:1:1 relationships, what scales with what, which object multiplies. Confusion here is quiet and expensive.
- **Anatomy** — the shape of a key/token/payload/config the user had to have explained.
- **Decided vs open** — one-liners for what's settled (so it isn't relitigated) and what's genuinely open (so it isn't assumed settled).
- **Guardrails** — "settled, don't reopen", priority ceilings, constraints from other teams. Collect these in a closing **Standing guardrails** section.
- **Corrections of prior belief** — where the user (or the docs) believed X and it turned out to be Y. State Y plainly; don't re-narrate the correction.

Leave out: narrative, process, who-said-what, anything the user never stumbled on. If it was never confusing, it doesn't need an anchor.

**Fresh-session test for every bullet:** would this line still be true — and still useful —
in a new session on this same project, without today's context? A bullet naming session
specifics (a teammate, an environment id, a probe result, a latency number) fails: that is a
fact, not a model. Cut it, or move it to the project's fact file.

**With arguments**: scope as above. **Without arguments** (only then): judge from the list.

## Where it goes

One sheet, merged over time — never a new file per invocation.

**First resolve the root**, in this order:

1. If the user's instructions (including their local context file) say where generated, non-committed files go — use that.
2. Else, if `.context/` exists at the repo root — use it, following `.context/AGENTS.md` if present.
3. Else — ask once where to save (use a structured question dialog if your tool has one); if you cannot ask, use the repo root and state where you wrote.

**Then place the sheet under that root.** Two cases:

- **An active project directory exists** — a project folder (under `projects/` or `research/`) that this session has already been writing into, or one the user named. The sheet is `anchor.md` inside it, alongside the effort it describes. A project path merely mentioned or read once does not count; when in doubt, use the bucket.
- **Otherwise** — the sheet goes in an `anchor/` bucket under the root, named `YYYY-MM-DD-<slug>.md`, where the slug names the topic.

**Merge — never duplicate.** Read the file before writing. Update an existing section in place when a topic recurs; replace bullets the conversation has contradicted (the sheet states current truth, not history); append new sections for genuinely new topics.

In a project directory there is exactly one `anchor.md`, so the merge target is obvious. In an `anchor/` bucket, glob `anchor/*-<slug>.md` first: if one matches, merge into it and **leave the filename alone** — the date records when the sheet was started, not when it was last touched. Create a new dated file only when no slug matches. A bucket full of near-duplicate sheets defeats the whole point, because then the user has to read all of them to find out what's currently true.

## Style contract (the whole point — hold it strictly)

- **One idea per bullet, one line each.** If a bullet needs two lines, it's two bullets or too much detail for a cheat sheet.
- **Bold the key term** in a bullet so a skimming eye catches it.
- **Lead with the most organizing distinction** — the one bullet that makes the rest make sense.
- Short `##` sections with plain names. A section is 2–6 bullets; more means split or prune.
- Tiny ASCII fragments only when a shape genuinely beats words (a 3-line mapping, an arrow chain). No elaborate diagrams — those belong in the full docs, which the sheet can point to. **The sheet may contain at most one ASCII fragment, at most 8 rendered lines.**
- Plain words. No unexplained jargon: the sheet must work when the reader has ZERO context loaded — that's its entire job.
- **When the argument names a diagram** (the yes/no path, a flow): the diagram itself goes on the sheet as the section's body — surrounding bullets stay ≤ 4.
- **Standing guardrails are FORBIDDEN in argument-scoped sheets** (they belong only to no-argument session scans). Never invent them for a named topic — the named topic absorbed no session guardrails.

## Example (shape, not content)

The subject below is invented. Read it for the shapes — an organizing distinction first, then cardinalities, anatomy, and guardrails last.

```markdown
# Cheat sheet — mental models (skim to reload context)

## The two delivery moments (don't blend them)
1. **Accept** ("did we take the event?", once) → 202 and a queue write. Decided.
2. **Deliver** ("did the subscriber get it?", retried) → the backoff debate lives here.

## Cardinalities (1:N:N)
- 1 event : N subscriptions : N attempts. Attempts scale with **retries**, not subscribers.
- Pausing a subscription stops **new attempts only** — in-flight ones still land.

## Payload anatomy
- `id` is the **attempt** id, not the event id. Dedupe on `event_id`.

## Standing guardrails
- Ordering: not guaranteed, by design. Settled — don't reopen.
- Retry ceiling is 5. Raising it needs a capacity review first.
```

## After writing

Reply with two or three sentences: where the sheet lives, which sections were added or updated, and — if you merged — what got replaced. Don't paste the sheet back into the chat; the user just wrote it with you.
