# Checklist — the contracts the type checker and the linter cannot see

This code runs inside {{what-the-code-runs-inside}}. <!-- fill: one or two sentences on who trusts this code and what they rely on it for --> Most contract mistakes pass the type checker, the linter and the suite, and fail later in a mode, an input or a version nobody tried.

This file is two things:

- **Failure classes**: the recurring ways innocent-looking code betrays that trust. They are architectural and are expected to survive dependency releases.
- **The verify method**: how to check the exact mechanics against the copies this repo actually builds against. Mechanics change between versions; never take a specific (a name, a field, an event order) from here, from a plan or from memory without re-deriving it there.

Shelf life: this file describes *kinds* of failure and *how to verify*, on purpose. A line that states a mechanism and can no longer be re-derived from the pinned copies has rotted: delete it.

## Where the truth lives

<!-- fill: one row per source of truth this repo has; fill the empty cells, delete a row that does not apply, and check that every path exists before writing it -->

| Need | Where |
| --- | --- |
| Which dependency and version is pinned | <!-- fill: the manifest and its lockfile, e.g. `package.json` and `pnpm-lock.yaml`, `pyproject.toml` and `uv.lock`, `go.mod` and `go.sum`, `Cargo.toml` and `Cargo.lock` --> |
| The pinned copy | `{{pinned-truth}}` |
| Its contract docs (lifecycle, events, extension points) | <!-- fill: the docs directory inside the pinned copy, or where the docs for the pinned version are --> |
| Its exact types | <!-- fill: the path of its type declarations, stubs or public signatures (`.d.ts` files, `.pyi` stubs or typed sources, the package's exported Go or Rust source) --> |
| What it really does with what you hand it, and in what order | <!-- fill: the path of its shipped source or compiled output; some contracts exist only there --> |
| A protocol, schema or file format this repo reads or writes | <!-- fill: the schema file, or the spec and its version --> |

The pinned copy is the truth for what builds and tests here. A copy installed anywhere else (globally, in another environment, another version in a shared cache) may differ; do not read it.

Before writing a helper, grep the pinned copy's exported declarations for one. Never copy a value the dependency exports: a test that compares your copy with the export means the copy should go. Import the dependency by its package name, never through a path into its installed files.

Code here imports only what <!-- fill: the repo's manifest, e.g. `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` --> declares. When new code needs another module, declare it, or depend on a structural type if the surface is tiny, or write the few lines. Never import a transitive dependency: something that resolves only because another package happens to install it.

## The failure classes

For each: the silent failure, and the check. The checks name *where* to verify the mechanism, not the mechanism.

<!-- fill: 5–12 classes in all. Keep each class below that can occur in this repo, delete the others, renumber, and add the repo's own in the same form: Why / Check / When this goes stale. -->

### 1. Untrusted input cast instead of narrowed

**Why.** Every edge carries data this repo did not produce: arguments from a caller outside it, payloads a dependency passes through, responses from another service, files on disk, the environment. The dependency's types describe a well-behaved producer; a real one is not obliged to behave. A cast or unchecked conversion at the edge passes the checker, and the malformed value then throws deep inside a mapper or reaches a user as malformed output.

**Check.** List every value your change receives from an edge. Each is held as unchecked (`unknown` in TypeScript, `object` in Python, `any` or raw bytes in Go, `serde_json::Value` in Rust) and is narrowed or parsed before use, with a defined outcome for the malformed case: skip with a notice, substitute text, refuse the input. Add a test that feeds the malformed shape through the real path. `craft-check`'s `boundary-cast` rule reads JavaScript and TypeScript only, and catches only some spellings there; a cast after a helper (`prop(x, "content") as …`), `cast(Message, json.loads(s))`, `v.(Message)` without the `ok`, and `serde_json::from_str(s).unwrap()` are the same cast.

**When this goes stale.** When the boundary moves (a new input channel) or the repo adopts a schema validator that narrows at the edge for you; then say which one and delete the manual steps.

### 2. A throw outside any handler

**Why.** An error thrown on the main call path reaches whatever boundary reports errors. An error thrown from an event listener, a stream event, a timer, a promise continuation, a goroutine or a background thread has no such boundary: it ends the process or fails a whole unit of work, and no test of the happy path sees it.

**Check.** For each callback your change registers, ask who catches a throw from it. Guard each such entry once, keep the cause, and report it where the user sees it. Add a test that makes the callback throw. Search for work nobody waits on (a floating promise, a coroutine or task never awaited, a goroutine whose error is dropped): each is awaited or joined, or has a handler that does something.

**When this goes stale.** When the runtime changes how it treats listener errors; re-derive from the pinned copy's source.

### 3. A failure reported as success

**Why.** A call that fails but returns through the success channel: the caller, a program or a model, reads success and carries on with a wrong result.

**Check.** Find the failure path of what you changed. Who is told, through which channel, and does that match what the pinned contract says signals failure? The message says what was attempted, with what input, and what would work.

**When this goes stale.** When the dependency changes how failure is signalled.

### 4. State with the wrong lifetime

**Why.** State kept in memory or on disk outlives or underlives the thing it describes: a session, a request, a branch, a process. Restored state may be old, foreign or left by a failed run.

**Check.** For every piece of state, name what it follows and what resets it. Shape-check anything restored before using it. Never mutate a snapshot you returned. Take storage paths from the caller or the context, never from one installation's layout.

**When this goes stale.** When something else takes over the lifetime (a store, a framework); then name it and delete the manual steps.

### 5. A mode nobody tried

**Why.** The same code runs non-interactive, without a terminal, in CI, or embedded in another program, and only the mode the author used was exercised.

**Check.** Does the change take a path that needs a person or a display? It behaves the same without one, apart from not prompting or drawing, and a safety decision made by asking decides safely when nobody can answer.

**When this goes stale.** When a mode is added or dropped; list the modes again from the repo's docs.

### 6. Examples treated as authority

**Why.** A dependency's shipped examples are the best source of API shape and a poor source of style: code written to be read once.

**Check.** Copy the shape, not the narration comments, casts or error handling. Re-derive what you copied in the pinned docs, and confirm every module it imports is one this repo declares.

**When this goes stale.** When the examples change with a release; re-derive, do not trust what was copied.

<!-- fill: this repo's own classes, as further numbered sections; candidates: a resource started at a layer not every run reaches, or released twice; output with no size bound; untrusted text reaching a terminal, a page or a shell (one shared sanitiser, applied where the text enters); calls that race on a file or shared state; a capability newer than the oldest supported version (feature-detect, never compare versions); a secret echoed into an error or a log -->

## Probing

Where a claim depends on what the dependency does, settle it by experiment or by reading the pinned copy's source, and cite the file.

<!-- fill: the two or three probes always available here, one bullet each (a script that feeds the entry point awkward input; a run with no terminal attached), and one sentence naming where the repo's docs keep the commands to start the running system -->
