# Migrations

`<scripts>` is the `scripts/` dir and `<templates>` the `templates/` dir beside the handoff `SKILL.md`. The user never runs anything here.

## Pointer

Read this only when `HANDOFF.md` exists and its first line is not `<!-- handoff-format: 2 -->`. Format 1 used numbered `## N` blocks with a free-text `status:` line. Pickup cannot compare those fields, so you convert the file once, before either skill continues.

1. Tell the user in one line that the pointer is in the old format and you are converting it, keeping the original as `HANDOFF.md.format1.bak`. Migrated blocks get no `commits` field, because the old pointer has no git state to compute it from. Pickup runs the merge check for them until the project's next `/handoff` adds it.
2. Dry run: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> migrate`. It prints the converted file and, on stderr, one note per problem it could not resolve. Show the user the block headings and the notes, nothing more.
3. Apply: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> migrate --write`.
4. Resolve each note. The common ones:
   - `handoff must end in handoff.md` — the block pointed at a `plan.md` or a file outside the layout. If the project is still active, write a real handoff file for it in its project dir and re-run `upsert` for that slug. If it is not, `remove --slug <slug>`.
   - `handoff file does not exist` — the path was mistyped in the old pointer. Find the project dir, then `upsert` with the right path, or `remove` if the dir is gone.
   - `branch … appears in more than one entry` — pickup resolves by branch and cannot pick between them. Keep the block for the live effort and `remove` the other (it is usually marked superseded).
   - Migrated blocks have no `next:`. That is intended: an old status is not a next step. Each project's next `/handoff` writes its own.
5. Prune: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> check --dead` lists blocks whose head is already in `origin/main`. Offer `prune`, and `remove --slug <slug>` for dead blocks the migration did not mark `done`. Remove nothing without the user's yes.
6. `python3 <scripts>/handoff-pointer.py <HANDOFF.md> check` must exit 0 before you continue. Report what changed in three lines: blocks converted, blocks removed, notes left for the user.

## Project dir

Read this when a project dir has an older layout (`handoff.md` or `NN-handoff.md`, `decisions.md`, maybe `notes.md`) and the user said yes to adopting the `00-` layout. Nothing is deleted. Old content keeps its words and only changes names.

1. Rename the log: `mv handoff.md 00-handoff.md` (or `NN-handoff.md`), and its `-archive` sibling to `00-handoff-archive.md` if one exists. Replace any preamble above the first entry with the header from `<templates>/00-handoff.md`. Old `## Handoff DATE` entries stay as written. Lint and rotate both read them.
2. Rename decisions: `mv decisions.md 00-decisions.md`, and replace its preamble with the header from `<templates>/00-decisions.md`. Leave existing lines as they are. Lint reports them as pre-existing warnings, and they get reformatted when someone edits them.
3. An old `notes.md` held reference material (run records, SHA maps, rationale), which is now a numbered doc. Rename it to the next free number, e.g. `mv notes.md 01-reference.md`.
4. Copy whatever is missing from `<templates>` (`00-state.md`, `00-notes.md`, `AGENTS.md`), and write `CLAUDE.md` holding the single line `@AGENTS.md` if it is absent.
5. Fill `00-state.md` from what you can verify now: the aim, the known facts with source tags, and the unknowns the user has raised. Do not copy the old entry's open decisions or watch-outs unless the user confirms they still stand. Those fields were often filled for the sake of filling them.
6. Carry on with the handoff. Step 8's `upsert` moves the pointer to the new `00-handoff.md` path.
