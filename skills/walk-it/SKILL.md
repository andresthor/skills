---
name: walk-it
description: >-
  Guide the user step-by-step through code, a diff, a plan, a feature, a flow, a ticket, or how to
  test/verify something — one step at a time, at their pace, with a map of where they are. Use this
  whenever the user says "walk me through", "walk me through these changes", "take me through it",
  "step me through", "guide me through", "give me a tour of", "onboard me to", "how do I test
  this", "how do I try this", "how do I verify this", or any variant where they want to be guided
  through something or told how to do or test it. Also use it for preparing an
  onboarding walkthrough for a teammate. Reach for it even when the user only implies they want
  orientation — "ok now what?" after a plan, "how do I actually use this?", "show me the happy
  path". Distinct from eli5 (which explains what something is in one answer) — walk-it takes the
  user through it.
argument-hint: "[what to walk through — omit if already in context]"
metadata:
  version: 1.2.0
---

## What to do

Take the user through something — a flow, a diff, a plan, a feature, how to test or use it — so they come out oriented: they can picture the whole thing, know where each part lives, and could explain it to someone else. Someone who says "walk me through this" is asking to be *taken through* it at a pace they control. So unless the whole thing is trivially small, give one step per response and let the user move you on. Handing over the finished list in one go turns a walkthrough into a document, and that is the failure this skill exists to prevent. Don't offer an all-at-once version either; only produce one if the user asks for it unprompted ("just give me the whole thing").

## Find the target

If the user named something or passed an argument, use that. Otherwise infer from context: the last diff, the plan under discussion, the feature just implemented, the ticket being looked at. If it's genuinely ambiguous, ask one short question.

Read before you walk: the relevant files, the diff, the issue. A walkthrough that sounds confident and gets details wrong is worse than none. Take your facts from the code, not from docs about it. When the two disagree, walk what the code does. Correcting yourself mid-walk costs the reader more than the check would have.

A detailed request tells you **what to cover and what to emphasise**. It doesn't dictate the opening or the format. If the user lists files or stages, cover them, but order the walk along the flow itself. If they name a theme ("I want to understand the validation rule"), carry it as a lens through the steps and point it out where it shows up. Don't make it step 1.

## Tour or procedure

Decide which one you're giving, because they read differently:

- **Tour** — "how does X work", onboarding, a diff or feature to understand. The goal is a mental model. Steps follow the flow (the user's journey, or the path data takes) from where it starts to where it ends. Each step explains what happens there and why.
- **Procedure** — "how do I test/try/verify/set up X". The goal is doing. Steps are actions with expected results: where to go, what to type or click, what success looks like. For example: "open `/settings`, fill in Name, click Save. You should see a success toast." Put setup first: what to install, run, or point at before anything else, and the safe local or test environment before anything that touches real accounts or data.

Many walks mix the two (a tour that ends with "try it yourself"). That's fine; lead with whichever matches what the user asked.

## Size it

Look at the shape before writing anything: how many real stages are there, and does any stage carry sub-structure? This is your call to make silently; never ask the user.

- **Trivial** (up to 3 short steps, no sub-structure, no flow worth drawing): answer inline as a short numbered list. Don't pace three sentences across three turns.
- **Everything else**: walk it, one step per response.

## The first response

The first response orients before it details. It contains, in this order:

1. **One or two sentences** on what this flow or change is for, and why it exists.
2. **A map**: a small diagram of the whole thing — the parts involved and how they connect (see Diagrams). This is the picture the user will hang every later step on.
3. **Step 1**, starting where the flow starts: the first thing the user does or the first thing the system does. Don't start with the safeguards, the config, or the edge cases.

Leave out preamble about the repo or the process ("the docs here describe another branch", "I checked the tests first"). Mention context like that only if it changes what the reader will see, and then in one line.

The same goes for things you notice while reading that aren't what the user is trying to understand, such as docs that drifted from the code or an unrelated gap. Mid-walk they pull the reader away from the thing they're learning, so keep them off the main path and mention them at the end if they're worth knowing. Something that bears directly on what they asked, like a risk in the change they're looking at, belongs in the step it concerns.

## Writing a step

Each step is one idea and fits on one screen:

- **The idea first, in plain words.** What happens here and why it matters, as if you were saying it out loud to someone sitting next to you.
- **Then where it lives**: the file, function, route or command that matters. Name what the reader needs to find it, not every identifier nearby. A paragraph dense with inline code is hard to read in a terminal and buries the point.
- **What to notice**: the one detail that's surprising, easy to break, or load-bearing.
- **A small diagram** when the step itself moves through a flow or changes state.

Pitch the detail to the reader, and read who that is from the request and the conversation. Someone new to the code needs the shape before the names. Someone who just watched you change it, or works in it every day, wants to know exactly where things are and what might break. Either way, lead with the idea and keep each step to one idea. Leave out what doesn't help *this* reader: line numbers, commit hashes, platform quirks, and references to docs or numbered rules they haven't seen (state the rule instead). Middle steps tend to fill up as the walk reaches the dense part of the code. If a step runs past a screen, it's two steps.

**Hands-on parts:** only show commands you've checked actually work. If you can't check one, say so. Don't debug in front of the reader. If something breaks while you prepare, fix it or leave it out.

**When reality differs from the walk** (the user says "I don't see the toast"): stay on that step, help sort it out, and continue from there once it's resolved.

## Progress line and footer

Open every paced step with a progress marker, so the user always knows how long the walk is and where they are. Write it as plain text (a bold label, then the dots on the next line), not inside a code block:

**Step 2 of 5 — Wire up the handler**
●●○○○

The label names the current step only. Never list or preview later steps: a count is orientation, a preview is the list this skill exists to hold back. Commit to a total before step 1. If it genuinely changes, say so in one line ("this splits in two, so 6 total now").

Close every paced step with one quiet line of options instead of a question. Make it plain italic text, not a code block, so it sits in the background:

*next · go deeper · back · ask anything*

A question like "Ready for step 3?" invites a reflexive yes and reads as a push. The options line tells the user what they can do and leaves the pace to them.

**A step stays open until the user moves on.** Questions and tangents are answered within the current step, under the same progress line. The counter doesn't advance. Plain-language navigation works too: "skip this", "jump to the database part", "stop here". Honor it and keep the progress line accurate.

- **"Go deeper"** means more on the same idea: how it works underneath, why it's built that way, a concrete example or failure case. It doesn't mean adjacent topics or things you found along the way.
- **"Back"** re-shows the previous step, marked as a recap (e.g. "Step 2 of 5 — recap"). Condense it to what matters; the user has seen it once.

Skip the progress line and footer for trivial inline walkthroughs.

## Diagrams

Draw generously. A small diagram of the flow is usually the fastest way for someone to see the whole shape, and walkthroughs that open without one leave the reader assembling the picture from prose. Draw when there's a flow, a sequence, a request path, a state change, or a before/after. Skip a diagram only when the thing has no shape (a single setting, a one-line change).

If an `ascii-diagrams` skill is available, load it before drawing the first map. Use its direct mode for *how* to draw (character set, sizing, quality checks); *whether* to draw is decided here. Otherwise: keep diagrams small and labelled, a few boxes rather than a schematic. Label arrows with what moves along them. Keep them under ~70 columns so they don't wrap in a terminal.

**Map, not itinerary.** The first-response map shows the system: the parts and how they connect. It doesn't label which step covers what, since that would preview the walk. Later steps can re-show the map with a "you are here" marker:

```
browser ──POST /reset──▶ api ──enqueue──▶ mailer
                          │
                          ▼
                     tokens table    ◀── you are here
```

A table works for mappings (input → output, response → action). Prefer those to inventories of every field or file.

## Ending

After the last step, close in two or three lines: what the user now has (the one-sentence version of the whole flow), plus anything worth exploring next, offered as options (failure paths, a related flow, trying it locally). No full recap of every step.

## Tone

Clear, direct, sequential. Assume the user knows their craft; they want orientation in *this* thing, not a lesson in general concepts. Say what happens, say why, show where, move on.

The right mental model: you're the person who knows this codebase well, the user just sat down next to you, and they asked "ok, take me through it."

## Invoking walk-it

If you're writing a prompt that will trigger this skill (for example, preparing onboarding walks for a teammate), keep it short. Name the flow, who it's for, and whether the goal is understanding or doing: "/walk-it the checkout flow, for onboarding a new teammate". The skill finds the code itself. Listing file paths and required stages adds little, and pulls the walk toward covering everything listed instead of what matters most.
