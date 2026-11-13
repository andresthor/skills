# .context — generated workspace (never committed)

Local home for generated documents and working material. `CLAUDE.md` here is a symlink to this file.

- `projects/<YYYY-MM>/<NN-slug>/` — working material for one effort, all in its one folder: `plan.md`, `notes.md`, `research/`, `handoff.md`, …. Grouped by month; `NN` counts within the month (`01-…`, `02-…`).
- `output/<skill>/` — skill- and agent-generated deliverables, one folder per skill.
- `research/` — reference material that outlives a single effort. May be shared with other repos.
- `notes/` — free-form notes. May be shared with other repos.
- `HANDOFF.md` — index of active handoffs. The handoff tooling writes it; do not edit it by hand.

Rules:

- `projects/`, `output/`, `research/` and `notes/` may be symlinks out of the repo. Resolve the absolute path before handing one to a tool or a subagent.
- In `output/` buckets, name files `YYYY-MM-DD-<slug>.md` — date first, no counting (agents miscount when appending to a shared bucket).
- Inside a project folder, authored and ordered docs may use an `NN-slug` prefix (`00-plan`, `01-design`, …). That is a human-curated sequence, so numbering is fine. Plain conventional names (`handoff.md`, `notes.md`) are fine too.
- Never commit anything from this directory.
- Prune freely — everything in `output/` is disposable once consumed.
