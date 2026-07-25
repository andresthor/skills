---
name: commit
description: >-
  Creates a Conventional Commit with smart staging and concise messages. Use this skill for EVERY git
  commit — whether the user asks to commit, you're wrapping up a task, or you're committing as part of
  a larger autonomous workflow. Never run git commit directly; always go through this skill.
argument-hint: "[closes|resolves ISSUE-ID]"
allowed-tools: Bash(git add *), Bash(git status *), Bash(git commit *), Bash(git diff *), Bash(git log *)
metadata:
  version: 1.0.0
---

## Context

- Status: !`git status`
- Branch: !`git branch --show-current`
- Recent commits (style reference): !`git log --oneline -5 2>/dev/null || echo "(no commits yet - this will be the first)"`

## Your task

Create a Conventional Commit for the current changes. Do not push without explicit consent from the user.

Classifying and describing the change well requires knowing the *actual* edits, not just the filenames `git status` lists. Get that knowledge the cheapest way that's accurate:

- **You made these changes this session** → you already know them. Work from that; don't reload a diff you've effectively already seen. This is the common case and where re-reading wastes the most.
- **You're coming in cold** (you don't actually know what changed) → read the diff yourself before classifying: `git diff HEAD` for everything, or `git diff HEAD -- <files>` to stay focused on a large changeset.

The point is to read the diff exactly when you need it and not by reflex.

### Step 1: Stage

- **Files already staged** → commit those as-is.
- **Nothing staged** → stage only the files belonging to one logical change. Leave out anything unrelated (a stray build-config edit, an unconnected formatting tweak) and say what you left out and why. When in doubt, leave it out.
- **No changes at all** → report "No changes to commit" and stop.

### Step 2: Classify

From the diff content, decide:
- **Type**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`
- **Scope** (optional): a component/module name, and only when the change is localized to one. Never a ticket/issue ID — those go in the footer, never the scope.
- **Breaking change**: append `!` after the type

### Step 3: Write the message

**Subject**: imperative mood ("add", not "added"), lowercase except acronyms, no trailing period, specific enough to complete "If applied, this commit will…". No filler.

**Body** — usually unnecessary. Add bullets (`- `, lowercase) only for what the diff *doesn't* make obvious; never to restate the subject or itemize every edit. Default to no body or 1–2 bullets. Needing more than 3 is a sign the commit is doing too much, not a target to hit. Bullets follow three hard rules:
- **One physical line each.** If a bullet doesn't fit on one line, it's too detailed — cut it down, don't wrap it onto a second line.
- **One idea each.** Don't smuggle two changes into one bullet by joining them with `;` or "and also". Two ideas means two bullets — or, more often, means you're down in implementation detail that doesn't belong in the message at all.
- **No PR/issue references in bullets** (`#123`, `PR #456`, `see the upstream PR`). Ticket linkage lives in the footer only.

**Footer**: if the invocation argument contains `closes <ID>` or `resolves <ID>`, add `Closes <ID>` or `Resolves <ID>` — no colon. Never guess ticket numbers.

**Commit exactly the subject, optional body bullets, and optional footer you composed — nothing else.** Don't hand-add attribution lines, `Co-Authored-By`, `Generated with …`, or session-link trailers; if your tool emits those, they're governed by its own attribution config, not something this skill tacks on. Before committing, glance at the final message and confirm it carries no lines you didn't write.

### Step 4: Commit

Pass the message with a heredoc:

```
git commit -m "$(cat <<'EOF'
subject line here

- bullet only if it earns its place
EOF
)"
```

### Step 5: Report

```
Committed as `<sha1-short-hash>`

<subject>

<body>
```

### What good vs. bad looks like

A body should explain the *why* and the non-obvious, not narrate the diff:

```
feat: implement tiered guardrail system

- configurable via GUARDRAIL_LEVEL: strict (default) or standard
- deny for nuke-level ops, ask for irreversible-but-sometimes-intentional ones
```

The same commit done badly restates the subject and lists every mechanical edit — `added GUARDRAIL_LEVEL env var`, `added strict mode`, `modified format_message`, etc. If a bullet just echoes what the diff already shows, drop it.

Other failure shapes to avoid:

```
chore(deps): pin parser to 2.1.0-rc4           # subject is fine — the rest is not

- prerelease build (see PR #88) needed for      # references a PR, and wraps onto
  the new flag defaults; repin before release    # a second line — two violations
- drop the retry-count option; backoff is now   # ';' smuggles two changes into
  inferred from the transport                    # one bullet, and it wraps too

Resolves: ISSUE-42                               # colon after Resolves — drop it
Claude-Session: https://…                        # injected trailer — never include
```

