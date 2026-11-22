---
name: {{repo}}-craft
description: >-
  Engineering judgement for writing, changing, refactoring and reviewing code in this repo,
  which runs inside {{what-the-code-runs-inside}}. Use whenever touching the repo's source,
  scripts or tests, planning or designing a feature or refactor here, reviewing a diff or
  branch, or deciding how to structure, comment, type or test something here. Covers where
  boundaries belong, when to share code, what comments are for (never citations of plans,
  notes or step ids), how to verify against the pinned dependency instead of memory, and how
  to report. Use it for small changes too.
---

<!-- fill, then delete this comment. The templates assume a TypeScript repo whose scripts are in `package.json`. Replace each placeholder everywhere it appears in the skill, its references and the review agent:
- `{{repo}}`: the repo's short name, lowercase with hyphens. Example: acme-api
- `{{what-the-code-runs-inside}}`: a noun phrase, read after "runs inside" and "the contracts of", for whatever loads, calls or hosts the code. Example: a long-lived server process that an orchestrator starts and stops
- `{{gates}}`: one shell command that runs every gate; the templates supply the backticks. Example: pnpm check
- `{{pinned-truth}}`: the path of the pinned copy of the dependency the code is written against; the templates supply the backticks. Example: node_modules/<host-package>/
- Every other blank is a `fill:` comment that says what to write. Replace the comment with that text, or delete it where it says it may be deleted.
- In the frontmatter `description`, replace "the repo's source, scripts or tests" with the real directories, and add the repo's main kinds of unit (handler, route, command, component) after it. -->

# {{repo}}-craft

How to write code here so it stays good while the repo changes under it. Formatting, import order and type strictness are checked by the formatter and `tsc`, and a few craft rules by `bin/craft-check.mjs`. <!-- fill: one sentence per further tool the gates run, e.g. "Unused code is checked by <tool>."; delete if none --> `{{gates}}` runs them all, and the pre-commit hook runs the gates on every commit. This file is the layer those tools cannot check, and the layer that must survive refactorings and dependency upgrades unaided.

<!-- fill: one sentence on how work reaches this repo, if that shapes how code must be written (built step by step from a written plan; refactored often; young); delete if nothing special -->

Two rules follow, and everything below serves them:

1. **Never trust a description written about the code or the dependency — a plan, a design note, a README and this file's past tense included.** Read the actual thing. Code already in the tree is evidence of what was needed; it is not precedent for how the next thing must look.
2. **What the code is judged by, in priority order:**
   - It keeps the contracts of {{what-the-code-runs-inside}}. <!-- fill: one sentence naming the two or three contracts whose breakage compiles, lints and fails later --> Most mistakes here compile, pass lint, and fail in a mode, an input or a shutdown nobody tried.
   - A reader can use each piece without opening it.
   - It contains what the problem needs today and nothing else.
   - You understand every line you hand over.

**Plans and notes written outside the repo stay outside the code.** They explain why a change was built; the code must stand without them. No comment, test name or commit cites a plan, a research or design note, a spike, a step id, a scenario number or a private abbreviation. A reader of the repo has none of those documents. [references/comments.md](references/comments.md) has the patterns.

## What to read, and in what order

This file is enough for most changes. The references carry detail; open the section you need.

| Task | Read |
| --- | --- |
| Planning or designing a feature or refactor | [references/design.md](references/design.md), then [references/checklist.md](references/checklist.md) |
| Any change at all — where boundaries belong | [references/design.md](references/design.md) |
| Writing or judging comments, test names or commit messages | [references/comments.md](references/comments.md) |
| Anything touching <!-- fill: the paths of the modules that talk to the runtime or the pinned dependency, e.g. `src/server/`, `src/adapters/` --> | [references/checklist.md](references/checklist.md) |
| Reviewing a diff, branch or file | [references/review.md](references/review.md) |

## How to work

### 1. Orient

- Read the files you will change in full, plus their tests.
- Look at what the repo and the pinned dependency already provide before writing a helper. <!-- fill: one sentence naming where shared helpers live, e.g. "Shared helpers are in `src/util/`."; delete if nowhere -->
- **Trust the pinned copies, not memory, not a blog post, not any plan, not this skill.** The copy this repo builds against is in `{{pinned-truth}}`. When you need a signature, a lifecycle rule or a data shape, read it there. [references/checklist.md](references/checklist.md) says where.
- Know which runtimes, versions and consumers your change reaches. <!-- fill: one sentence naming where the repo's docs describe them, e.g. "`README.md` lists the supported versions." --> Read that; do not recite it.
- If a task description or a plan disagrees with the tree, the tree wins. Say the disagreement out loud before implementing either one.

### 2. Decide the shape before writing

State the interface first: what goes in, what comes out, what it promises. If that takes more than a few sentences, the unit is doing too much or hiding too little. Then apply the defaults below — and when two defaults point different directions for a structural choice, that is an "ask first" moment, not a coin flip:

| Question | Default |
| --- | --- |
| New function or inline? | Inline, until the piece has a contract you can state without describing its body |
| Share with similar code? | Not at the first use. At the second, only if the two must change together |
| New option, field, mode or hook? | Only with a production caller that passes it today. A test is not a caller, and neither is a later change |
| Optional or required? | Required, if production always passes it |
| Class or function? | Function. A class when there is state with a lifecycle |
| New dependency? | No. Write the twenty lines |

<!-- fill: one more table row per repo-specific default, in the same two-column form (where state lives, how behaviour varies per consumer, what a new route or command costs); delete if none -->

### 3. Write

- The entry point wires things together. Each concern lives in its own module. Split logic from runtime wiring only when the logic has a contract of its own; a small unit is one file, tested through what it registers or exports.
- Depend on the narrowest shape you use. It keeps tests small and survives upgrades.
- Validate at the boundary, where data this repo did not produce comes in. <!-- fill: one sentence listing those edges, e.g. "Here that is request bodies, files on disk and the environment." --> Narrow `unknown` there; never cast. Trust your own types inside.
- Throw errors that tell the reader what to do next.
- Comments, per [references/comments.md](references/comments.md): none by default; one line when a reader would otherwise guess wrong or wonder why; `/** */` on exports whose signature leaves a caller's question open.
- Write the test in the same change, against the public interface, named for the property it protects.

### 4. Verify

The gates are whatever scripts `package.json` defines when you run them; read it, do not recite it. At the time of writing, `{{gates}}` runs them all: run it from the repo root and read the whole output. The gates say nothing about runtime contracts; [references/checklist.md](references/checklist.md) has the standing checklist and the probes. For behaviour that only shows up in the running system, run it. <!-- fill: one sentence naming where the repo's docs keep the commands to start it, e.g. "`README.md` has the commands."; delete if there is nothing to start -->

Report which gates you ran and which runtime paths you did or did not exercise. "The suite passes; I did not exercise it in the running system" is a complete and useful statement. When something you need is out of reach, carry on and list what stayed unverified.

### 5. Hand over

Report what changed and why, what you verified and how, and what you noticed but left alone. Commit only when asked, staging the files you changed by path. Each commit:

- passes every gate on its own; none is red, even in the middle of a series
- is one change, typed by its content: a `refactor` changes no output, a `test` touches only tests, and any observable change (a message, a field, an order, a status) is a `fix` or `feat`
- ships the test of the behaviour it changes, and the docs and comments it makes false
- is a subject, a blank line, and a body only where the diff does not say why; it cites nothing outside the repo: no plan, research note, review, step id or scenario number
- does not exist to repair the previous one; amend the series before it is shared instead

On a rename or a move, grep the old name, path and wording across the source, tests, comments and the README in the same commit.

## Refactoring

A refactor changes structure and keeps behaviour. That is only checkable if the two are kept apart.

1. Make sure tests cover the behaviour first. If they do not, add them and confirm they pass before moving anything.
2. Change structure in one commit, behaviour in another.
3. After moving code, re-read the control flow. Early exits, ordering of side effects and error paths are what extraction breaks.
4. Re-read every comment near what you moved. A comment that was true is now possibly false.
5. Stop when the code passes the priorities at the top. Tidier is not a goal.

## Acting with confidence

Be decisive where you have grounds, and open about where you do not.

**Go ahead without asking when:**

- a runtime contract is broken and the fix is local
- a comment cites a document or a step id, restates code, records history, or is no longer true
- a test cannot fail
- a helper has one caller and hides nothing
- an `any` or a cast can be replaced by the real type or a narrowing
- code exists only for a later change and nothing calls it

**Say what you would do and ask first when:**

- code looks deliberate and you cannot find the reason
- the change alters a public interface or a format someone else reads, or removes behaviour
- the fix is outside the task you were given
- two defaults above point in different directions and the choice affects structure

**Push back when** asked for something that breaks a runtime contract or adds speculative machinery. Say what will go wrong, concretely, and offer the simpler route. Then do what is decided.

Do not hedge to seem careful. State what you verified as fact, mark what you inferred as inference, and leave out the rest.

## Reviewing

Follow [references/review.md](references/review.md): design first, then runtime contracts, then readability; findings in order of consequence, each with the concrete failure it causes.
