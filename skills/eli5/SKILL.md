---
name: eli5
description: >-
  Explain a change, issue, error, code snippet, concept, or anything else in plain, simple language —
  with ASCII diagrams and a step-by-step walkthrough. Use whenever the user says "eli5", "explain like
  I'm five", "explain this simply", "I don't get this", "break this down", "what does this do", or
  otherwise wants a confusing piece of code, a diff, a stack trace, an architecture, or a concept made
  easy to understand. Reach for it even when the user just pastes something baffling and asks "what is
  going on here?"
argument-hint: "[what to explain — omit if it's already in context]"
metadata:
  version: 1.0.0
---

## What to do

Take whatever the user is confused about — a code snippet, a diff, an error, a system, a concept — and explain it so a smart person who lacks *this specific* context can follow it. Not a toddler: assume general intelligence, just zero familiarity with the thing in front of them.

The goal is genuine understanding, not a wall of text. Someone reads your explanation and goes "oh, *that's* all it is."

## First, find the target

If the user named or pasted something, explain that. If they just said "eli5" with nothing attached, explain the most recent meaningful thing in context — the last diff, the error you were both staring at, the function under discussion. When it's genuinely ambiguous, ask one short question rather than guessing wrong.

## How to explain

Lead with the punchline. One or two sentences capturing the whole thing before any detail — people understand the parts faster once they know what the parts add up to.

Then build up from what the reader already knows. Anchor unfamiliar ideas to familiar ones; a good analogy does more work than three paragraphs of precision. Name jargon once, in plain words, then move on — don't pretend the term doesn't exist, but don't hide behind it either.

Stay concrete. Real values, real names, a real example flowing through the system beats abstract description. If something is the way it is for a reason, say the reason — the "why" is usually the part that was actually missing.

Be honest about size. A one-line fix gets a few sentences, not a manufactured five-section report. Match the explanation to the thing; padding a simple answer to look thorough just buries the point.

## Draw the picture

Most things worth explaining have a shape — a flow, a before/after, a hierarchy, a sequence. When there's a shape, draw it. An ASCII diagram lands an idea faster than the equivalent prose, and it's the difference between "I read your explanation" and "I get it now."

Reach for a diagram when you'd otherwise describe how data moves, what changed between two states, how pieces nest, or what happens in what order. Skip it when the answer is genuinely just a sentence — a diagram of nothing is noise.

Keep them small and labeled. A few boxes that are instantly legible beat an elaborate schematic nobody parses.

**A change (before → after):**
```
BEFORE                          AFTER
  request                         request
    │                               │
    ▼                               ▼
[ handler ] ── parses ──┐       [ handler ]
    │                   │           │
    ▼                   │           ▼
[  db   ]  <── raw ─────┘       [ validate ] ── rejects bad input
                                    │
                                    ▼
                                [  db   ]  <── only clean data
```

**A flow (how a thing moves through the system):**
```
user types URL
      │
      ▼
[ browser ] ──DNS lookup──> [ resolver ] ──"where's example.com?"──> [ DNS ]
      │                                                                 │
      │  <─────────────────── 93.184.216.34 ───────────────────────────┘
      ▼
[ connect + request ] ──> [ server ] ──> HTML back to browser
```

**A hierarchy or layout (how pieces nest):**
```
Request
 ├─ headers
 │   ├─ Authorization   <- the token lives here
 │   └─ Content-Type
 └─ body
     └─ { "user": ... } <- this is what failed to parse
```

Use whatever shape fits — these are starting points, not a fixed catalogue.

## Structure it

Structured formatting is part of the job — it's what makes an explanation scannable instead of a slab. Use it to mirror the actual structure of the thing.

- **Step-by-step / walkthrough** — number the steps when order matters (how a request flows, how to reproduce a bug, what to do next). Each step says what happens and, where it helps, why.
- **Short paragraphs** for the connective narrative — one idea each.
- **Bold** the key term or the one thing that matters in a line, so a skimming reader catches it.
- **Inline `code`** for anything that appears literally in the code — names, values, flags.

Don't over-format. Bullets for genuinely parallel items, prose for reasoning. A document that's all bullets is as hard to read as one that's all prose.

## A rough shape to aim for

Adapt freely — this is a default, not a template to fill mechanically:

```
**The gist:** one or two sentences — the whole thing in plain words.

[ASCII diagram, if there's a shape worth drawing]

**Walkthrough:**
1. First thing that happens / first piece — what and why.
2. Next thing — what and why.
3. ...

**Why it matters / what to do:** the so-what, when relevant.
```

## What to avoid

The failure mode is explaining *at* someone instead of *to* them. Restating the code in slightly longer English — "this function takes a parameter and returns a value" — teaches nothing; explain what it's *for* and why it works the way it does. Don't smuggle in unexplained jargon, don't inflate a small answer to seem rigorous, and don't draw a diagram where a sentence would do. If you finish and it still sounds complicated, you haven't understood it well enough yet — go again.
