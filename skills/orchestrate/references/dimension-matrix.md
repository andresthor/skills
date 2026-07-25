# Dimension matrix

The rubric you reason against to turn free-text intent into an orchestration config. **This is a rubric, not a switch statement.** Read the input, infer what you can, default the rest. Never walk a rigid decision tree — that's how this becomes brittle and useless. Use judgment.

Eight dimensions. For each: the **values**, the **default**, the **resolving signals** (what in the input pins it), and the **divergence weight** (how badly a wrong guess forks the result — this governs whether a gap is worth a question; see the questioning principle in SKILL.md).

---

## D1 — Fan-out mode · **HIGH divergence**
**converge** (many agents → one truth) · **diverge** (many agents → many artifacts to choose among)
- **Default:** infer from the verb. Analyze / review / evaluate / audit / research-to-a-conclusion → **converge**. Design / ideate / generate-options / explore-styles → **diverge**.
- **Resolving signals:** "pick the best", "compare approaches", "find the bug", "one answer" → converge. "give me options", "several directions", "redesign", "brainstorm" → diverge.
- **Why HIGH:** converge and diverge produce structurally *opposite* prompts (shared truth + verify-by-challenger vs. worktree isolation + no cross-talk). Guess wrong and the whole run is the wrong shape.

## D2 — Definition of done / deliverable · **HIGH divergence**
report · decision/recommendation · patch/PR · artifact set · spec/plan · ranked options · prompt(s)
- **Default:** none — this must be known. If the input doesn't make the deliverable concrete, it's the first thing to resolve.
- **Resolving signals:** explicit "I want a …", or strongly implied by the task.
- **Why HIGH:** the deliverable determines roles, verification, and what "finished" means. Everything else hangs off it.

## D3 — Scale · **HIGH divergence**
solo (1 agent) · panel (2–3) · team (5+) · multi-phase pipeline (phases with gates — see "Multi-phase shapes" in `assembly-templates.md` for the research→debate skeleton)
- No upper cap on agent count; lean on judgment.
- **Default:** **panel**. Escalate to team/pipeline for broad or multi-stage work; drop to solo for a single well-scoped task.
- **Resolving signals:** breadth of the problem, number of distinct sub-areas, whether phases/gates are implied, stated budget.
- **Why HIGH:** scale drives cost, coordination machinery (D7), whether you even need roles, **how much ceremony the run carries, and where it executes**. A solo task wrapped in team scaffolding is waste; a broad task run solo under-covers.
- **Drives proportionality + offload — for the subagent mechanism only (see SKILL.md steps 5–6):** once the run is plain subagents, solo/panel (1–3) run **inline** in the invoking session with light ceremony; team/pipeline (5+) — or any run with heavy returns (a role doing web/research, or producing a multi-section report) even at panel size — **offload** to a runner in its own context, with the full always-on layer. Agent-teams and workflows are chosen at step 5 and run in the primary session by nature — they are never offloaded regardless of scale. Match the machinery to the size.

## D4 — Role lens · MED divergence
analyze · build · review · research · design · eval
- **Default:** derive from D1 + D2 (e.g. converge + report → research/analyze; diverge + artifact set → design).
- **Resolving signals:** the domain verbs in the input.
- **Why MED:** usually derivable from D1/D2; only ask if genuinely undeterminable *and* it would swing the roster hard.

## D5 — Collaboration mode · MED divergence
independent parallel · cross-talk debate · stochastic consensus (N blind attempts → vote/synthesize) · adversarial panel
- **Default:** **independent** for converge; **none/independent** for diverge. Upgrade to debate when cross-pollination matters; adversarial when the cost of a wrong conclusion is high.
- **Resolving signals:** "have them debate", "pressure-test", "get consensus", "independent takes".
- **Why MED:** changes the interaction protocol but not the deliverable; safe to default and surface in the echo.

## D6 — Verification rigor · LOW divergence
self-check · verify-by-challenger on live `file:line` · gold-diff (against a known-correct artifact)
- **Default:** **verify-by-challenger** whenever the run makes factual/correctness claims; self-check for purely generative work.
- **Resolving signals:** "must be correct", "verify against the real code", "there's a gold answer".
- **Why LOW:** has a safe strong default [P6]; bake it into the plan rather than asking.

## D7 — State / continuity · LOW divergence
ephemeral · working-dir coordination (named files as phase gates) · handoff + PROGRESS (multi-session)
- **Default:** **working-dir coordination** for team/pipeline; ephemeral for solo/panel one-shots; handoff+PROGRESS when multi-session is implied.
- **Resolving signals:** "across sessions", "this is phase 2", "long-running".
- **Why LOW:** derivable from D3; safe default [P2].

## D8 — Spend posture · LOW divergence
one-shot · pilot-then-scale · hard cap + per-step approval
- **Default:** **pilot-then-scale** when team + expensive model; one-shot otherwise. Per-step approval when irreversible actions are in scope.
- **Resolving signals:** "be careful with cost", "this is expensive", "just do it".
- **Why LOW:** safe default [P7]; the irreversible-action gate is always-on regardless.

---

## Resolution summary

After assessing, you hold a config like:

```
D1 fan-out:        diverge
D2 deliverable:    5 redesign artifacts to choose among
D3 scale:          team (5)
D4 role lens:      design
D5 collaboration:  independent (no cross-talk)
D6 verification:   self-check
D7 state:          working-dir (worktrees)
D8 spend:          pilot-then-scale
```

Tag each entry as **resolved** (pinned by input), **defaulted** (you chose the default), or **ambiguous** (genuinely undetermined). Only `ambiguous ∩ HIGH-divergence` can trigger a question. Everything else is shown in the echoed config for one-glance override.
