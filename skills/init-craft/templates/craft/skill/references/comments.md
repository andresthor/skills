# Comments

A comment carries what the code cannot say: a reason, a constraint, a consequence. Everything else belongs in a name, a type, or nowhere.

<!-- fill: rewrite each code block in this file in the repo's main language and its comment syntax, keeping what it shows; then delete this comment -->

## Contents

- [Two kinds](#two-kinds)
- [What goes in an interface comment](#what-goes-in-an-interface-comment)
- [What goes in an implementation comment](#what-goes-in-an-implementation-comment)
- [What never goes in a comment](#what-never-goes-in-a-comment)
- [Documents outside the repo](#documents-outside-the-repo)
- [Before and after](#before-and-after)
- [When you are refactoring](#when-you-are-refactoring)
- [Sources](#sources)

## Two kinds

| | Interface comment | Implementation comment |
| --- | --- | --- |
| Syntax | the language's doc comment: `/** … */`, a docstring, `///`, a `// Name …` block above a Go declaration | a line comment: `// …`, `# …` |
| Reader | someone calling the code, who should not have to open it | someone changing the code |
| Says | what the caller can rely on and must provide | why the code is the way it is |
| Length | as long as the contract needs | one line; two at most |
| Default | present on exports whose signature leaves questions open | absent |

Most function bodies need no comments. Most exported functions with any subtlety need one above them. If a body seems to need several, the code is asking to be simplified first.

## What goes in an interface comment

Take the signature and list what a caller still cannot know. Those answers are the comment.

```ts
export function addTodo(text: string, after?: number): Todo;
```

Open questions: is `text` trimmed, and is empty allowed? Is `after` an id or an index, and what happens when it does not exist? Are duplicates merged? Does this persist, or only change memory?

Things that belong there, when they apply:

- side effects, above all on a function whose name sounds pure
- preconditions the caller must uphold, and ordering between calls
- what happens at the edges: empty, missing, duplicate, too large
- units and formats (`timeout` in ms, paths absolute or relative to what)
- whether it throws, and on what
- which inputs are untrusted and what has been done about it
- for a module header: what the module is for and the one design decision a newcomer would otherwise question

Leave out per-parameter and return lines (`@param` and `@returns`, `Args:` and `Returns:`, `# Arguments`) that restate the name and type. Keep one only when it adds a constraint:

```ts
/** @param timeout Milliseconds. `0` disables the timeout. */
```

Never repeat in a doc comment a type the signature already declares.

## What goes in an implementation comment

The test: **would a competent reader, seeing only the code, guess wrong or wonder why?**

Worth a comment:

- **A reason the code cannot show.** Why this order, why not the obvious approach, why a value is what it is.
- **A constraint from outside.** A service that rejects a schema form, a terminal that interprets a byte, a host that loads modules in a particular order, a library that awaits each handler in turn, a browser that limits open connections.
- **An invariant that later code depends on.** "Entries stay sorted by id; `find` below relies on it."
- **A consequence that is invisible at the call site.** A performance cliff, a security property.
- **What a dense expression does, in logical terms.** A regular expression or a bit of index arithmetic may get a line saying what it matches or computes. That is a "what", and it is allowed because the code cannot say it plainly.

State the fact, with its reason, in one line: "Sorted by id; `find` below stops at the first match". It stays true until the code changes.

## What never goes in a comment

- **The code again.** `// loop over segments`, `// register the handler`, `// return the result`.
- **The name again.** `/** Renders the row. */` above `renderRow`.
- **History.** What the code used to do, what was fixed, which change or step added it, what a report flagged, what "is not wired yet". That is the commit message's job, and the comment is wrong as soon as the next change lands.
- **A citation of a document outside the repo.** A plan, a research note, a spike, a debate, a step id. See [Documents outside the repo](#documents-outside-the-repo).
- **People, dates, tickets, decisions.** "Per discussion with…", "as of March", "decided to…".
- **Instructions to the reviewer or notes to self.** "Note: changed this to…", "Important!".
- **Hedging.** "This should work", "probably safe". Find out, then state it or remove it.
- **An unchecked claim.** A comment that asserts a property ("escapes control text", "derived from X", "written only through Y", "the library's default") needs a test, a probe or a citation behind it, or it goes. A claim about another module is grepped before it is written.
- **Section banners and decoration.** If a file needs a table of contents it needs splitting.
- **Commented-out code.** Git has it.
- **A joke or an allusion.** The reader who needs the comment is the one who will not get it.
- **`TODO` without substance.** If it stays, it says what is missing and what breaks without it. Better: do it, or leave it out.

## Documents outside the repo

Work on a repo often starts from documents that live outside it: a plan, research or design notes, a spike. <!-- fill: one sentence naming the kinds of outside document this repo's work comes from; delete if none --> A reader of the code has none of them, and the documents keep changing after the code ships. So a citation is a dangling pointer on the day it is written and a false one soon after. The same holds for test names and commit messages.

Never write, in a comment, a test name, or a commit:

| Pattern | Examples |
| --- | --- |
| A research or plan document | `research/03-options.md §4`, `plan.md "step 5"`, "the design review settled" |
| A step, row, invariant or scenario id | `// B6`, `step 8's loader.ts`, `row 9a`, `invariant 15`, `(S7)`, `"row 9a: …"` as a test name |
| A spike or probe | `spike/prototype.mjs`, "probe 6's file", "the gate's recipe" |
| History of the build | "the review flagged", "stubs until step 8", "no production caller yet", "empirically-verified correction" |
| A private abbreviation for another codebase | `LIB/main.js:353-438`, `UP:2998` |

A published, versioned standard is not one of these: `RFC 9110 §15.4` names a document every reader can open.

What to do instead:

- **The document held a reason.** State the reason itself, as a present-tense fact about the code, in one line. If it takes a paragraph, the code needs simplifying first.
- **The document held a contract of a dependency or protocol.** Name the module and the behaviour by their public names (`Client.send` resolves after the server acknowledges), and pin it with a test. A line number into a dependency's installed files rots at the next release; the test does not.
- **The id marked a step of a recipe.** If the steps matter, the function names say them. A numbered list of bare ids is a reading guide to a document the reader does not have.
- **The code is for a later change.** Delete it. It comes back with that change, and its caller.
- **A test was named for a scenario.** Name it for the property it protects; a scenario id says nothing to someone who reads the test list to learn the contract.

## Before and after

**A citation turned into the reason it pointed at.**

```ts
// Before
// B4: defaults only + proxy, before any network (research/03-options.md §2).
const config = loadConfig(dir, { userFile: false });

// After
// Defaults only until the user's file is validated below; the proxy is set before any network call.
const config = loadConfig(dir, { userFile: false });
```

**A module header that read like a build log.**

```ts
// Before
// The importer: runs research/03-options.md §2's phase B recipe (rows B1, B3-B14; B0 and
// B2 are step 8's concerns), the production port of spike/prototype.mjs. Built standalone first.

// After
// Imports one validated file: version check, schema, duplicates, then write.
```

**Narration removed, reason kept.**

```ts
// Before
// Write the response
connection.write(line);
// Flush the output
await drain();

// After
connection.write(line);
// Exit waits on this: an unflushed pipe loses the last response on a fast exit.
await drain();
```

**History turned into a fact.**

```ts
// Before
// Switched from message identity to callId after the identity assumption turned out false

// After
// Keyed on callId: the library emits a new message object for each lifecycle event.
```

**A side effect a caller would not expect.**

```ts
// Before
function nextId(): number

// After
/** Returns an unused id and reserves it; two calls never return the same value. */
function nextId(): number
```

**A comment that should have been a name.**

```ts
// Before
const t = 50 * 1024; // max bytes

// After
const MAX_OUTPUT_BYTES = 50 * 1024;
```

**A comment that should have been a type.**

```ts
// Before
/** action must be one of "list", "add", "toggle" */
function run(action: string)

// After
function run(action: "list" | "add" | "toggle")
```

**A reason that was a name in disguise, and one worth keeping.**

```ts
// Before
// Resolve the path
const target = resolve(root, rel);
// Check the root
if (!target.startsWith(root + sep)) throw new Error(`${rel} is outside ${root}`);

// After
const target = resolve(root, rel);
// With the separator, so `/repo-old` does not pass as inside `/repo`.
if (!target.startsWith(root + sep)) throw new Error(`${rel} is outside ${root}`);
```

**A long comment that was really a design problem.** Eight lines explaining how three helpers cooperate mean the three helpers are one function. Merge them; the comment shrinks to the one sentence that was the actual idea.

## When you are refactoring

- A comment is part of the code it describes. Moving or changing the code without re-reading the comment leaves a false statement behind, which costs more than no comment. After a change, restate every nearby comment as a present-tense fact, and delete derivations of formulas that no longer exist.
- Do not delete a comment because it breaks a length rule. First ask what it knows. A four-line comment recording a real constraint gets tightened, not removed.
- Do not add comments to code you did not otherwise change, to explain what you learned by reading it. If it was truly non-obvious, one line; if you merely had to read it, none.
- Write the comment for someone who does not yet understand the code. The author's own understanding is what makes a comment feel unnecessary, or makes a cryptic one feel clear. Re-read it cold before finishing.

## Sources

- Ousterhout and Martin, *APOSD vs Clean Code*, comments section — <https://github.com/johnousterhout/aposd-vs-clean-code>
- <!-- fill: keep the line below for this repo's language and delete the others, with this comment --> Google TypeScript Style Guide, comments — <https://google.github.io/styleguide/tsguide.html#comments-documentation>
- Python, *PEP 257: Docstring Conventions* — <https://peps.python.org/pep-0257/>
- *Go Doc Comments* — <https://go.dev/doc/comment>
- The rustdoc book, *How to write documentation* — <https://doc.rust-lang.org/rustdoc/how-to-write-documentation.html>

Where the maintainer's own instructions are stricter, they win.
