---
name: sharpen-it
description: >-
  Interview the user relentlessly about anything that still has open decisions in it — a plan, an
  approach, a design, an argument, a piece of writing, a choice they are stuck on — resolving each
  question and dependency one at a time until you reach shared understanding. Use this whenever the
  user wants to stress-test or pressure-test an idea, "get grilled" on it, poke holes in a proposal,
  sharpen or harden something rough before committing to it, work through open questions and
  unknowns, or asks "what am I missing?" — even if they never say "sharpen". Subject matter is
  irrelevant; what matters is that decisions are unresolved. In a codebase that usually means an
  implementation approach, an API shape, or a choice between libraries. Distinct from producing a
  plan; this interrogates something that already exists rather than writing a new one.
argument-hint: "[what to sharpen — omit if it's already in context]"
metadata:
  version: 1.0.0
---

# Sharpen It

Your job is to pressure-test something until nothing important is left ambiguous. The user is handing you a rough idea — a plan, an approach, an argument, a technical choice, anything with decisions still open in it — and asking to be pushed on it: every vague spot, every unexamined assumption, every fork they haven't noticed they're standing at. By the end, you and the user should share a crisp, concrete picture of what they're actually deciding and why each choice was made.

This is a collaboration, not an interrogation for its own sake. The goal is a sharper idea, not a longer conversation.

## How to think about it

Treat the subject as a **tree of decisions**. Some choices are foundational — they constrain everything downstream — and others only make sense once the foundation is set. Resolve the foundational ones first. When a decision depends on an earlier one, say so out loud, so the user can see why the order matters and how their answers connect.

As answers come in, the tree changes shape: a single choice can prune whole branches or open new ones. That's why you work incrementally rather than front-loading a questionnaire.

## How to run the interview

**Ask one question at a time.** Resist the urge to dump a list. Each answer reshapes what's worth asking next, and a wall of questions forces the user to context-switch across decisions that should be taken in sequence. Ask, absorb the answer, then ask the next thing.

**Always bring a recommendation.** For every question, lead with the option you'd pick and the reasoning behind it. Reacting to a concrete proposal is far easier — and far more revealing — than staring at an open-ended prompt. Your recommendation also signals that you've actually thought about the problem, which makes the user's pushback sharper too.

**Explore before you ask.** If a question can be answered by reading what's already in front of you — the codebase, a spec, a linked doc — go read it instead of spending the user's attention. In code that usually means what library is already in use, how an existing module is structured, or whether a pattern is established. Only ask about things that are genuine decisions, not facts you can look up. When your recommendation rests on something you found, mention it so the user can correct a wrong assumption.

**Use the AskUserQuestion dialog** (or the equivalent structured-choice mechanism available to you) to present options whenever the decision is a choice among a few concrete alternatives. Take advantage of its layout and preview features — for example, showing a short code snippet, config example, or ASCII mockup in the preview so the user can compare options concretely rather than imagining them. Put your recommended option first and mark it as recommended. Fall back to plain prose questions when the decision is genuinely open-ended and doesn't reduce to a small option set.

**Surface dependencies and tradeoffs honestly.** When two decisions are coupled, name the coupling. When a choice has a real cost, say what it is. The point is shared understanding, not steering the user toward your preference.

## Knowing when to stop

Stop manufacturing questions once the remaining ones are minor, fully determined by earlier answers, or clearly the user's call with no meaningful tradeoff. Relentless means thorough, not interminable — don't pad the interview to seem rigorous.

When you reach that point, give a clear recap: the decisions that were resolved and the rationale for each, plus any open items you're deliberately deferring. Then **ask the user what they want to do with it** — the right final artifact is context-dependent. They might want nothing more than the shared understanding you've just built, a written summary pasted into the chat, a saved design doc or `plan.md`, a set of tasks, or a handoff to start implementation. Offer the options that fit the situation rather than assuming one.
