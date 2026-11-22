# Design judgement

How to decide where a function boundary goes, when to share code, and when to leave working code alone. The examples are invented for illustration. They are not descriptions of code in the repo, and nothing in the repo is endorsed by appearing similar.

## Contents

- [The one test](#the-one-test)
- [Function boundaries: depth, not length](#function-boundaries-depth-not-length)
- [State and ownership](#state-and-ownership)
- [Sharing code: two real uses, then watch for flags](#sharing-code-two-real-uses-then-watch-for-flags)
- [Undoing a wrong abstraction](#undoing-a-wrong-abstraction)
- [Build for the problem you have](#build-for-the-problem-you-have)
- [Types](#types)
- [Errors](#errors)
- [Tests](#tests)
- [Refactoring someone else's code](#refactoring-someone-elses-code)

## The one test

Every design choice here reduces to one question: **does this change reduce what a reader has to hold in their head, or make what they need easier to find?** If it does neither, it is not an improvement, however much tidier it looks.

Length, duplication count and number of files are proxies. When a proxy and the test disagree, the test wins.

## Function boundaries: depth, not length

A function is **deep** when it does a lot behind a small interface, and **shallow** when the caller needs to know nearly everything the body does in order to use it.

Take a function that turns a to-do list into the text a reader sees:

```ts
function describeTodos(todos: Todo[]): string
```

It decides the order, how done items are marked, what an empty list says and where a long list is cut. The caller knows none of that and passes one argument. That is deep.

Splitting it for the sake of size produces this:

```ts
// Shallow: each piece is as complicated to use as to read, and the rule that the
// notice counts what was dropped now has to be known by every caller.
const sorted = sortTodos(todos);
const shown = takeFirst(sorted, LIMIT);
const lines = shown.map(formatTodo);
const text = joinWithNotice(lines, sorted.length - shown.length);
```

**Before extracting, check:**

1. Can you describe what the new function does without describing how? If the honest description is the body read aloud, leave it inline.
2. Is the new function independent of its parent? `e.shouldPayToday()` reads fine without opening it. A helper that only makes sense given the caller's loop state does not.
3. Does it hide anything? A one-line wrapper with a longer name than its body hides nothing.

**Signs of entanglement, where merging is the fix:**

- You flip between two functions to understand either.
- A function named like a question changes state. `isOverLimit(text)` that also decrements the remaining budget will be called twice by someone, correctly assuming a predicate is safe to repeat.
- A helper needs its caller to uphold a rule ("must be called with increasing offsets") that is written down nowhere.
- A name has grown to a sentence. The length is standing in for an interface that is too complicated.

**Extraction can change behaviour.** Splitting one loop into "advance the state" and "test the state" removes the early exit that the combined loop had. After moving code, re-read the control flow: `break`, `continue`, early `return`, and the order of side effects.

A 60-line function that reads top to bottom in distinct steps is fine. So is a 3-line one that names a real idea. Neither number tells you anything.

The same test applies to files. A header that has to list several jobs describes that many modules; a module whose whole logic fits in its one caller is not a module.

## State and ownership

- One writer per mutable field. When a second module assigns it, move the field to whoever owns its lifecycle and give the others a read-only view.
- Wiring code (the entry point, a setup function) hands each unit what it needs and holds nothing else. State with a lifecycle (a child process, a timer, a pending dialog) lives in a unit with an explicit start and stop, testable without the real runtime.
- Pass configuration as an argument or a getter, never by mutating an object another object already holds.
- The unit that makes a decision exposes it. A renderer maps facts to marks; it never re-derives a rule the state machine enforces. The owner of a deadline exposes the time left, and a threshold the user sees is a named constant of the module that enforces it.
- One clock per feature: once a `now` seam exists, every time read in that feature goes through it.
- Keep a value in the unit its consumers compare it in. A representation that is only ever converted back is a second source of truth.
- Guard independent side effects one at a time, so a throw in the first never cancels the second.

## Sharing code: two real uses, then watch for flags

Write the first use concretely, in place. Do not make it reusable. With one example you will guess the wrong interface.

On the second real use, extract what the two actually share, and let both instances shape the interface. When the repeated lines share interacting local state (a cursor, a remaining-width budget), bundle that state first and then write functions over it.

Two uses are necessary, not sufficient. Ask what kind of code it is:

| Repeated code is… | Example | Share it? |
| --- | --- | --- |
| Mechanical plumbing, identical by nature | narrowing an `unknown` to an object, writing a line to stderr, escaping text for one output format, truncation notices, resolving a path argument, a severity union | Yes, at the second use |
| Domain behaviour that happens to look alike today | how the live view and the replay each turn an event into a row | Probably not; they will diverge |
| Similar by coincidence | two schemas that both have `path` and `limit` | No |

The question that separates the rows: **will these cases need to change independently?** If a change to one should not automatically change the other, they are not the same thing, and sharing them turns every future edit into a negotiation.

Prefer deriving a value over keeping two in step. A list of names kept beside the type that declares them will drift; derive one from the other, or check them against each other once. A count declared at the top and items added below will drift too: compute it from what was added, and take a size from the value itself (`buffer.byteLength`) instead of a number kept beside it.

One copy of a rule, not two that agree today. Two parsers of the same environment variable, two clock types, two severity unions: one of them is wrong after the next change.

## Undoing a wrong abstraction

The signal: a shared function gains a parameter or a branch so that one more caller can use it.

```ts
// Each flag was a reasonable request. Together they mean no caller runs the same code.
renderRow(theme, args, { showPath: true, showCount: false, compact: true, asError: false });
```

Do not repair it in place, and do not add the next flag. Existing code argues for its own survival, and the more complicated it is the harder it argues.

1. Inline the shared function into every caller.
2. In each caller, resolve the flags to constants and delete the branches that caller never takes.
3. Look at what is left. Callers that nominally shared code are usually running fairly different code. Extract again only what is truly common, which may be nothing.

A couple of conditionals in shared code can be a fair way to learn what varies. The mistake is staying there.

## Build for the problem you have

- No option, parameter, generic or config key without a caller that uses it today.
- No fallback for a case you cannot name. A `catch` that swallows and continues hides the bug it was meant to handle.
- No compatibility shim for an interface with no consumers. Where there is a consumer (another repo, a deployed client, stored data), the shim is real work and needs a test.
- **Nothing for a later change.** No state nothing produces, no mode no caller selects, no hook that does nothing yet, no error constructor nobody throws. However certain the later change is, the code it needs comes with it, shaped by its real caller.
- **Whatever this repo adds is paid for where it runs.** On a hot path, at startup, in every call: a feature has to earn its place there as well as in the code. <!-- fill: one sentence on what the cost is in this repo (latency on a hot path, startup time, bundle size, prompt size) -->
- The plainest construct that works: a function before a class, a literal before a registry, a `switch` before a plugin system.

A roadmap invites the opposite: what is coming is known, so writing it early looks like saving time. It is not. Code nobody calls has no test that can fail, guesses its interface, and has to be read by everyone until the day it is used or deleted.

## Types

- `unknown` for a value you pass through or have not yet checked; narrow before use. `any` switches the checker off for everything it touches.
- No `as` to silence an error. A cast is a claim that the compiler cannot verify, so it needs the reason next to it when the reason is not obvious. At a boundary (input from outside, a dependency's callback payload, a file) a cast is never right: the value is untrusted and the cast is how a malformed one reaches the rest of the system. Narrow it. Casting the same value at every use means its type is not wired through; fix that once.
- No `@ts-ignore`. `@ts-expect-error` on a single expression with a comment, in tests, when the point is to pass something invalid.
- Derive, do not restate: the type a schema infers for a validated shape, the dependency's own types for what it defines, `typeof import("…")` for a module's shape, `Parameters<…>` for a callback. A hand-copied type is a second source of truth.
- Depend on the narrowest shape you use. A function that calls two methods of a large object should ask for those two; its test then needs a two-line stub and no runtime. Narrow the shape, not the types inside it: an id stays `UserId`, not `string`.
- Unions in one position before overloads; optional trailing parameters before overloads that differ only in arity.
- A callback parameter is optional only if the callback may really be invoked without it.
- Export what another module uses. An export is a promise; an unused one is a promise nobody asked for.
- **A test is not a caller.** An export only tests import is allowed when it is a contract in its own right: a docblock that states it, an `@internal` tag, and a test that pins a property the public entry cannot reach cheaply (a URL validator, a parser). Otherwise test through the entry and drop the export.
- An optional parameter or field that production always passes is required; a default that only tests rely on is a test-only export by another name. A seam production never passes (a stub fetch, a clock) is one optional `deps` object on a documented entry, defaulting to the real thing, never a scatter of optional fields across several option types and never an option threaded through the entry point.
- Never export a constant so a test can avoid restating its value. A test that derives its expectation from the code's constant cannot fail when the constant moves; the test states the number.
- **Unused things never exist: no unused imports, constants, exports, parameters, or fields — ever.** That is a rule of this skill, whether or not a tool checks it. <!-- fill: if the gates run an unused-code checker, one or two sentences on how it runs and which tags or ignores it honours; delete if not --> A tag or ignore added to quiet a checker is the finding the checker was about to report. Types follow the function whose signature they carry and are not tagged. No tool sees an optional field nobody sets, a field nobody reads, or a return value every caller drops; check those by hand before considering any change done.

## Errors

- Write the message where it is thrown. A message factory earns its place only when two sites throw the identical message; a module of one-caller factories puts every reader in two files.
- Throw with a message that says what was attempted and with what input. The reader is a person, a calling program or a model deciding what to try next: `"no project with id 7; ids are 1–4"` lets them recover, `"invalid input"` does not. <!-- fill: one sentence on who reads an error in this repo (a calling program, an end user, an operator reading logs, a model) -->
- Pick the error code or class by who is at fault: the caller's input, or this code. Where the dependency defines codes or error classes, check against its own rather than memory. One rule per failure kind, applied everywhere: if two paths report the same failure differently, one of them is wrong.
- Catch where you can do something about it: add context and rethrow, turn an expected condition into a normal result, or clean up. Otherwise let it propagate to the boundary that reports it. The exception is code that runs outside any such boundary: event listeners, stream events, timers, promise continuations. There a throw can end the process, so guard each such entry once and keep the cause.
- Every failure keeps its cause (the status, the errno, the vendor's reason, sanitised and clipped) and names the next step, in a message to a user as much as in a log line. A message about missing configuration names each missing or malformed item.
- `catch (error: unknown)` and narrow with `instanceof Error`.
- Validate at the boundary (input from outside, a dependency's callback payloads, files, environment, responses from other services) and trust the types inside. Defensive checks on values your own code just produced are noise.

## Tests

- Test behaviour through the interface a caller uses. A test that names a private helper has to be rewritten by every refactor, which removes the reason to have it.
- Write the test alongside the code, in the same change. Designing a unit and then testing it is as good as test-first; shipping it untested is not.
- A test earns its place by failing when the code is wrong. Check that it can: break the code and watch it go red.
- Name the test for the property, in plain words: "a done item sorts after every open one". A reader should learn the contract from the test names alone. Never a plan row or scenario id: `"row 9a: …"` or `"(S54)"` tells them nothing.
- Keep the runtime out where you can. Pure functions with structural stubs run in milliseconds and do not break on a dependency release. For code that needs the real thing (the file system, a child process, signals, a real parser), use the real thing, offline where possible; a hand-written fake is for what cannot run, and then it has the methods you call, not a re-implementation.
- Drive the path a user or caller takes: the command, the request, the exported function. A test that calls an internal nobody can reach proves nothing about what they see.
- Assert properties of the output (the order of items, a field present, nothing unescaped), not exact bytes or timestamps; byte pins turn every harmless reformat into a fake behaviour change.
- Time is fake: unit tests drive timers with fake timers and the injected clock. Tests of the running system wait on an event or an observable state. No real sleeps, no polling with `waitFor`.
- Test helpers are shared like any other plumbing: one helper, not a copy per test file. <!-- fill: one sentence naming where shared test helpers live, e.g. "They are in `test/support/`."; delete if nowhere yet -->
- Tests are code. The same rules on duplication and clarity apply, with one allowance: a little repetition in tests is better than a helper that hides what is being asserted.
- Put the contract and security properties under test first: what must never reach a user, a log or the disk; what a malformed input does; what must not outlive the process. <!-- fill: this repo's own must-never properties, one sentence each -->

## Refactoring someone else's code

- Keep a refactor and a behaviour change in separate commits. A reviewer cannot verify "no behaviour change" in a diff that also changes behaviour.
- Stay inside the task. An unrequested restructuring of neighbouring code, however much better, costs the owner a review they did not plan and may undo a decision you cannot see. Say what you noticed and leave it.
- Before removing something that looks pointless, find out why it is there: `git log -S`, `git blame`, the tests. If you still cannot tell, ask.
- Existing code is evidence of what was needed, not proof of how it should be written. Follow local naming and layout so the file reads as one piece; do not copy a pattern you can see is wrong just because it is already there. Flag it.

## Sources

- John Ousterhout and Robert Martin, *APOSD vs Clean Code* — <https://github.com/johnousterhout/aposd-vs-clean-code>
- Sandi Metz, *The Wrong Abstraction* — <https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction>
- Dan Abramov, *Goodbye, Clean Code* — <https://overreacted.io/goodbye-clean-code/>
- Casey Muratori, *Semantic Compression* — <https://caseymuratori.com/blog_0015>
- TypeScript Handbook, *Do's and Don'ts* — <https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html>
- Google, *What to look for in a code review* — <https://google.github.io/eng-practices/review/reviewer/looking-for.html>
