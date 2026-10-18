---
name: verify-it
description: >-
  Spin up two independent adversarial subagents to pressure-test a
  proposed solution, fix, or claim before acting on it. Use when an agent (or the user) has just
  arrived at a candidate answer and you want a second opinion before committing. Triggers on phrases
  like "verify this", "double-check this", "pressure-test", "get a second opinion", "is this solution
  right", or any moment where a non-trivial fix has just been proposed and hasn't been validated yet.
argument-hint: "[the claim or solution to verify]"
allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion
metadata:
  version: 2.0.0
---

# Verify It

A lightweight pressure-test for a proposed solution, fix, diagnosis, or claim. Two independent adversarial subagents review the same proposal and report back.

The point is to catch the things you missed because you were close to the problem. You've just spent time building a theory of the fix — that's exactly when blind spots are hardest to see.

---

## Step 1: Identify the Proposal

Figure out what's being verified. There are two sources:

1. **An argument was given when this skill was invoked** — treat that text as the proposal (or as a pointer to what in the conversation to focus on, e.g., "the migration plan", "the bug diagnosis above").
2. **No argument was given** — the proposal is already in the conversation. Scan back and identify the most recent candidate solution/fix/claim/diagnosis. If there's more than one plausible candidate, ask the user which one to verify rather than guessing.

Write down, in your own words, a crisp summary of:

- **The claim** — what is being proposed as true or as the fix
- **The changes** — files, commands, behavior changes
- **Factual claims** — the stated root cause, plus every file, function, API, version, or behavior the proposal asserts exists or behaves a certain way
- **Evidence** — raw error messages, stack traces, logs, test output
- **The argument** — why the proposer believes the evidence leads to the claim

**Skip if trivial.** If the proposal is a one-line change with obvious correctness, say this skill is overkill and stop — unless the user invoked it explicitly, in which case run it anyway.

**Print this summary, then keep going in the same turn.** Don't stop for approval, don't ask "does this look right?" — spawn the agents immediately after printing it. The summary earns its place by being on the record, not by gating anything: when a verdict comes back resting on a bad premise, this is what lets the user see *why* it went wrong instead of just distrusting the output.

Keep it to one line per bullet. It's a premise on the record, not a report and not a checkpoint.

One case does stop: if you can't paraphrase the proposal cleanly — it's too tangled, or you genuinely don't understand it — say so and ask the user to narrow it. You can't verify something you don't understand. Short of that, print and proceed.

---

## Step 2: Launch Two Adversarial Reviewers in Parallel

In a single message, spawn two adversarial subagents with the same brief (different harnesses call these sub-tasks, agents, or background workers — use whatever parallel delegation your tool offers). They work independently and must not see each other's output. Deep defects are caught by some passes and missed by others; two independent passes catch more than one longer pass, at no extra wall time.

If your environment cannot run subagents at all, do two reviews yourself, sequentially, and keep them independent: finish one completely before starting the other, and come at the second from a different starting file or failure mode.

Brief both agents thoroughly — they haven't seen this conversation. Give each the full Step 1 summary, the relevant file paths (so they can read source directly, not summaries), and any constraints the user has mentioned.

Three instructions go in **both** briefs, verbatim in substance:

- **Read only. Do not edit, write, or run anything that changes state.** An agent told to find problems, holding edit tools, drifts naturally toward fixing them — and a verification that mutates what it was verifying has destroyed the thing the user asked for. Findings are the deliverable; the fix is the user's call afterward. If your harness lets you restrict a subagent's tools, give both read-only tools — the brief instruction stays either way.
- **Return a short list, not an essay.** Findings ordered most severe first, one to two sentences each, with `path:line` evidence where a claim rests on code. No preamble, no restating the proposal back, no summary of what they were asked to do. If nothing turned up, say so in one line.
- **A claim that something is missing cites the search that came up empty.** "No test covers this", "no caller passes X", "nothing guards Y" — name the grep or files checked. Absence claims made from a partial read are the most common wrong finding.

The second instruction is what keeps Step 3 honest. Synthesis can't stay tight if it starts from two essays.

### The adversarial brief

**Mandate:** find what's wrong with the proposal. Attack the *execution*, not the user's stated goal.

Things to probe:
- Does the fix address the root cause, or just a symptom?
- What edge cases does it miss? (empty inputs, concurrency, failure modes, unusual states)
- What could it break? Call sites, shared state, dependent code, invariants elsewhere.
- Does the reasoning rest on an assumption that might be false? Check the factual claims it leans on against the code.
- Would the tests that cover this actually fail if the bug were present? A test that passes either way proves nothing.
- Is there a materially simpler or more robust approach that was overlooked?

The adversarial agent is not a rubber stamp. Its job is to disagree usefully. Give its objections real weight.

---

## Step 3: Synthesize

When both agents return, combine their findings into a short verdict for the user. The output is a scannable decision aid, not a report — someone should be able to read it and know what to do next in about fifteen seconds.

The verdict is one of:

- **Wrong** — a premise the fix depends on is false (root cause, a cited symbol, a described behavior)
- **Needs revision** — the premise holds, but the fix leaves the bug, misses a case that matters, or breaks something
- **Holds up with caveats** — only non-blocking findings remain (minor edge cases, a simpler alternative)
- **Holds up** — nothing survived checking

Pick the worst level any surviving finding earns.

The shape:

```
**Verdict:** <one of the four> — <half a sentence saying why>

**Findings**
- <the issue> — <what it breaks or costs>. `path/to/file.ts:42` (both / one reviewer)
- ...

**Next:** <one line — proceed, revise this specific thing, or stop and rethink>
```

Rules that keep it that size:

- **At most five findings**, most severe first. If there are more, the extras are noise at this stage — carry the top five and say how many you dropped.
- **One to two sentences per bullet.** Anything longer is a discussion, and a discussion belongs in the reply to a follow-up question, not in the verdict.
- **When nothing survived, say so in one line** — never write a paragraph explaining that there was nothing to write.
- **Never paste agent output verbatim.** If the user wants the full text of a finding, they'll ask, and you still have it.
- **Check the evidence behind any finding that would move the verdict.** Open the cited `path:line` and confirm it shows what the agent claims. Drop a finding only when the code doesn't support it — never because you disagree with its reasoning. An uncited finding stays, marked *unverified*.
- **If the reviewers contradict each other, surface it** rather than picking a side.
