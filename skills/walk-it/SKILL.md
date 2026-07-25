---
name: walk-it
description: >-
  Guide the user step-by-step through code, a diff, a plan, a feature, a ticket, or how to test/verify
  something — oriented toward doing or following, not just understanding. Use this whenever the user
  says "walk me through", "walk me through this/these changes", "walk it", "take me through it", "step
  me through", "guide me through", "how do I test this", "how do I try this", "how do I verify this",
  or any variant where they want to be guided through something or told how to do/test it. Reach for
  it even when the user just implies they want orientation — "ok now what?" after a plan, "how do I
  actually use this?", "show me the happy path". Distinct from eli5 (which explains *what* something
  is) — walk-it guides *what to do* with it.
argument-hint: "[what to walk through — omit if already in context]"
metadata:
  version: 1.0.0
---

## What to do

Guide the user through something — code, a diff, a plan, a feature, how to test or use it. The goal is that they follow along and come out oriented, not just informed. Steps are concrete and sequential; the user should be able to move through them without needing to figure anything out on their own.

The name is the instruction. Someone who says "walk me through this" is asking to be *taken through* it at a pace they control — not handed a document. Delivering the finished list in one response is the failure mode this skill exists to prevent.

## Find the target

If the user named something or passed an argument, use that. Otherwise infer from context: the last diff, the plan under discussion, the feature just implemented, the ticket being looked at. When it's genuinely ambiguous, ask one short question rather than guessing wrong.

If orientation is needed first (a large codebase area, an unfamiliar ticket), do a quick scan before walking — read the relevant files, check the diff, pull the issue. Don't skip this; a confident-sounding walkthrough that gets the details wrong is worse than none.

## Assess scope before you start

Survey the shape of what you're walking through before writing anything: how many real top-level stages are there (not sub-bullets — the actual stages a person moves through), and does any of them carry meaningful sub-structure? Three stages that each contain real work are not a trivial walkthrough; treat sub-structure as weight, the same as step count.

This assessment is yours to make silently. It decides delivery, and it is never a question you put to the user.

## Trivial scope (2–4 short steps, no sub-structure): give it inline

No dialog, no preamble — go. Numbered steps, one idea each, concrete.

Don't inflate small things. If someone asks "walk me through this 3-line change," give them three sentences in a list. Padding a simple answer with process is noise, and pacing three sentences across three turns is the same mistake wearing a different hat.

## Everything else: one step per response

Give step 1 and nothing else. End your response there. Do not write step 2, do not preview the steps still to come, do not append a summary of where the walkthrough is heading. Close with a short cue — "Ready for step 2?" or "Try that and tell me when you're ready to continue" — and stop.

Each step stands alone: what to do, what to watch for, and briefly why it matters. When the user comes back, give the next one the same way.

Two rules hold this together, and both matter:

- **Never offer a choice between paced and all-at-once.** There is no all-at-once mode to offer. Asking "want it one at a time or all laid out?" reintroduces the exact dump this skill is meant to prevent, and a model that can answer its own question will always answer it with the dump.
- **Never decide on the user's behalf that this one is fine to print.** "They're only reading, not doing" is not a reason to hand over the whole list. Reading is the most common case, and it is still a walkthrough.

The one exception is an explicit, unprompted request from the user — "just give me the whole thing," "dump it all." That's their call, so honor it. You never propose it.

## Testing walkthroughs

When the goal is "how do I test this" or "walk me through the happy path," the steps are *what to do in the app*: where to navigate, what to click or type, what to look for, what success looks like. Be concrete — not "check the form," but "open `/settings`, fill in the Name field, click Save — you should see a success toast."

Cover the main happy paths first, then any notable edge cases if they're worth knowing. Don't try to be exhaustive — pick the paths that give the best signal.

## Diagrams

When there's a flow, a sequence, or a before/after worth visualizing, draw it. Same conventions as eli5: ASCII, small, labeled. A short diagram that shows the path through the system or the order of operations is often worth a hundred words. Skip it when a list of steps is already clear on its own.

A diagram of the overall route is one thing you may show up front — a map is not the walkthrough, and seeing the shape helps the user know where they are. Showing the map does not license listing the steps.

```
step 1 → step 2 → step 3
             │
             └─ if X, skip to step 5
```

## Tone

Clear, direct, sequential. Assume the user knows the domain — they just want orientation, not a lesson. Don't explain what a function is if they asked how to test a feature; don't over-define terms they already know. Say what to do, say what to expect, move on.

The right mental model: you're the person who knows this codebase well, the user just sat down next to you, and they asked "ok, take me through it."
