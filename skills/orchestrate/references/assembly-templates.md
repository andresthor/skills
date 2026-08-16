# Assembly templates

How a resolved config (D1–D8 from `dimension-matrix.md`) becomes your orchestration plan. The skeleton below is the full menu; **omit any section with no resolved content** — never carry an empty header. Each section is annotated with the pattern it implements (see `pattern-library.md`).

The plan is written in the second person — addressed to the orchestrator who will run it: the objective held, the roster spawned, the gates enforced. For a small run that orchestrator is *you*, inline — you act on it directly. For a large run you offload it: the same plan body becomes the core of the **execution brief** (see below) you hand to a single runner agent. Either way it's an operating playbook, never a deliverable handed back to the user.

---

## The skeleton

```
# <objective — one sentence>
Definition of done: <D2, concrete>.

## Out of scope                              [P11 — always-on if any scope is inferable]
- <explicitly excluded surface area>

## Failures so far / KEEP these              [P1 — only if iterating on a prior run]
Prior attempts failed in distinct ways; all are disqualifying:
1. <named failure> — <precise mechanism>
KEEP these (what worked, preserve):
- <preserved win>

## Roster                                     [P5 — varies by D1/D3/D4]
<role name> — scope: <…>; deliverable: <…>; output path: <…>; lifecycle: <active | idle-on-call>.
(repeat per role)

## Collaboration protocol                     [P5/P6 — D5]
<independent | debate | stochastic consensus | adversarial — see presets>
No agent has veto authority, including you. You do NOT author, moderate, or decide —
you checkpoint at boundaries and keep the run on its objective.

## Verification                               [P6 — D6]
<self-check | verify-by-challenger on live file:line | gold-diff against <artifact>>

## State & coordination                       [P2/P3 — D7]
Working directory: <path>. All output goes to named files there.
Plan file: <path>/orchestration-plan-<goal-slug>.md — resolve the slug here and write the concrete
name; goal, stats, diagram; written before anything spawns [always-on].
<handoff.md / PROGRESS.md / decision-record per round — when multi-phase/session>

## Spend & gates                              [P7/P12 — D8]
<one-shot | pilot on <cheap model> then scale | hard cap $<n> + per-step approval>
Irreversible actions (<push/publish/post/delete/migrate>) require explicit user confirmation.
Halt and report if <precondition> fails rather than degrading silently.

## Orchestrator self-governance               [always-on]
Before each phase, re-state the objective to yourself. Redirect any agent that rabbit-holes
or drifts. When an agent goes wrong, name its exact wrong assumption — don't just re-issue the
instruction [P10]. No single voice outweighs another.

## Interruption                               [P12 — always-on]
Inline run: surface genuine ambiguity about the task via the runtime's user-question tool (such as `AskUserQuestion`, `question`, `ask_question`) — you're in-session.
Offloaded run: you can't reach the human — resolve ambiguity by defaulting and noting it in your
return; never bounce back for a question. Either way, reading files / doing the research does NOT
require asking permission — only real decisions do.
```

---

## Fan-out presets (D1 — the biggest fork)

### CONVERGE — many agents → one truth
- Roster of **distinct, non-overlapping analytical roles** + an **architect/synthesizer** who is a real team member, never the lead [P5].
- Collaboration: independent by default; debate or adversarial if D5 says so.
- Discovery roles carry **"investigate the live source yourself, cite file:line; do not pre-filter — synthesis judges"** [P6, gem].
- Verification: **verify-by-challenger** — contested facts settled by the challenger opening the cited source, not by waking the author [P6].
- Lifecycle: researchers write their report, then go **idle-on-call** to protect context.

### DIVERGE — many agents → many artifacts
- N agents, each instructed to take a **"vastly different but bold"** approach [P9].
- Each in its **own git worktree** so they can build/run/commit without colliding; keep branches, discard worktrees.
- **No cross-talk** — divergence is the point; homogenization is the failure.
- No synthesis step — the deliverable is the *set*; the user chooses among them.
- First-step guard if a working tree is needed: instruct the agent to `cd` into the repo before spawning.

---

## Collaboration presets (D5)

- **Independent parallel:** roles run blind to each other; results collected and (converge) synthesized.
- **Cross-talk debate:** an agent-team whose members communicate directly (see "Agent-team vs. orchestrator-relay" below for when this is worth it); bounded rounds; an architect appends a decision-record each round [P2]; live-evidence discipline [P6]; no veto [P5].
- **Stochastic consensus:** N *independent* attempts at the same question, then a vote/synthesis pass — use when one attempt is noisy and you want a robust signal.
- **Adversarial panel:** add a skeptic role whose job is to *refute*; for high-stakes claims, run majority-refute (≥2 of N must refute to kill a finding). Skeptic has **no veto** [P5]; pair with the anti-sycophancy note [P8] so agreement-bias doesn't corrupt the vote.

---

## Agent-team (direct comms) vs. orchestrator-relay

By default, parallel agents are independent and the lead relays between them. That relay is a bottleneck that **flattens** disagreement — every voice is paraphrased through one mediator, so sharp, incompatible positions get smoothed toward a bland middle.

Reach for a true **agent-team** (agents that message each other directly, via the runtime's inter-agent messaging mechanism if available — such as `SendMessage`) ONLY when ALL of these hold:
- the value is in the *friction between* agents, not their independent outputs (a real debate, a design argument, a consensus that must survive cross-examination), AND
- every agent genuinely needs to hear every other agent — relayed summaries would lose the nuance that makes the exchange worth running, AND
- there are few enough agents (≈2–5) that all-to-all communication stays signal, not noise.

Otherwise — independent parallel research, converge-and-synthesize, a fan-out of artifacts — the team machinery is overkill: it spends context and coordination on communication the task doesn't need. When you don't need a team, the lead collects and (for converge) synthesizes.

**Render the comms mode explicitly in the emitted prompt — never leave it implicit.** When you emit a debate, the prompt must spell out how the agents actually talk:
- Direct-comms team: *"Spawn these roles as an agent-team; they address each other directly (via the runtime's inter-agent messaging, e.g. `SendMessage`); you (the lead) do NOT relay turn-by-turn — you only checkpoint at round boundaries."* Name the rounds and who opens each.
- Lead-relay (the default for everything that isn't a real debate): say the lead collects and passes along.

If you leave it implicit, the run defaults to the lead narrating each turn — which flattens the disagreement into a mediated middle, the exact failure the team shape exists to prevent. So whenever the value is the friction between agents, emit the direct-comms team explicitly.

---

## Multi-phase shapes (D3 = pipeline)

Some work isn't one fan-out — it's stages, each gated on the last. The canonical and highest-value shape is **research → debate**: gather grounded findings first, THEN bring in fresh or opposing minds to argue over them. Don't collapse it into a single round — an agent forced to gather and judge in the same breath does neither well.

Skeleton:
- **Phase 1 — gather.** Discovery roles investigate live sources, cite file:line, "don't pre-filter". Each writes a named report to the working dir, then goes **idle-on-call** — NOT kept active through later phases (that unbounded context growth is what kills long-running agents).
- **Gate.** Phase 2 does not begin until every Phase 1 report exists. The files are the gate — observable, no polling.
- **Phase 2 — contest.** Fresh agents (debate / adversarial / a skeptic) read the Phase 1 *artifacts* plus the live code and argue. Contested facts are settled by the challenger opening the cited source itself [P6] — never by waking the Phase 1 author. An architect (a real member, never the lead) appends resolutions to a decision-record each round [P2].
- **Close.** Converge → the architect synthesizes from the decision-record. Diverge → the artifacts stand.

Emit this shape whenever the input implies "look into X, then decide/argue about it," or when the work clearly separates into a discovery stage and a judgment stage. Phases compose with the collaboration presets above — e.g. Phase 1 independent-parallel, Phase 2 agent-team debate.

---

## Workflow mechanism (deterministic — Claude Code)

When the process is a **fixed script** — the phases, the fan-out, and the gates are all known up front and need no mid-run judgment — the phased shape above is better *compiled* than hand-driven. In Claude Code, express it with the Workflow tool (`/workflows`): a deterministic script that fans out, gates, and pipelines agents for you, driven from the session that owns the tool. Reach for it over hand-driven phases when the run is large and repeatable and you would otherwise be babysitting boundaries by hand.

- **Stays in the primary session.** A workflow is orchestrated by the tool-owning session; it is not offloaded to a runner.
- **Not for reactive work.** If you need to re-adjust roles or refocus agents as results land, you want an agent-team (live steering), not a script. Determinism is the whole precondition.
- **Fallback (any runtime without a scripted-workflow primitive):** run the **Multi-phase shape** above by hand — same phases, same file gates, you hold the boundaries yourself. The script is an optimization over that shape, not a different capability.

---

## Execution brief for an offloaded runner

For a large run (team / pipeline, or heavy returns) you don't execute inline — you spawn **one** `general-purpose` agent, labelled `runner`, in its own context to run the assembled plan, so the fan-out's returns never flood your conversation. But a freshly-spawned agent has none of your context and none of this skill. So the brief must be **self-contained and must carry the execution-time countermeasures** — not just the config and roster. If the no-veto rule, the phase gates, and the role-identity rule (plain subagents, not named teammates) don't travel with the plan, the runner is a weaker orchestrator than you'd be inline. Hand it the plan body (the skeleton above, fully resolved) wrapped in this:

```
You are the execution runner for an orchestration that has ALREADY been designed and approved.
Do not re-litigate the design or ask the user anything — you have no channel to them. Run the
plan below to completion and return the result.

<the fully-resolved plan body — objective, out-of-scope, roster, collaboration, verification,
 state & coordination, spend & gates>

## How to run it
- FIRST, preflight your spawn capability: confirm an agent-spawning tool is in your function set,
  then spawn one trivial probe subagent ("reply with the word ok" — nothing else). If the tool is
  missing or the probe fails, STOP and return immediately, reporting the missing capability.
  Do NOT execute the roster's roles yourself — a solo role-play of the plan is a failed run,
  not a fallback, and this is the one gap you never default-and-note your way through.
- Spawn the roster with the runtime's agent-spawning tool (such as `Agent`, `task`, `runSubagent`)
  as **plain subagents** — carry each role in the prompt, do NOT register them as named teammates.
  You are yourself a spawned agent; the team roster is flat, so a named-teammate spawn is rejected.
  Spawn them **synchronously** too — a spawned agent cannot launch background agents (in Claude
  Code: omit `name`, set `run_in_background=false`). For parallelism, issue the spawns as one
  batch of tool calls in a single message; background mode is not how you fan out.
  Your roster is independent fan-out and never addresses itself, so it needs no addressable names.
  (If a design ever needs agents to address each other, it is an agent-team — it cannot be offloaded
  and must not have been handed to you; return and flag it rather than forcing it here.)
- Hold the gates: a phase begins only when the prior phase's named output files all exist.
  Observe the files; don't poll the agents.
- No agent has veto, including you. You do NOT author, moderate, or decide the content — you
  checkpoint at boundaries, keep the run on its objective, and synthesize at the end (converge).
- Govern drift by naming an agent's exact wrong assumption [P10], not by re-issuing the instruction.
- Mid-run ambiguity: default to the most reasonable reading and NOTE it in your return. Never stop
  to ask — you cannot reach the human.
- Irreversible actions (push / publish / post / delete / migrate): do all the REVERSIBLE work, then
  STOP at the irreversible step and flag it in your return for the parent to execute. Never perform
  one unconfirmed — unless this brief explicitly pre-authorized it.
- Honor any spend cap stated above; otherwise run the plan as scaled.

## What to return (your entire final message)
The RESULT: the synthesized output (converge) or the artifact set with absolute paths (diverge), plus a one-line note of any defaults you took and any irreversible step you left flagged.
```
