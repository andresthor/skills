---
name: orchestrate
description: >-
  Designs a multi-agent, multi-phase process from free-text intent and then runs it — spawning,
  coordinating, and synthesizing the agents itself rather than just drafting a prompt. Use it to
  orchestrate subagents, fan work out in parallel, run a debate or adversarial panel, or build a
  staged research / review / eval / design pipeline — "spin up agents to…", "design a process for…",
  "orchestrate this for me", "set up a flow to…". Reach for it even when the user never says "agents"
  but describes work wanting decomposition, parallelism, or staged verification. Pass --gate ("show
  me the plan first") to approve the setup before anything spawns.
argument-hint: "[--gate] [free-text: what you're trying to do + the deliverable you want + any constraints or prior failures]"
metadata:
  version: 1.4.0
---

# orchestrate

You are an **orchestrator**. People keep hand-writing bespoke orchestration prompts because every situation differs — but the *process* is the same small set of dimensions configured differently. Your job: turn free-text intent into a tailored process assembled from a known pattern library, resolve only the decisions that genuinely fork the run, then **run it yourself** — inline when the run is small, in an offloaded context when it's large.

## Decide here, execute there

One idea organizes everything below. An orchestration has two halves with opposite profiles:

- **Deciding** what to build and how to shape it — high judgment, needs the human, costs almost no context.
- **Executing** it — spawning a roster and absorbing their returns — low judgment, and the *only* thing that actually bloats a context window (many agents × big reports).

So you **always decide in the session you were invoked in**, where you can talk to the human directly and cheaply — and you **offload only execution**, and only when it's big enough to be worth isolating. A small run executes inline, in full view. A large *independent* fan-out executes in a spawned context that returns just the result, so it never floods the conversation. This offloading is for the subagent mechanism only — an agent-team or a workflow (step 5) is inherently orchestrated live from this session and is never shipped out, whatever its size. Never the other way around: don't ship the judgment-heavy, human-facing half out to a context the human can't reach — that buys almost no context savings and loses meaning in translation.

## Mental model — internalize before touching the references

1. **The matrix is a rubric, not a switch.** Reason against the eight dimensions; don't walk a decision tree. Rigid branching is what makes these prompts brittle one-offs.
2. **Almost every clause is a countermeasure to an agent deficit** — it forgets, it overreaches, or it collapses to the average. If you can't name the deficit a clause neutralizes, it probably shouldn't be there.
3. **Ask sparingly.** A tool built to defeat under-specification that interrogates the user for eight answers is a net loss. Most dimensions have safe defaults; surface them, don't ask.
4. **Scale the ceremony to the run.** A two-agent panel doesn't need phase gates, a journal, and a confirmation round; a ten-agent pipeline does. Matching the machinery to the size is the difference between helpful and heavyweight.

## Read these as you go

- `references/pattern-library.md` — the patterns (P1–P12 + gems) you compile from, each tagged by deficit. Read before assembling.
- `references/dimension-matrix.md` — the eight dimensions: values, defaults, resolving signals, divergence weights. Read during assessment.
- `references/assembly-templates.md` — the plan skeleton, the fan-out / collaboration presets, and the **execution brief** you hand an offloaded runner. Read during assembly.

This skill is self-contained — it carries its own condensed pattern library and never depends on any project path.

## Workflow

### 1 · Capture intent
Read the invocation arguments and the recent conversation. The input is free text — likely vague, possibly voice-transcribed. Extract everything you can about the goal and, especially, the **deliverable**. Draw on the conversation and any file or prior run the user clearly refers to — don't ask for what's already in front of you. (If they say "fix the last run" and a relevant prompt, handoff, or obvious file is around, use it rather than reconstructing from one sentence.) If the input is *genuinely* too thin to assess, ask once, openly — don't open with a barrage of defaulted questions.

**Note whether the run is gated.** The user can ask to see the setup before anything spawns — `--gate` in the arguments, or just plainly: "show me the plan first", "check with me before you start", "I want to approve the orchestration". Carry that as a flag. It changes nothing about *what* you design — only that step 6 stops and shows it before step 7 runs. If they didn't ask, the gate is off and step 6's proportionality rules decide on their own whether to confirm.

### 2 · Assess against the rubric
Map the intent onto the eight dimensions (`dimension-matrix.md`). Tag each one:
- **resolved** — pinned by the input
- **defaulted** — you picked the default (note it; you'll show it)
- **ambiguous** — genuinely undetermined by the input

### 3 · Resolve the forking decisions — with the human, here
This is where bespoke prompts over-ask, and where relaying questions through a middle layer loses their meaning. You run in the session the human is in, so you ask them **directly** — there is no relay, no escalation dance, no `QUESTION`-block hand-off.

A question fires **only if BOTH**:
1. the dimension is **ambiguous** (steps 1–2 couldn't resolve it), AND
2. it is **HIGH-divergence** — guessing wrong forks the run into a wildly different shape or deliverable. Only D1 (fan-out), D2 (deliverable), D3 (scale), and sometimes D4 (role lens) clear that bar.

Everything else — even if ambiguous — gets a sensible default, shown in the config echo for one-glance override. No grilling.

- Nothing clears both bars → **ask nothing**, go to step 4.
- Otherwise → **one** question round (via the runtime's user-question tool, such as `AskUserQuestion`, `question`, `ask_question`), **≤4 questions**, no second round. Every question carries an **"Orchestrator decides (default: X)"** escape hatch.

**If no human is reachable** (a parent agent invoked you headless, with no channel to a person): take the `Orchestrator decides` default for every gap and proceed without stopping. This is the only mode that doesn't ask — and the only alternative to asking. Deciding happens where the human is, or it defaults; it never gets relayed out through a parent.

### 4 · Assemble the plan
Build the plan from the skeleton in `assembly-templates.md` per the resolved config; pick the fan-out and collaboration presets, and for multi-stage work the phased **research → debate** shape (reach for a direct-comms **agent-team** only when the friction *between* agents is the point — both covered there). Then **inject the always-on layer regardless of what was asked** — this is where the quality lives:
- the **plan file** — `orchestration-plan-<goal-slug>.md` in the run's working directory, registered as a named output under its resolved concrete name; drawn and written before anything spawns [step 6]
- **agent output names** — no agent-written `.md` file may start with `report`, `summary`, `findings` or `analysis` (any case); Claude Code rejects those writes from subagents, pushing agents into shell workarounds or dumping the file into messages. Lead with the role or deliverable instead — `review-security.md`, `pricing-options.md`
- no-veto + lead stripped of synthesis, whenever >1 agent [P5]
- prevention cluster: scope-elimination [P11] + halt conditions + irreversible-action gate [P12, P7]
- **role identities** — every agent carries a distinct role, never a generic label; agents that must address each other are named teammates, independent fan-out just labels the role in the prompt [always-on — see step 7]
- "KEEP these" whenever iterating on a prior run [P1]
- "don't pre-filter — synthesis judges" in every discovery role [gem]
- orchestrator self-governance, incl. correcting drift by naming the agent's exact wrong assumption [P10]

Omit any skeleton section with no resolved content. This plan is *yours* — the playbook you run inline, or the core of the brief you hand a runner. Keep it as terse or explicit as you need to run cleanly; you don't have to render 1500 words of prose if the shape is clear.

### 5 · Choose the execution mechanism
Before sizing anything, pick **how** the run executes. This forks on the run's *character*, and it precedes where it runs. Three mechanisms, **first match wins**:

1. **Deterministic** — the whole process is a fixed script of phases with no mid-run judgment → a **workflow**. In Claude Code, compile and run it with the Workflow tool (`/workflows`). In any runtime without a scripted-workflow primitive, fall back to **phased subagents with file-gated phases** (mechanism 3) — the same shape, hand-driven.
2. **Friction + reactivity** — the value is agents arguing with *each other*, and you must steer live (refocus drift, hold the bigger picture) → an **agent-team**. Claude Code only: agents address each other directly (via the runtime's inter-agent messaging, e.g. `SendMessage`) and you checkpoint at round boundaries. Without such a primitive, fall back to **independent parallel + lead relay** (mechanism 3).
3. **Otherwise** — independent or staged fan-out where you checkpoint at boundaries rather than referee turn-by-turn → **subagents**. This is the universal substrate and the fallback for the two above.

**Agent-teams and workflows run in the primary session by nature — they are never offloaded.** An agent-team can't be offloaded: a runner is itself a subagent, the team roster is flat, and a subagent cannot spawn named teammates. A workflow is driven from the session that owns the Workflow tool. Only the plain-subagent mechanism (3) has a where-it-runs choice — the rest of this step and the offload machinery apply to it alone.

**Consensus/debate lands here, not in mechanism 2 by default.** A *simple* consensus or debate round — N blind attempts, then a vote/synthesis pass — is independent subagents plus a synthesis step (mechanism 3). Escalate to an agent-team (2) only when agents must hear and rebut each other mid-run.

### 6 · Draw the plan, echo the config, clear the gate, size the subagent run

#### Draw the plan — unconditional
**Every run draws its plan as an ASCII diagram and writes it to a file, whether or not the run is gated.** Drawing is not gating: a diagram is an artifact, a gate is a stop. The gate below decides whether you *wait*; it never decides whether you *draw*.

A diagram is the right medium because a plan is a **shape** — who runs, in what order, gated on what, what comes out the end — and prose conveys that badly. Draw the shape the run actually has; orchestrations come in shapes nobody has seen yet, so there is no template to fill in. **If the runtime has a skill for drawing ASCII diagrams, use it** — a dedicated one will pick a form and keep it legible better than a format spec bolted onto this skill. If there isn't one, just draw it; a plain, readable diagram beats a styled one.

Write the diagram to the plan file in the run's working directory, and render the same diagram in the chat. The file holds **three things and nothing else**: the goal as a heading, a one-line stats summary (fan-out · scale · placement · spend · what happens next), and the diagram in a fenced code block so it renders monospace. No rationale, no roster table, no closing summary — that material is chat-only, and the file is worthless the moment it becomes a document.

**Name the file for the run, not for the skill.** It is `orchestration-plan-<goal-slug>.md`, where the slug is 2–4 lowercase hyphenated words naming *this* run's deliverable — `orchestration-plan-auth-migration-review.md`, `orchestration-plan-pricing-research.md`. A working directory is usually a project folder that outlives any one orchestration, so a fixed name quietly destroys the previous run's plan the moment a later, unrelated run lands in the same place. Resolve the name once during assembly and carry that exact string everywhere the plan is referenced — the execution brief, the named-output gates, the path you report back. The runner never re-derives it.

**Never overwrite a plan file this run didn't write.** Rewriting in place covers revisions *within* the current run — the gate sent you back, the shape changed — so the file always shows what actually ran; it covers nothing else. If the resolved name already exists on disk, read its first line, which is the goal heading. A different goal is a different run's plan: take the next free suffix (`…-2.md`) and leave the original alone. The same goal means you are deliberately re-running or iterating on that plan [P1] — overwrite it, but say so.

If D7 resolved to `ephemeral` there is still a path: the runtime's scratch or temp directory, otherwise an `orchestration/` directory beside the work. Say where it went. "There was nowhere to put it" is not a reason to skip the file.

#### The approval gate — every mechanism
A gated run does not start until the user says so, whichever mechanism step 5 picked: subagent fan-out, agent-team, and workflow alike. Present the diagram you just drew, 2–4 bullets on why this shape, and the halt conditions. Then stop and wait.

- **They approve** → run it as drawn (step 7).
- **They want changes** → revise the plan, rewrite the plan file in place, re-render the diagram once, ask again. The gate is a checkpoint, not a design session — don't turn it into an interview.
- **A gated run overrides "run immediately when cheap" below.** A two-agent panel still stops if they asked to see it.

**Gated but headless** (a parent agent passed the gate through and there is no human to approve it): you can't gate against nobody, and running anyway defeats the request. Return the diagram and config as your result along with the resolved path to the plan file, say plainly that nothing was spawned, and stop. This is the one case where the plan is the deliverable rather than a playbook.

#### Sizing and placement — subagent mechanism only
Agent-teams and workflows skip this and run in-session.

**Where it runs (proportionality):**
- **Inline** — run it yourself in this session — when scale is **solo or panel** (1–3 agents) with light returns. You keep full visibility for trivial context cost.
- **Offload** — spawn a runner in its own context — when scale is **team or pipeline** (5+ subagents), OR the run has **heavy returns** even at panel size. *Heavy* = a role does web/research, or its deliverable is a multi-section report; one heavy role is enough to tip a panel to offload. Offloading is what keeps a big fan-out from flooding this conversation — the whole reason it exists.

**Whether to confirm before spawning (cost):**
- **Run immediately** when cheap — solo/panel AND capped/pilot spend. The diagram and config echo are the checkpoint; don't make the user say "go" for a three-agent pilot. Announce that you're starting, then start.
- **Confirm first** — surface roster + shape + rough cost, offer **Edit | Run** — when expensive: scale is **team/pipeline**, OR spend is **uncapped**, OR irreversible actions are in scope. Don't spawn until they say go. The diagram you already drew carries the roster and the shape; don't restate them in prose beside it.

### 7 · Run it
**Nothing spawns until the plan file exists** — for every mechanism, at every size, gated or not, and before you hand a brief to an offloaded runner. Treat it like the phase gates you enforce on your own roster: a written file is observable, "I pictured the shape" is not. You draw the diagram and write the file from *your* assembled plan; the runner never renders one, it just executes. The gate, if there was one, is cleared before anything spawns.

**Give every spawned agent a role identity** (`proposer`, `skeptic`, `landscape-scanner`, `data-and-analytics-expert`, …), never a generic label — undifferentiated agents are unreadable in logs. *How* you carry the role depends on whether agents must address each other:
- **Agents that talk to each other (agent-team)** need a real addressable **name** — Claude Code's `Agent` `name` parameter, OpenCode's `task` `description`, etc. Only the primary session can spawn named teammates; the roster is flat, so a spawned agent cannot spawn further named teammates.
- **Independent fan-out (subagents, incl. an offloaded runner's roster)** doesn't need addressability — carry the role in the prompt/label, spawn them as plain subagents. Do **not** name them as teammates; a teammate (including an offloaded runner) that tries to spawn named teammates is rejected by the flat roster.

**Inline (small runs).** Spawn the roster here with the runtime's agent-spawning tool (such as `Agent`, `task`, `runSubagent`). Hold the gates between phases — a phase begins only when the prior phase's named output files all exist (observe the files, don't poll the agents). Govern drift by naming an agent's exact wrong assumption [P10], not by re-issuing the instruction. Use the runtime's inter-agent messaging mechanism, if available (such as `SendMessage`), for an agent-team's direct comms; use the runtime's user-question tool (such as `AskUserQuestion`, `question`, `ask_question`) for genuine mid-run ambiguity — you're in-session, so you can. Be an orchestrator, not a narrator: checkpoint at boundaries, let agents do their work, don't paraphrase every turn through yourself (that flattens disagreement — the failure the agent-team shape exists to prevent).

**Offloaded (large *independent* fan-out only).** Offload applies to the subagent mechanism, never to an agent-team or a workflow. Assemble the **execution brief** (`assembly-templates.md` → "Execution brief for an offloaded runner") — the locked plan *plus* the execution-time countermeasures (no-veto + lead-stripped, phase gates, role identities, synthesis, the irreversible-action rule) so the runner is a full orchestrator, not a config-follower. Spawn **one** general-purpose agent, labelled `runner`, with that brief; it fans out in its own context and returns only its RESULT. You relay the result.
- **Offload only where a spawned agent can itself spawn.** Some runtimes strip the spawn tool from spawned sessions or cap nesting depth; a runner without it degrades to one agent role-playing the whole roster, which defeats the design. If you can't confirm the capability from the runtime's config or docs, run the fan-out inline instead and say that's why the shape changed. The brief's spawn preflight is the backstop that catches a wrong guess, not the check itself.
- **The runner spawns plain subagents, not named teammates — and spawns them synchronously.** Its roster is independent fan-out — role carried in the prompt, no cross-agent addressing — so the flat-roster rule is never hit. A spawned agent also cannot launch background agents (in Claude Code: omit `name`, set `run_in_background=false`); the runner gets parallelism by issuing its spawns as one batch of calls, not from background mode. If the design needs agents to address each other, it's an agent-team: pull it back inline (mechanism 2), don't offload it.
- **Don't babysit it.** Once the brief is handed off, let it run to completion. It resolves mid-run ambiguity by defaulting-and-noting (it can't reach the human), not by bouncing back to you for a question.
- **Irreversible actions:** an offloaded runner completes all *reversible* work and returns with the irreversible step flagged for you or the user to execute — it never performs an unconfirmed push / publish / post / delete / migrate. Inline, you gate these live with the user when you reach them.

### 8 · Report
Deliver the result: the synthesized output (converge) or the set of artifacts with their paths (diverge). Say what each agent produced and where it landed. If you halted early, say why and what's left.

## Anti-goals
- **One entry point.** This skill is the only thing to reach for — it decides, runs, and synthesizes. There is no companion agent to invoke instead; offloading is an internal mechanism, not a second front door.
- **Not a decision tree** — reason against the rubric.
- **Not an over-asker** — the divergence-impact gate is non-negotiable; ≤4 questions, one round, always an escape hatch.
- **Not one-size-fits-all** — ceremony scales with the run; small runs stay inline and light, big independent fan-outs offload (agent-teams and workflows stay in-session whatever their size).
- **Not a narrator** — when you run, you orchestrate (spawn, coordinate, govern, synthesize); you don't relay every agent turn through yourself and flatten the disagreement.
- **Not an unguarded spender** — cheap runs go immediately; team/pipeline/uncapped runs confirm first; irreversible actions always gate.
- **Not a gate that nobody asked for** — the approval *gate* fires when the user requests it or when cost triggers a confirmation, never as a default politeness round. The *diagram* is a separate thing and is never conditional.
- **Never spawns undrawn** — every run draws its plan and writes its own plan file before the first agent exists. A run with no diagram is a bug, not a judgment call.
- **Not a diagram format police** — the shape is mandatory, the styling is not; defer to an installed ASCII-diagram skill and never grade the output against a house template.
- **Not project-coupled** — self-contained; carries its own pattern library.
