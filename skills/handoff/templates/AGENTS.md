# Project documentation

These are the rules for writing documentation for this project.

## Invariants

1. Always read this file (`AGENTS.md`/`CLAUDE.md`) before writing anything in this directory.
2. This file can only be edited by the user OR on explicit command from the user.
3. Each of the main documents has guidance/rules in its header that override any skill instructions that might conflict.
4. If you notice inconsistencies or conflicting information:
   - Fix them if you know that they are the result of a decision made within your session
   - Surface them to the user otherwise
5. Bloat is bad. Progressive disclosure is king.
   - See the rest of this document for what this means.
6. A session that is starting up and/or doing a /pickup *must* read the primary documents prefixed with `00-` in this directory.

## Directory structure

- **Primary documents** live in the root: `00-decisions.md`, `00-handoff.md`, `00-notes.md`, `00-state.md`
- **Additional documentation** is created as either:
  1. A root document with a numbered prefix, starting at `01-` and taking the next free number, f.ex. `01-architecture.md`, `02-dev-process.md`, `03-implementation-plan.md`
  2. A subdirectory numbered the same way, f.ex. `04-figma-designs/<files>`, `05-ux-changes/{research,results}/<files>`
- Root documents and subdirectories share one numbering sequence.
- **Scripts and code** should generally never be included in these directories unless as examples. Results and logs may be collected under appropriate subdirectories.

Note: use useful slugs and use good judgement when dividing up work.

## Writing docs and decisions

- **Agents read these docs.** Use bullets, one fact per line, no prose.
- **Use file and path references** to avoid bloat and encourage progressive disclosure. Agents should know upfront *what exists* but not be forced to ingest everything upfront.
- **Add little per session:** only what the next session needs. Edit or delete before appending.
- **One fact lives in one place.** Check the other docs before writing. On a conflict, ask; never contradict silently.
- **Decisions go only in the project's `00-decisions.md`,** tagged `[user]`, `[agent]`, `[inferred]` or `[<team>]`. Follow that file's header rules.
- **Never record a call as `[user]`** unless the user stated it in chat.
