---
name: plan-it
description: >-
  Unified implementation planner — decides WHAT is being built and produces a concrete, risk-scaled
  plan for HOW. Accepts a feature description, a spec file, a Linear issue or project (or another
  tracker, if you have a tool that reads it), and/or Figma URLs, folding design context in via a
  design-capture subagent. Triggers: planning an implementation, breaking a feature
  into tasks, turning an issue or spec into steps, choosing an architecture. Not for open research.
argument-hint: "[feature description, spec path, Linear issue/project, and/or Figma URL(s)]"
metadata:
  version: 1.0.0
---

# Plan-It: Unified Implementation Planning

A structured, level-scaled planning methodology that uses parallel agents and adversarial debate to produce implementation plans calibrated to a feature's risk and complexity. It accepts any mix of sources — a conversational brief, a spec file, a Linear issue or project, and/or Figma designs — and folds each in without over-planning a simple change or under-planning a risky one.

There is **no plan-mode gate** — approval is conversational. The Figma track delegates design capture to a subagent so design context lands on disk instead of in this orchestrator's window.

## What This Needs

The core planner needs nothing but the codebase and a conversation. Two optional tracks light up only when the tooling is present — check before you rely on either, and degrade as described rather than failing.

- **Issue tracker (optional).** Linear is the first-class path, via `mcp__linear__*`. Other trackers work the same way if you have a tool that reads them. With no tracker tool, ask the user to paste the issue body and treat it as a spec.
- **Figma (optional).** Needs Figma MCP access, and works best with a dedicated `figma-agent` subagent. Without either, ask the user for screenshots.

## How This Works

The user provides a feature to plan via any combination of:

- **Conversation or a free-text brief** — the default source.
- **A spec or plan file** — a path to an existing document.
- **A Linear issue or project** — an issue ID (`ABC-123`) or project name; another tracker works the same way.
- **Figma URL(s)** — one or more design links; captured by a design-capture subagent into the plan's `figma/` cache.

You drive a six-phase process (Phase 0 intake → Phase 5 summary), scaling effort to match the feature's risk profile.

---

## Core Principles

- **Calibrate effort to risk.** A basic feature gets a basic plan. Don't over-engineer planning for a straightforward change, and don't under-plan something that could break core flows.
- **No assumptions without confirmation.** If something isn't specified by the user, don't assume it's an acceptable tradeoff. Surface it.
- **Agents read sources directly.** Summaries lose nuance. Give agents paths and let them form their own understanding.
- **The adversarial agent earns its slot.** Their objections prevent groupthink and catch scope underestimation. Treat their arguments with the same weight as the others — but not as complete veto power.
- **Plans are for acting on.** Every step should be specific enough to implement. "Consider using a better pattern" is not a plan step.
- **The user's context is king.** A technically superior plan that ignores the user's constraints, timeline, or codebase conventions is not a plan worth having.
- **Figma is visual-only.** Trust it for layout, styling, structure, and visible copy — never for API field names, types, or enum values. Verify those against the codebase or SDK.

---

## Phase 0: Source Intake & Working Directory

This phase always runs first. Identify the sources, fetch what's fetchable, and establish the output directory.

### 0a. Resolve sources

Inspect the invocation (arguments and conversation) and classify each input:

- **Linear issue ID** (matches `ABC-123`): if a tracker tool is available, fetch the issue with relations included — `mcp__linear__get_issue` for Linear, the equivalent read call for another tracker. Read the full description, acceptance criteria, labels, linked/parent issues, assignee, priority, project. With no tracker tool, ask the user to paste the issue body and treat it as a spec file.
- **Linear project name** (any other identifier that resolves to a project): search via the tracker tool, read the project description, and list its child issues — each may carry its own criteria, labels, and Figma links. Treat the project description as high-level scope and child issues as the breakdown.
- **Figma URL(s)**: note them for Phase 0c. Also extract any additional Figma URLs found in the issue/project descriptions or comments.
- **Spec/plan file path**: read it as a primary source.
- **Conversation / free-text brief**: summarize the agreed direction and call out assumptions before proceeding.

If no source resolves to anything concrete, ask the user what they want planned before continuing.

### 0b. Establish the working directory

The plan's working directory (`<plandir>`) is `<projects-root>/<slugified-feature>/` — e.g. `.context/projects/billing-sync-retry/`. If a directory for this feature already exists there, reuse it (that's a plan revision, not a new plan). Create it if it doesn't exist.

Resolve `<projects-root>` in this order:

1. If the user's instructions (including their local context file) say where project working material goes — use that.
2. Else, if `.context/` exists at the repo root — use `.context/projects/`, following `.context/AGENTS.md` if present.
3. Else — ask once where to keep the plan (use a structured question dialog if your tool has one); if you cannot ask, use `projects/` at the repo root and state where you wrote.

### 0c. Capture Figma designs (conditional)

**Only if Figma URLs are present.** For each top-level Figma URL (or distinct screen group), spawn a design-capture subagent — a dedicated `figma-agent` if your setup has one, otherwise a general-purpose subagent instructed to capture design context via the Figma MCP (skip this track and ask the user for screenshots if no Figma access exists). Point it at `<plandir>/figma/` as its workspace directory. The agent caches its deliverables there — design tokens, screenshots, an ASCII mockup, and a codebase translation — using the minimum Figma MCP calls.

- Pass the agent the Figma target and the absolute `<plandir>/figma/` workspace path.
- Run agents for independent URLs in parallel; name each one.
- Once cached, **everything downstream reads `figma/` from disk** — the context-gathering agents in Phase 2, the plan in Phase 4, and the user. Nobody re-fetches from the MCP server unless the design genuinely changed.

This is the entire Figma machinery. Do not attempt exhaustive, formal component inventories or Build-vs-Reuse tables here — the capture agent's deliverables plus the level-scaled investigation below are sufficient. Scale the design rigor to the feature's level like everything else.

---

## Phase 1: Level Evaluation

**This phase always runs.** Every invocation evaluates the feature against four axes to determine planning intensity. This must be a sober, cold analysis — even if the user suggests a level, confirm or counter it with axis-by-axis reasoning. Tracker scope and Figma surface area feed these axes (a multi-screen design or a cross-cutting issue raises Scope Containment and Solution Space).

### Evaluation Axes

Score each axis independently as 1, 2, or 3:

#### Scope Containment

| Score | Signal                                                                                                  |
| ----- | ------------------------------------------------------------------------------------------------------- |
| 1     | **Bounded**: 1-3 files, single module, no cross-module dependencies                                     |
| 2     | **Moderate**: multiple modules, but the boundary is predictable from the requirements                   |
| 3     | **Rippling**: cross-cutting concern, unclear boundaries, or changes propagate through dependency chains |

#### Path Criticality

The question to ask: _if this breaks, does a core flow or feature break?_

| Score | Signal                                                                                                          |
| ----- | --------------------------------------------------------------------------------------------------------------- |
| 1     | **Non-critical**: internal tooling, cosmetic, isolated utility, test infrastructure                             |
| 2     | **Adjacent**: changed code interacts with modules on core paths but doesn't directly handle critical operations |
| 3     | **Core**: directly handles auth, payments, data integrity, or sits on a path exercised by the majority of users |

#### Requirement Clarity

| Score | Signal                                                                                                                   |
| ----- | ------------------------------------------------------------------------------------------------------------------------ |
| 1     | **Fully specified**: inputs, outputs, behavior, and edge cases are clear from the spec or conversation                   |
| 2     | **Mostly clear**: happy path is defined but some edge cases or integration points need resolving                         |
| 3     | **Underspecified**: open questions about fundamental behavior, conflicting requirements, or scope still being discovered |

#### Solution Space

| Score | Signal                                                                                                         |
| ----- | -------------------------------------------------------------------------------------------------------------- |
| 1     | **Obvious**: one well-established approach, community consensus, or direct pattern match in the codebase       |
| 2     | **Moderate**: 2-3 reasonable approaches with real tradeoffs between them                                       |
| 3     | **Wide**: many viable approaches, novel problem, no clear winner, or the "obvious" solution has known pitfalls |

### Level Determination

**Level = max(all axis scores)**

| Max Score | Level           | Meaning                                                                                                                             |
| --------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 1         | **basic**       | Straightforward, limited scope, low risk. The most elegant solution is the question, not whether one exists.                        |
| 2         | **default**     | Touches important paths or has real tradeoffs. The simplest approach cannot be assumed good enough.                                 |
| 3         | **non-trivial** | Scope or solution space is genuinely uncertain AND/OR the feature directly affects core flows. Multiple solutions must be explored. |

### Presenting the Evaluation

Show the user the axis scores and recommended level. If the user suggested a different level, state which axes drove the discrepancy. Recommend your assessed level but defer if the user has context you lack.

### Escalation During Planning

The adversarial agent in Phase 2 may argue the assessed level is too low. When this happens:

- **default to non-trivial**: Escalate silently. Spin up additional agents and continue at the higher level.
- **basic to default**: Surface to the user with the adversarial agent's reasoning. This is the biggest jump in cost — the user should confirm before proceeding.

---

## Phase 2: Multi-Agent Context Gathering

Ultrathink before dispatching agents. The quality of the plan depends heavily on choosing the right roles, giving agents the right context, and framing their investigation angles so they produce genuinely different perspectives.

**Critical rule**: give agents file paths and source references to read themselves. Do not give summarized versions of code or specs — summaries lose information and intent, and agents are capable of forming their own understanding. When Figma was captured, give agents the absolute `<plandir>/figma/` paths and tell them to read the cached deliverables directly — never to re-fetch from the Figma MCP. When a tracker source exists, give agents the issue/project content (or its on-disk copy).

Research agents suit a mid-tier model (e.g. Sonnet) where your tool supports per-agent model choice — otherwise the default model is fine. Give each a role name where supported. Every level includes at least one adversarial agent.

### Level 1 (basic)

No outside research. The codebase, conversation, and any cached Figma/tracker context are sufficient.

1. **2 research agents** with complementary roles assess the best implementation approach. They should:
   - Read the relevant code directly (give them paths, not summaries)
   - Read the cached `figma/` deliverables if present
   - Identify the most elegant, robust solution without assuming what constitutes an acceptable tradeoff
   - Look for existing patterns in the codebase to follow or extend
   - Return with a concrete implementation recommendation

2. **1 adversarial agent** reviews the same code and requirements to:
   - Find gaps, risks, or incorrect assumptions
   - Challenge whether the level assessment is correct (can argue for escalation to default)
   - Identify anything the other agents took for granted
   - Does not single-handedly have veto rights, but their opinion must be considered thoroughly

3. All agents return their analysis independently. No shared state, no assumptions, no self-imposed scope limitations.

### Level 2 (default)

Same structure as basic, with a preceding research step and more agents.

**Step 0 — Research**: Dispatch **1-2 research agents** with web-search and web-fetch access to gather up-to-date information relevant to the feature:

- Current API/SDK/library documentation for any external dependencies
- Known patterns, community solutions, or recent changes in relevant libraries
- Anything where relying on training data or assumptions would be risky

These agents return a detailed evaluation and analysis. **Wait for them to complete** before proceeding — their findings inform all subsequent steps.

**Step 1**: Up to **3 research agents** with complementary roles (same mandate as L1 Step 1, now informed by Step 0 findings)

**Step 2**: **1 adversarial agent** (same mandate as L1 Step 2)

**Step 3**: All agents return independently.

### Level 3 (non-trivial)

Every step from Level 2, scaled up to match the complexity.

**Step 0**: **3 research agents** with web search/fetch, each investigating a different facet of the problem space (e.g., one on the primary framework/library, one on integration patterns, one on failure modes and edge cases in similar systems)

**Step 1**: **4-5 research agents** with diverse roles — the orchestrator should assign roles that cover different concerns: architecture fit, implementation mechanics, performance, developer experience, failure modes, and any domain-specific concerns relevant to this feature

**Step 2**: **1 adversarial agent**

**Step 3**: All agents return independently.

---

## Phase 3: Stochastic Consensus and Debate

When all Phase 2 agents have returned, orchestrate a debate. The goal is convergence on a concrete implementation approach through genuine disagreement — not through premature agreement or politeness.

### Debate Focus

Two concerns, weighted by level:

| Level       | Implementation approach | Risk assessment |
| ----------- | ----------------------- | --------------- |
| basic       | Primary focus           | Light touch     |
| default     | Balanced                | Balanced        |
| non-trivial | Balanced                | Primary focus   |

Implementation approach: architecture, patterns, code organization, API design, how to build it.
Risk assessment: edge cases, failure modes, performance implications, breaking changes, what could go wrong.

### Orchestrator Responsibilities

You are not a passive relay. You must:

- **Monitor for goal drift.** If the debate optimizes for theoretical elegance over practical fit, or for general scalability when the user needs simplicity — redirect.
- **Inject the user's context.** Agents lose sight of actual requirements. Remind them of constraints and non-negotiables when discussion drifts.
- **Call for further research** if a critical question surfaces that no agent can answer confidently. Pausing beats proceeding on shaky ground.
- **Push past false consensus.** If agents agree too quickly, probe for hidden disagreements. Real consensus is earned through examined tradeoffs, not granted by default.
- **Detect level escalation.** If the debate reveals the feature is more complex than assessed, apply the escalation rules from Phase 1.

### Debate Format

Use ultrathink to choose the right format. Scale to the level:

- **basic**: Focused point/counterpoint on the 1-2 key decisions. Keep it tight.
- **default**: Proposal defense — each perspective presents their recommended approach, others critique. Build a tradeoff matrix against the user's priorities.
- **non-trivial**: Structured multi-round debate. Proposals first, then critiques, then collaborative convergence. Multiple rounds if disagreements are substantive. Don't rush resolution.

The debate concludes when there is genuine convergence, or clearly identified remaining disagreements with reasoned positions on each side.

---

## Phase 4: Comprehensive Analysis

1. **Ultrathink** to evaluate the debate output independently. The agents did the investigation — now you synthesize, assess, and apply your own judgment.

2. Write the implementation plan to `<plandir>/plan.md`:

```markdown
# Implementation Plan: [Feature Name]

## Recommended Approach

What to build and why this approach was chosen. Key architectural decisions with reasoning.

## Alternatives Considered

Approaches that were evaluated and why they were not chosen. Include any dissenting views that have genuine merit — not everything resolves cleanly.

## File Impact Map

All files that will be created, modified, or deleted — exact paths, one-line summary of what changes in each.

## Implementation Steps

Ordered, concrete steps. Each step specifies:

- Exact file paths affected (create, modify, or delete)
- What to change — specific enough to implement without re-researching the problem
- Dependencies on other steps
- How to verify the step is correct (specific command, assertion, or observable behavior)

Task granularity: each step should be a coherent unit of work — related changes that can be implemented and verified together. Don't split coupled changes across steps or combine unrelated changes into one. The right boundary is what makes sense as a single dispatch to an implementing agent, not an arbitrary time estimate.

## Risk Assessment

- Known risks and their mitigations
- Edge cases surfaced during debate
- Areas needing further investigation during implementation
- What to watch for (regression signals, performance cliffs, etc.)

## Open Questions

Unresolved items the user should decide before or during implementation.
```

This document is the primary deliverable. It should be concrete enough that someone could implement from it without re-researching the problem.

### When the plan touches UI built from Figma

If Phase 0c cached Figma designs, every plan step that builds or changes UI must:

- Reference the cached asset by local path (`figma/<node-id>.png` or whatever the capture agent wrote under `figma/` — e.g. `mockup.txt`, `translated-code.md`), not a Figma URL.
- Use concrete values (copy strings, icon names, color tokens) traced to the cached deliverables or an actual codebase file — never guessed.
- Include a **visual-verification step**: render the live UI and compare it element-by-element (position, spacing, colors, typography, copy) against the referenced cached asset. Weight this to the level — a light check at basic, a thorough per-screen comparison at non-trivial.

### Plan Quality Standards

Plans that contain any of the following aren't concrete enough for an implementer to act on — they force re-research or guesswork, which defeats the purpose of planning:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases" without specifying which cases and how
- "Similar to Step N" without repeating the relevant specifics (the implementer may read steps out of order, or a different agent may handle each step)
- Steps that describe _what_ to do without specifying how to verify it worked
- References to functions, types, or APIs not defined or identified elsewhere in the plan
- Vague file references ("the config file", "the test module") instead of exact paths
- For UI work: approximated styling values, or icon/copy/enum values whose source can't be traced to a cached asset or a real file

### Self-Review

After writing the complete plan, review it before moving to Phase 5:

1. **Requirement coverage**: Walk each requirement from the user's description, the tracker source, or the spec. Point to the step that addresses it. List any gaps.
2. **Placeholder scan**: Search for the anti-patterns listed above. Fix them.
3. **Name consistency**: Do function names, type names, and file paths used in later steps match what earlier steps established? A function called `clearLayers()` in Step 2 but `clearFullLayers()` in Step 5 is a plan bug.
4. **Source traceability** (when Figma/tracker sources present): every concrete value traces to a cached asset, the tracker source, or a real codebase file.

Fix issues inline. If a requirement has no corresponding step, add one.

---

## Phase 5: Executive Summary

**After** the full plan is written, create `<plandir>/summary.md`.

Contents:

- Key recommendation in 1-2 sentences
- Top 3-5 implementation decisions with one-line rationale each
- Critical risks or caveats
- Estimated scope: files, modules, rough change size

Write this AFTER Phase 4 — it must reflect the final plan. Keep it scannable (under 2 minutes to read).

---

## Context File Integration

After both documents are written, follow any project-specific conventions in the repo's agent context files (AGENTS.md / CLAUDE.md and their local variants) for how plans are tracked (e.g. updating a PLAN.md or PROGRESS.md index). If no such convention exists, skip this step.

---

## Present Plan

There is no plan-mode gate. When the plan and summary are written to disk:

1. Present the executive summary inline, with the exact on-disk paths to both files (`<plandir>/plan.md` and `<plandir>/summary.md`) so the user can open them.
2. If Figma was captured, point to `<plandir>/figma/` as the cached design source.
3. Ask the user to review and tell you what to adjust, or to confirm before implementation begins.

**Do not begin implementing until the user has reviewed and approved the plan.** The plan files on disk are the durable deliverable regardless of whether implementation starts now or later.
