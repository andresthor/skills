# Pattern library

The orchestration patterns this skill compiles from. Each is tagged with the **agent deficit** it neutralizes — an agent **forgets** (amnesia), **overreaches** (confabulates / flatters / accrues unchecked authority), or **collapses to the safe average** (mode-collapse). Plus operational and prevention patterns that cut across.

Every emitted prompt is an assembly of these. When you cite *why* a clause is in the prompt, point at the pattern ID here.

> Provenance: distilled from an analysis of ~178 real agent sessions. This file is self-contained — the skill carries the library with it and depends on no external source.

---

## The spine — three deficits

An agent has three structural deficits. Almost every pattern is a countermeasure to one of them. When assembling a prompt, ask of each clause: *which deficit does this neutralize?*

1. **It forgets.** The context window is mortal; the agent confidently reconstructs a plausible-but-wrong version of anything it lacks.
2. **It overreaches.** A single agent with unchecked authority lets one hallucination — or one bout of sycophancy — contaminate the whole result.
3. **It averages out.** Untethered parallel agents share one training distribution and converge on the same mediocre answer.

---

## Patterns

### P1 — Failure encoded forward · [forgets]
Before a complex run, write a *named* taxonomy of how prior runs failed — each with a precise mechanism, not "it didn't work" — plus an explicit **"KEEP these"** list of what worked and must be preserved.
**Why:** an agent can't self-correct what it doesn't know was broken; positive instruction alone won't stop it repeating a known-bad strategy. "KEEP these" prevents regressing wins while fixing losses.
**Emit when:** the input references a prior run/attempt. The KEEP-these half is *mandatory* whenever iterating.

### P2 — Externalized state as source of truth · [forgets]
The conversation is lossy; the filesystem is not. Three artifacts: a `handoff.md` *navigation layer* (pointers + gotchas + exact commands, not a duplicate); a `PROGRESS.md` durable ground truth (decisions + rationale + cross-check numbers); a decision-record appended *every round* so context death never erases conclusions.
**Why:** decouples truth from the mortal context window; lets a fresh or dying agent orient in seconds.
**Emit when:** team or multi-phase/multi-session work (dimension D7).

### P3 — `.context/` above the repo root, gitignored · [forgets]
Documentation lives one directory *above* the project, spanning projects — outlives any git op, never accidentally committed.
**Why:** separates the artifact from the context-about-building-it; accumulates workspace knowledge instead of siloing per repo.
**Emit when:** specifying where state/handoff files live.

### P4 — Continuity payloads, not pointers · [forgets]
For implementation tasks, pre-resolve every blocking unknown *inline*: full PR/issue text, server URL, log paths, test credentials **with role labels**, non-obvious caveats, explicit completion criteria.
**Why:** the agent can't hallucinate about an implementation documented in front of it.
**Emit when:** the deliverable is a patch/build and the run is single-agent or short.

### P5 — Authority diffusion / no-veto · [overreaches]
Distinct, non-overlapping roles, each with scope + deliverable format + output path + lifecycle. **The lead is stripped of synthesis/moderation/authoring** and only checkpoints at boundaries. No single agent — lead or adversary — has veto.
**Why:** prevents one agent's bias/sycophancy/hallucination from contaminating the whole result, and prevents a lone dissenter from causing paralysis.
**Emit when:** any time there is more than one agent. This is **always-on** for panels/teams.

### P6 — Gate skepticism + verify-by-challenger · [overreaches]
Don't trust an instrument you haven't validated. Resolve factual disputes by the *challenger* opening the cited `file:line` / `gh pr diff` directly — never by the author re-asserting.
**Why:** summaries hallucinate; falsifiable citations stop the telephone game. (Real case: an LLM judge scored broken code 5/5.)
**Emit when:** the run makes factual/correctness claims (D6). Default verification for converge runs.

### P7 — Spend governance + irreversible-action gates · [overreaches]
Treat dollars-per-run as a steering variable: pilot-on-cheap-model before scaling, budget caps, per-step approval. Hard gates on irreversible acts (push, publish, post, delete, migrate) requiring explicit confirmation.
**Why:** prevents burning budget on an unvalidated instrument and prevents irreversible mistakes.
**Emit when:** team + expensive model (D8), or any irreversible action is in scope. The irreversible-action gate is **always-on**.

### P8 — Anti-sycophancy by construction · [overreaches]
A standing instruction that brevity and precision are the markers of a healthy agent; padding and agreement-seeking are the smell of a sick one. Carry it as a persona the agent inhabits — a terse, unimpressed senior reviewer with nothing to prove — rather than as a per-prompt reminder.
**Why:** calibrates the agent away from hedging and flattery without per-prompt nagging.
**Emit when:** any debate/adversarial/eval run where agreement-bias would corrupt the signal.

### P9 — Diversity-as-constraint + worktree isolation · [averages]
For generative fan-out: instruct "vastly different but bold" approaches, each agent in its **own git worktree** (independent filesystem → can run servers, commit independently). Keep branches, discard worktrees.
**Why:** untethered parallel agents converge on the safe average; the explicit divergence clause forces real alternatives; worktrees prevent multi-agent-in-one-dir conflicts.
**Emit when:** fan-out mode is DIVERGE (D1).

### P10 — Assumption-surface diagnosis · [operational]
When an agent goes wrong, name its exact implicit *wrong assumption* rather than re-stating the requirement.
**Why:** re-explaining treats the symptom; naming the wrong model fixes the cause in one sentence. This is the skill behind effective short corrections.
**Emit as:** a note in the orchestrator self-governance / steering section — how the lead should correct drifting agents.

### P11 — Scope elimination as the first move · [prevention]
Before planning, *delete* surface area: name what's explicitly out of scope ("X not needed — scrap that; Y is v2"), then plan the remainder.
**Why:** planning quality degrades when the problem is over-specified; eliminating first shrinks the search space.
**Emit as:** an "Out of scope" section. **Always-on** when any scope can be inferred.

### P12 — Halt conditions + calibrated interruption · [prevention]
Give the agent legitimate stop/ask paths with explicit carve-outs: "if you can't load the skill / the precondition fails — halt and report"; "surface real ambiguity via the runtime's user-question tool (such as `AskUserQuestion`, `question`, `ask_question`), but file-access permission is NOT an interrupt reason."
**Why:** prevents silent degradation when a gate fails, and calibrates between over- and under-interrupting.
**Emit as:** a halt-condition line + an interruption section. **Always-on.**

---

## Emerging gems (apply when they fit)

- **"Do not pre-filter — synthesis judges."** In every *discovery* role, instruct the agent not to self-censor "obvious" findings at collection time. Counters collect-time self-censorship. Inject into all discovery/research roles by default.
- **`CRITICAL:` inline directive.** A lightweight one-line behavior override (`CRITICAL: respond text-only`, `CRITICAL: output only the diff`) when a specific response shape matters.
- **Prompts-as-deliverables.** When a knowledgeable role's output *is* a prompt for a downstream task, say so explicitly.
- **Session names as retrospective evals.** Suggest the user name the run with an outcome-bearing slug.

---

## Always-on layer (inject regardless of what was asked)

These are the *improvements* — the under-amplified edges. Inject them whether or not any question was asked, when applicable:

- **No-veto + lead-stripped-of-synthesis** whenever >1 agent [P5].
- **Role identities** — every spawned agent carries a distinct role, never a generic label; undifferentiated agents are unreadable in logs. Agents that must *address each other* (an agent-team) are named teammates via the runtime's label field (such as `name` in Claude Code, `description` in OpenCode) — and only the primary session can spawn them, since the roster is flat. Independent fan-out (including an offloaded runner's roster) doesn't address itself, so it just carries the role in the prompt — do not name those as teammates. Always-on for any fan-out.
- **Prevention cluster:** scope-elimination [P11] + halt-conditions + irreversible-action confirmation gate [P12, P7].
- **"KEEP these"** whenever iterating on a prior run [P1].
- **"Don't pre-filter — synthesis judges"** in every discovery role [gem].
- **Orchestrator self-governance:** remind objectives, no veto, anti-rabbit-hole, redirect-on-drift, correct via assumption-surface diagnosis [P10].
