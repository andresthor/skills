# Reviewing a change

For a diff, a branch, or a file someone asks you to assess. The order matters: a design problem makes the line-level findings beneath it irrelevant.

## Before forming an opinion

1. Read every changed file in full, not only the hunks. Four added lines can be the ones that tip a function over.
2. Read what the change is for: the commit messages, the task, the tests.
3. Inspect without moving the working tree: `git diff main...HEAD`, `git show <ref>:<path>`, `gh pr diff`. Do not check out, stash or reset; someone else may be working in it.
4. Run the repo's gates yourself, as [SKILL.md](../SKILL.md) says under Verify, from the repo root, and read the full output.
5. Probe what you doubt. A ten-line script that feeds the function or the entry point awkward input (a missing field, the wrong type, empty, very long, control characters, an unknown kind, the same call twice) settles more than reading does. Write it outside the repo and remove it afterwards.
6. Where a claim depends on what the dependency does, read the copy pinned in `{{pinned-truth}}` and cite the file. Where it depends on tree state (what is declared, what exists, which branches carry what), read the tree — and say that you checked it, because it may have moved by the time anyone reads your review.

When there is no diff, because you were given a file, a package or a scaffold, review it as it stands. Code with no caller yet cannot be judged on whether it should exist; judge whether the interface it promises is one you would want to be held to, and check `package.json` and `tsconfig.json` as part of the package.

## Pass 1: should this exist, in this shape?

- Does it solve the stated problem, and only that?
- Is anything here for a caller or a case that does not exist yet? A later change is not a caller, and neither is a test: for each export only tests import, check that its docblock states a contract and its test pins a property the public entry could not reach cheaply. A tag or ignore added only to quiet a checker is a finding.
- Is the boundary between modules in the right place? Would a caller need to read the implementation to use it correctly?
- Does it add to what this repo pays for every time it runs: work on a hot path, a handler on a frequent event, size in a bundle or a payload? Is that justified?
- Does it change what crosses to another party: a public export, a file or message format, command-line flags, a contract another repo relies on? Then that side changes with it. Is the change additive (a field renamed or removed reaches consumers still on the older build)? Has each side been checked?

## Pass 2: does it keep the runtime's contracts?

Work through the failure classes in [checklist.md](checklist.md) and check each that could apply. The classes are stable; for any mechanism detail, derive it from the pinned copies as the checklist says. One line per class; these apply to any codebase:

- a value from outside the repo's own code (input, a file, the environment, a dependency's callback) cast instead of narrowed, with no defined outcome for the malformed case
- a throw from code no handler calls through (listeners, stream events, timers, promise continuations), or a floating promise
- a failure returned through the channel its caller reads as success
- state that outlives or underlives what it describes, or is restored without a shape check
- a path that needs a person or a terminal, with no defined behaviour when there is none
- a shape copied from an example along with its casts and error handling, or an import `package.json` does not declare
- a resource not released, or not released idempotently, on every exit path
- untrusted text reaching a terminal, a page or a shell unsanitised
- a secret echoed into an error, a log or a fixture

<!-- fill: append one line per further class in this repo's checklist.md, and delete a line above whose class the checklist dropped; candidates: anything but the intended output reaching the output channel; an outgoing message invalid for its schema or sent out of order; a late answer or event applied to the wrong request; a capability assumed instead of checked; a deferral between an event and the state change that must keep its order; a host object cached past the moment the host can replace it -->

## Pass 3: will the next reader understand it?

- Could you explain each function's contract without reading its body?
- Any predicate with a side effect, any helper that depends on its caller's state, any flag parameter that selects between behaviours?
- Does every comment state something the code cannot? Is every comment still true after this change, including the ones the diff did not touch?
- Would the test names, read alone, tell you what the code guarantees? Would each test fail if the code were wrong?
- `any`, `as`, non-null `!`, `@ts-ignore`: each one present for a reason you can state?
- Is there a rule here that a person has to remember and a compiler flag or a test could enforce instead? Recommend the flag or the test.

## Mechanical sweep

`{{gates}}` already fails on the formatter and linter rules and on `bin/craft-check.mjs`. Read `bin/craft-check.config.mjs` for the current rule list before relying on this one. <!-- fill: one sentence per further mechanical check this repo has and what it catches (an unused-code checker, a commit-message hook); delete if none -->

### Checked mechanically

<!-- fill: keep the lines whose rule `bin/craft-check.config.mjs` enables, add one line per rule the repo defines there, and one per guard test that exists (imports, layout, ignore files) -->

- `empty-catch`: an empty `catch` block, or `.catch(() => {})`
- `boundary-cast`: `JSON.parse(` or `.json(` cast to anything but `unknown`, on one line
- `doc-citation`: a comment citing a plan, research note or spike by its path
- `step-id`: a comment or test name carrying one of the id shapes the config lists; none are built in, so delete this line until the repo lists its own
- `build-history`: a comment recording history or unfinished work
- `foreign-line-ref`: a comment pointing at a line in another codebase or in installed files
- `test-name-citation`: a test name carrying a citation, build history or a foreign line reference

What is left needs a reviewer's eye; every hit needs a reason you can state, or it is a finding:

- a commit line citing a plan, research note, spike, step or scenario id, or a private abbreviation; and the same in a comment or test name in a shape the rules above miss (`grep -nE 'research/|plan\.md|spike/'`, plus the id shapes this repo's plans use)
- a tag or ignore comment that only quiets a checker, and an export only tests import whose test only reads its value
- an `as` cast that is not a narrowing after a `typeof`/`in` check, above all after a helper that the craft-check pattern does not see, or a boundary cast split across lines or made through a variable
- an empty `catch` whose braces sit on separate lines
- an optional field production always passes, a field nobody reads, a return value every caller drops, code for a later change
- a commit that cites something outside the repo, or a `refactor` whose output changed

## Reporting

Lead with the verdict, then findings in order of consequence. For each:

- **Where**: `path:line`.
- **What happens**: the concrete failure, with the input or sequence that triggers it. "A config file with `port: "80"` reaches `listen` as a string and the process exits on an unhandled rejection" is a finding. "Consider validating the config" is not.
- **What to do**: the change, in a sentence or a few lines of code.
- **How sure you are**: say whether you ran it, read it, or are inferring.

Separate what must change from what is preference, and label preference as such. Leave out anything a formatter or linter would raise. Say what was done well when it is worth repeating elsewhere; it tells the author which instincts to keep.

If you did not verify something, say so. If you found nothing, say that, along with what you checked.
