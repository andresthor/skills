---
name: verify-it
description: >-
  Spin up two independent subagents — one adversarial, one fact-grounding — to pressure-test a
  proposed solution, fix, or claim before acting on it. Use when an agent (or the user) has just
  arrived at a candidate answer and you want a second opinion before committing. Triggers on phrases
  like "verify this", "double-check this", "pressure-test", "get a second opinion", "is this solution
  right", or any moment where a non-trivial fix has just been proposed and hasn't been validated yet.
argument-hint: "[the claim or solution to verify]"
allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion
metadata:
  version: 1.0.0
---

# Verify It

A lightweight pressure-test for a proposed solution, fix, diagnosis, or claim. Two independent subagents look at the same proposal from different angles and report back.

The point is to catch the things you missed because you were close to the problem. You've just spent time building a theory of the fix — that's exactly when blind spots are hardest to see.

---

## Step 1: Identify the Proposal

Figure out what's being verified. There are two sources:

1. **An argument was given when this skill was invoked** — treat that text as the proposal (or as a pointer to what in the conversation to focus on, e.g., "the migration plan", "the bug diagnosis above").
2. **No argument was given** — the proposal is already in the conversation. Scan back and identify the most recent candidate solution/fix/claim/diagnosis. If there's more than one plausible candidate, ask the user which one to verify rather than guessing.

Write down, in your own words, a crisp summary of:

- **The claim** — what is being proposed as true or as the fix
- **The reasoning** — why it's believed to be correct (root cause, mechanism, evidence)
- **The concrete changes or actions** — files, commands, behavior changes
- **Any factual claims** — specific functions, files, APIs, versions, behaviors the proposal asserts exist or behave a certain way

**Print this summary, then keep going in the same turn.** Don't stop for approval, don't ask "does this look right?" — spawn the agents immediately after printing it. The summary earns its place by being on the record, not by gating anything: when a verdict comes back resting on a bad premise, this is what lets the user see *why* it went wrong instead of just distrusting the output.

Keep it to one line per bullet. It's a premise on the record, not a report and not a checkpoint.

One case does stop: if you can't paraphrase the proposal cleanly — it's too tangled, or you genuinely don't understand it — say so and ask the user to narrow it. You can't verify something you don't understand. Short of that, print and proceed.

---

## Step 2: Launch Two Subagents in Parallel

In a single message, spawn both subagents (different harnesses call these sub-tasks, agents, or background workers — use whatever parallel delegation your tool offers). They work independently and must not see each other's output.

If your environment cannot run subagents at all, do the two reviews yourself, sequentially — adversarial first, then grounding — and keep them independent: finish one review completely before starting the other, and don't let the first review's conclusions color the second.

Brief both agents thoroughly — they haven't seen this conversation. Give each the full proposal summary from Step 1, the relevant file paths (so they can read source directly, not summaries), and any constraints the user has mentioned.

Two instructions go in **both** briefs, verbatim in substance:

- **Read only. Do not edit, write, or run anything that changes state.** An agent told to find problems, holding edit tools, drifts naturally toward fixing them — and a verification that mutates what it was verifying has destroyed the thing the user asked for. Findings are the deliverable; the fix is the user's call afterward.
- **Return a short list, not an essay.** Findings ordered most severe first, one to two sentences each, with `path:line` evidence where a claim rests on code. No preamble, no restating the proposal back, no summary of what they were asked to do. If nothing turned up, say so in one line.

That second instruction is what keeps Step 3 honest. Synthesis can't stay tight if it starts from two essays.

### Agent A — Adversarial Reviewer

**Mandate:** find what's wrong with the proposal. Attack the *execution*, not the user's stated goal.

Things to probe:
- Does the fix address the root cause, or just a symptom?
- What edge cases does it miss? (empty inputs, concurrency, failure modes, unusual states)
- What could it break? Call sites, shared state, dependent code, invariants elsewhere.
- Does the reasoning rest on an assumption that might be false?
- Is there a materially simpler or more robust approach that was overlooked?

The adversarial agent is not a rubber stamp. Its job is to disagree usefully. Give its objections real weight.

### Agent B — Grounding Verifier

**Mandate:** check that the factual claims in the proposal actually match reality. No attacking the logic — just ground-truth the facts.

Things to verify by reading the actual code/docs/runtime:
- Do the named files, functions, symbols, and APIs actually exist as described?
- Does the behavior the proposal describes match what the code really does? (read it, don't assume)
- Is the described root cause consistent with the evidence (error messages, stack traces, logs, tests)?
- Are version numbers, config keys, flag names, and external API shapes accurate?
- If the proposal cites a line, function, or file as the source of a bug — is it really the source, or is the problem somewhere upstream/downstream?

This agent should report discrepancies precisely: "the proposal says X does Y, but `path/to/file.ts:42` actually does Z."

---

## Step 3: Synthesize

When both agents return, combine their findings into a short verdict for the user. The output is a scannable decision aid, not a report — someone should be able to read it and know what to do next in about fifteen seconds.

The verdict is one of:

- **Holds up** — both agents came back clean, proceed with confidence
- **Holds up with caveats** — minor issues flagged, listed below; decide whether to address
- **Needs revision** — substantive problems found, the proposal should change before acting
- **Wrong** — the proposal is based on a false premise or misidentified root cause

The shape:

```
**Verdict:** <one of the four> — <half a sentence saying why>

**Adversarial**
- <the issue> — <what it breaks or costs>. `path/to/file.ts:42`
- ...

**Grounding**
- Proposal says <X>; the code does <Y>. `path/to/file.ts:42`
- ...

**Next:** <one line — proceed, revise this specific thing, or stop and rethink>
```

Rules that keep it that size:

- **At most five bullets per section**, most severe first. If there are more, the extras are noise at this stage — carry the top five and say how many you dropped.
- **One to two sentences per bullet.** Anything longer is a discussion, and a discussion belongs in the reply to a follow-up question, not in the verdict.
- **Omit a section entirely when it found nothing.** A clean grounding check gets no heading — never write a paragraph explaining that there was nothing to write.
- **Never paste agent output verbatim.** If the user wants the full text of a finding, they'll ask, and you still have it.
- **Skip objections that turned out to be misunderstandings.** Report a resolved objection only when the resolution itself is worth the user knowing.

---

## Notes

- If the proposal is trivial (one-line change with obvious correctness), this skill is overkill — say so and skip it rather than burning agent cycles.
- If the two agents disagree with each other (e.g., adversarial says "this is wrong because X", grounding says "X is actually true"), surface the disagreement to the user rather than picking a side.
- The agents must be briefed in parallel in a single turn. Sequential spawning leaks information and defeats the independence.
