# Migrating a format-1 pointer

Read this only when `HANDOFF.md` exists and its first line is not `<!-- handoff-format: 2 -->`. Format 1 used numbered `## N` blocks with a free-text `status:` line; pickup cannot compare those fields, so the file is converted once, by you, before either skill continues. The user never runs anything here.

`<scripts>` is the `scripts/` directory beside the handoff `SKILL.md`.

1. Tell the user in one line that the pointer is in the old format and you are converting it, keeping the original as `HANDOFF.md.format1.bak`.
2. Dry run: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> migrate`. It prints the converted file and, on stderr, one note per problem it could not resolve. Show the user the block headings and the notes, nothing more — the converted blocks are mechanical.
3. Apply: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> migrate --write`.
4. Resolve each note. The common ones:
   - `handoff must end in handoff.md` — the block pointed at a `plan.md` or a file outside the layout. If the project is still active, write a real `handoff.md` for it in its project dir (a normal entry whose Key paths name the plan) and re-run `upsert` for that slug; if it is not, `remove --slug <slug>`.
   - `handoff file does not exist` — the path was mistyped in the old pointer. Find the project dir, then `upsert` with the right path, or `remove` if the dir is gone.
   - `branch … appears in more than one entry` — pickup resolves by branch and cannot pick between them. Keep the block for the live effort; `remove` the other (it is usually marked superseded).
   - `next` reads `TODO: set with handoff-pointer upsert …` on every migrated block. That is intended: an old status is not a next step. Leave them; each project's next `/handoff` rewrites its own block. If the user asks for a next now, take it from the top entry of that project's handoff file, never from the old status.
5. Prune: `python3 <scripts>/handoff-pointer.py <HANDOFF.md> check --dead` lists blocks whose head is already in `origin/main`. Offer `handoff-pointer.py <HANDOFF.md> prune` and, for dead blocks the migration did not mark `done`, `remove --slug <slug>`. Remove nothing without the user's yes.
6. `python3 <scripts>/handoff-pointer.py <HANDOFF.md> check` must exit 0 before you continue with the skill that sent you here. Report what changed in three lines: blocks converted, blocks removed, notes left for the user.

Handoff files themselves need no migration: the lint checks only the top entry, so old entries stay as they are and the first new entry on each project is written to the new limits.
