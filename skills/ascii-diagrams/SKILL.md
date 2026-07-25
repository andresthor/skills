---
name: ascii-diagrams
description: >-
  Draw ASCII diagrams, or audit a markdown document (PR description, technical spec, RFC, design
  doc, README) and propose the ones that meaningfully speed up the reader. Use whenever the user
  asks for a diagram of something specific — "draw me a diagram of this", "diagram this
  architecture", "show this flow as ASCII" — or wants a markdown file's readability improved with
  diagrams, asks to "add diagrams to" a doc, says a doc is hard to follow, or wants visuals for an
  architecture / flow / state machine / dependency graph / data layout in a doc. Also use
  proactively after drafting a long markdown doc when key relationships are buried in prose.
argument-hint: "[path-to-markdown-file | what to diagram] [instructions]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(wc:*), Bash(ls:*)
metadata:
  version: 1.0.0
---

# ASCII Diagrams

A diagram earns its place by answering a question the reader is already asking, in less time than prose can. Most documents do not need one. Some need three. Your job is to figure out which is which and draft the ones that survive.

## Two modes

The mode is set by the user, not by you.

- **Audit** (default) — the user pointed at a document and asked whether it needs diagrams. You decide what earns a place. Everything below applies.
- **Direct** — the user asked for a diagram *of a specific thing*. The decision is already made. Skip the necessity work: no zero-default, no Step 2 disqualifiers, no substitution test, no plan-and-approve. Draw the thing, and draw it well.

Direct mode still runs Step 3 (name the relationship before picking a shape), Step 4 (character set), and the quality tests in Step 5 — cold-read, size ceiling, decoration scan, label sanity, consistency. Those make a diagram good; they don't argue about whether it should exist. **Never answer a direct request with "no diagram is justified here."**

## The single most important rule

**Default to zero diagrams** (audit mode). Then make each candidate fight its way in. If you cannot finish this sentence — "This diagram lets the reader answer *<one specific question>* in under 10 seconds, faster than the surrounding prose can" — do not draw it.

A diagram that restates a sentence is decoration. A diagram that adds visual weight without adding structure is decoration. A document peppered with decorative diagrams reads *worse* than the same document without them, because the reader has to parse each one before realizing it didn't help.

Calibrate volume to the doc's structural complexity, not its length:

- A 30-line bug-fix spec: usually **0**. Maybe 1 if there's a non-obvious branching flow.
- A 200-line feature spec: typically **0–2**.
- A 1000+ line architecture doc: typically **2–5**, never more than ~7.

If you find yourself proposing one diagram per section, stop and cut.

## Workflow

### Step 1 — Read the document and identify its shape

Read the input file. Note:

- **Doc type** (PR description, RFC, spec, README, design doc) — this hints at rendering medium.
- **Rendering medium** — does this live in a GitHub PR (markdown render), a `.md` in the repo (monospace viewer), an inline code comment, a plain-text email, a Slack thread? This drives the character set (see Step 4).
- **Existing diagrams** — note any already present, even weak ones. They may need replacement, not addition.
- **Length and density** — how many sections, roughly how many decisions does the reader need to track?

### Step 2 — Identify candidate spots (and the question each answers)

Scan the document for *relationships* — not for sections that "feel like they need a diagram." A diagram is justified when one of these is present and the reader has to hold it in their head to follow the doc:

| Reader's question | Candidate diagram family |
|---|---|
| "How does X work end-to-end?" | Sequence, linear flow, pipeline |
| "What happens when …?" (branches) | Branching flow, state machine, decision tree |
| "What depends on what?" (no time order) | DAG, call graph |
| "What is the structure of this thing?" | Nested boxes, tree, C4/architecture |
| "Where is the bottleneck / hottest cell?" | Bar chart, heatmap |
| "What does this byte/struct/memory look like?" | Bit field, memory layout, register layout |
| "How is this laid out on screen?" | Wireframe, table |
| "When does each piece happen?" | Timeline, Gantt, milestone chain |
| "What states does it have?" | State machine, state-transition table |

For each candidate, write down — for yourself — the **one sentence** the reader needs the diagram to answer. If you cannot, drop the candidate.

**Disqualify candidates aggressively:**

- The relationship is strictly linear and short (≤4 steps with no branches) → a sentence wins. *"Request flows: client → gateway → auth → service → DB."* beats a sequence diagram.
- The relationship is fully tabular with no spatial meaning → use a markdown table, not an ASCII diagram.
- The relationship is "list of things" → bullets win.
- The same diagram already exists nearby and is adequate.
- The reader already has the information from a code block immediately above/below.

### Step 3 — Match shape to relationship (do not pick a shape first)

For each surviving candidate, name the relationship **before** picking a shape. Read `references/diagram-guidance.md` for the heuristics — match dimensionality, let the reader's question drive the form, kill decoration. Then consult `references/diagram-catalog.md` for the menu of available shapes.

Two failure patterns to avoid:

- **Familiar-shape capture:** reaching for boxes-and-arrows because every diagram looks like that. A dependency graph is not a flow. A 2D heatmap is not a bar chart. If two relationships matter equally, you need two diagrams, not one clever hybrid.
- **Wrong dimensionality:** cramming 2D data into a 1D form (a bar chart hiding a per-day breakdown that should be a heatmap), or padding 1D data into a 2D form (a sequence diagram for a 3-step linear flow).

### Step 4 — Pick the character set

| Where the doc lives | Default character set |
|---|---|
| GitHub PR description, `.md` rendered in a monospace viewer | Single-line box-drawing: `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼` plus arrows `→ ← ↑ ↓ ▶ ▼` |
| Code comments, plain-text email, anything that may go through diff/grep/copy-paste | Pure ASCII: `- \| + / \ * . o` and `->` `<-` `^` `v` |
| Doc you fully control, where one element needs emphasis | Single-line, with **at most one** double-line `╔═╗` or block-shaded `█` element for that emphasis |

Avoid by default: 3D, shadowed, rounded corners, double-line everywhere, heavy block shading. They carry visual weight without information. The catalog shows them so you recognize them; the guidance tells you not to use them. Each glyph should either represent something or disambiguate structure — if `┌` already does the job, don't reach for `╔`.

### Step 5 — Draft each diagram, then apply the necessity tests

For each candidate, draft the actual diagram. Then, before keeping it:

1. **Cold-read test.** Look at the diagram alone. In under 10 seconds, can you state the relationship it shows? If not, the form is wrong (not the labels). Re-pick the shape.
2. **Substitution test.** Could a 1–2 sentence prose description replace it without losing structure? If yes, prefer the prose. Diagrams earn their keep on branching, cycles, parallelism, spatial layout, and relative magnitudes — *not* on linear sequences.
3. **Size ceiling.** Past ~15 nodes or ~7 swimlanes, the diagram is unreadable. Split by level of abstraction (C4-style: context → container → component) or cut.
4. **Decoration scan.** Remove every glyph that doesn't represent something or disambiguate structure. Shadows, decorative borders, redundant arrows.
5. **Label sanity.** Every node and edge that needs a label has one. Concrete values where applicable (`220ms`, `pending → processing`). No emoji inside diagrams.
6. **Consistency.** Don't mix arrow styles within one diagram. Don't mix character sets (pure ASCII *or* box-drawing — pick one per diagram).

If a diagram fails any test, either redraw it or drop the candidate. Dropping is honorable.

### Step 6 — Propose the plan before editing

Do **not** start editing the file yet. Show the user a plan first. Format:

```
Proposed changes to <path>:

1. INSERT after "<short anchor text>" (around line N):
   Type: branching flow
   Reader's question: "What happens when the cache misses?"
   [draft of the diagram, fenced]

2. REPLACE existing diagram between lines N–M:
   Reason: current diagram is a 3D box that adds no structure
   Type: nested architecture
   Reader's question: "How are the auth components nested?"
   [draft of the diagram, fenced]

3. SKIP — considered a sequence diagram for the request path,
   but the prose "client → gateway → auth → DB" is shorter
   and clearer.
```

State explicitly which candidates you skipped and why. The skip list is a feature: it shows the user you considered and rejected, rather than missing the spot.

Wait for the user's go-ahead. They may revise individual diagrams, ask for a different shape, or cut some. Iterate on the plan, not the file.

### Step 7 — Apply the approved changes

Once approved, use `Edit` (preferred — preserves the rest of the document exactly) to insert or replace each diagram. Wrap each diagram in a fenced code block (```` ``` ````) so it renders monospaced everywhere:

````markdown
**<bold-label-describing-what-it-shows>:**

```
<diagram>
```
````

The bold label above the diagram is required. It tells the reader what they're about to look at before they parse it.

After editing, summarize what changed in one or two sentences — file path, count of diagrams added/replaced/skipped. No restating each one.

## Things to never do

- **Never add a diagram per section.** If the document has 8 sections and you're proposing 8 diagrams, you have not done the work in Step 2.
- **Never use Mermaid, PlantUML, SVG, or HTML.** ASCII only. The skill exists because the doc is rendered in places that don't run Mermaid (terminal, plain-text email, code comments, some markdown viewers).
- **Never invent content.** If the document doesn't say what the components are or how they connect, ask the user — do not guess. A confidently wrong diagram is worse than no diagram.
- **Never silently remove the user's existing diagrams.** Replace them only if you're showing the replacement in the plan and explaining why. If a user wrote a diagram, assume it is doing work until proven otherwise.
- **Never use emoji inside diagrams.** They render at variable widths and break alignment.
- **Never mix character sets within one diagram.** Pure ASCII and box-drawing don't compose; pick one.
- **Never reformat the surrounding document.** Touch only the diagram regions and any minimum amount of glue text needed for the diagram to fit.

## When the user gives you free-form instructions

`$ARGUMENTS` may include extra guidance — *"focus on the auth section"*, *"the doc will be pasted into Slack so use pure ASCII"*, *"don't touch the existing flowchart, the whole doc leans on it"*. Treat these as constraints that override the defaults above.

If the user asks for diagrams for a specific section, still apply the necessity tests inside that section — don't add a diagram just because they pointed at it. Surface a "no diagram justified here, but here's why" answer if that's the honest read.

## Reference files

- `references/diagram-catalog.md` — the menu of available shapes, organized by purpose (containers, hierarchy, flow, state, data viz, technical, UI, time, specialized). Use this once you've named the relationship in Step 3.
- `references/diagram-guidance.md` — the rules of thumb: identify the relationship first, match dimensionality, let the audience's question drive it, respect the rendering medium, kill decorative elements. Read this before Step 3 if you're unsure which family to reach for.
