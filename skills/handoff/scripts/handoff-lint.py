#!/usr/bin/env python3
"""handoff-lint: mechanical checks on a handoff entry (the top one by default) and optionally decisions.md.

usage: handoff-lint.py <handoff.md> [--all] [--decisions decisions.md] [--json]
exit 0 clean · 1 errors found · 2 usage / parse error

Errors are the rules a handoff entry cannot meet by rewording: structure, and size measured in characters.
Warnings are density signals a reader would notice; they never fail the run.

  H1  heading is `## Handoff YYYY-MM-DD` (an optional ` HH:MM` for a second entry the same day), nothing else
  H2  every entry after the first is preceded by a `---` divider
  H3  entries are newest on top
  S1  the five sections are present, in order, with no other bold labels
  B1  entry ≤ 1,800 characters                                   (error)
  L1  no line over 160 characters, code spans excluded           (error)
  L3  no `;` outside code spans                                  (error)
  N1  first Next-up item starts with a command, a slash-command, or `ask —`   (warn)
  L2  a line holds more than one sentence                        (warn)
  L4  more than one em-dash in a line beyond the label's own     (warn)
  L5  more than one parenthetical in a line                      (warn)
  T2  fenced block longer than 8 lines — point at a file instead (warn)
  D1  decisions.md line is about the agent, not the project      (warn)
  D2  decisions.md line over 160 characters                      (warn)
  D3  decisions.md over 40 lines, or holds headings / nesting / strikethrough   (warn)
"""
import json
import os
import re
import sys

ENTRY_MAX_CHARS = 1800
LINE_MAX_CHARS = 160
DECISIONS_MAX_LINES = 40
SECTIONS = ["State now", "Next up", "Open decisions", "Key paths & commits", "Watch-outs"]
HEADER_RE = re.compile(r"^## Handoff (\d{4}-\d{2}-\d{2})( \d{2}:\d{2})?(.*)$")
LABEL_RE = re.compile(r"^\*\*([^*]+)\*\*\s*(—\s*(.*))?$")
CODE_RE = re.compile(r"`[^`]*`")
NEXT_OK_RE = re.compile(r"^(`|/|ask —|ask -|[a-z]+ )")
SELF_REF = re.compile(r"\b(I|I'm|me|my|myself|you|your|this session|the model|the agent)\b", re.I)
SELF_TOPICS = re.compile(r"\b(fetch|cite|spawn|subagent|concise|verbose|doc style|communication|workflow|tooling|lesson|always|never)\b", re.I)


def strip_code(s):
    return CODE_RE.sub("`x`", s)


def sentences(s):
    s = strip_code(s).strip()
    return len([p for p in re.split(r"(?<=[.!?])\s+(?=[A-Z`(\"'*])", s) if p.strip()])


def split_entries(text):
    """[(start_line, header_line, body_lines)] — headers inside fenced code are ignored."""
    lines = text.split("\n")
    fence = False
    entries = []
    for i, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = not fence
        if not fence and HEADER_RE.match(line):
            entries.append([i, line, []])
        elif entries:
            entries[-1][2].append(line)
    return lines, entries


def lint_entry(path, start, header, body, is_top, prev_nonblank):
    v = []

    def err(line, rule, msg):
        v.append(dict(file=path, line=line, level="error", rule=rule, msg=msg))

    def warn(line, rule, msg):
        v.append(dict(file=path, line=line, level="warn", rule=rule, msg=msg))

    m = HEADER_RE.match(header)
    if m.group(3).strip():
        err(start, "H1", f"heading carries extra text {m.group(3).strip()[:40]!r} — the date is the heading")
    if not is_top and prev_nonblank != "---":
        err(start, "H2", "entry is not preceded by a `---` divider")

    # the entry ends at the next divider-or-header; body already excludes later entries
    content = []
    for line in body:
        if line.strip() == "---":
            break
        content.append(line)
    chars = sum(len(l) for l in content if l.strip())
    if chars > ENTRY_MAX_CHARS:
        err(start, "B1", f"entry is {chars} chars (cap {ENTRY_MAX_CHARS}) — cut, move the rest to notes.md")

    labels = [(i, LABEL_RE.match(l.strip())) for i, l in enumerate(content) if LABEL_RE.match(l.strip())]
    names = [lm.group(1).strip() for _, lm in labels]
    expected = [n for n in names if n in SECTIONS]
    if expected != SECTIONS:
        missing = [s for s in SECTIONS if s not in names]
        extra = [n for n in names if n not in SECTIONS]
        if missing:
            err(start, "S1", f"missing section(s): {', '.join(missing)}")
        if extra:
            err(start, "S1", f"unexpected bold label(s): {', '.join(extra)} — only the five sections are labels")
        if not missing and not extra:
            err(start, "S1", "sections out of order")

    fence = False
    fence_len = fence_start = 0
    section = None
    first_next_seen = False
    for j, line in enumerate(content):
        ln = start + 1 + j
        s = line.strip()
        if s.startswith("```"):
            if fence and fence_len > 8:
                warn(fence_start, "T2", f"fenced block of {fence_len} lines — reference material belongs in a file")
            fence = not fence
            fence_len = 0
            fence_start = ln
            continue
        if fence:
            fence_len += 1
            continue
        if not s:
            continue
        lm = LABEL_RE.match(s)
        if lm:
            section = lm.group(1).strip()
            txt = lm.group(3) or ""
        else:
            txt = re.sub(r"^([-*]|\d+\.)\s+", "", s)
        if section == "Next up" and not lm and not first_next_seen and re.match(r"^1\.\s", s):
            first_next_seen = True
            if not NEXT_OK_RE.match(txt):
                warn(ln, "N1", "first Next-up item should be a command, a slash-command, or `ask — <question>`")
        if not txt.strip():
            continue
        plain = strip_code(txt)
        if len(plain) > LINE_MAX_CHARS:
            err(ln, "L1", f"{len(plain)} chars in one line (max {LINE_MAX_CHARS}) — a second fact is a second bullet")
        if ";" in plain:
            err(ln, "L3", "semicolon — split into bullets or cut")
        n = sentences(txt)
        if n > 1:
            warn(ln, "L2", f"{n} sentences in one line")
        if plain.count("—") > 1:
            warn(ln, "L4", f"{plain.count('—')} em-dashes in one line")
        if plain.count("(") > 1:
            warn(ln, "L5", f"{plain.count('(')} parentheticals in one line")
    return v


def lint_handoff(path, all_entries):
    text = open(path).read()
    lines, entries = split_entries(text)
    if not entries:
        return [dict(file=path, line=1, level="error", rule="H0", msg="no `## Handoff YYYY-MM-DD` entries found")]
    v = []
    stamps = [HEADER_RE.match(e[1]).group(1) + (HEADER_RE.match(e[1]).group(2) or "") for e in entries]
    if stamps != sorted(stamps, reverse=True):
        v.append(dict(file=path, line=entries[0][0], level="error", rule="H3", msg="entries are not newest on top"))
    for k, (start, header, body) in enumerate(entries):
        if k > 0 and not all_entries:
            break
        prev = next((lines[i].strip() for i in range(start - 2, -1, -1) if lines[i].strip()), "")
        v += lint_entry(path, start, header, body, k == 0, prev)
    return v


def lint_decisions(path):
    v = []
    lines = open(path).read().split("\n")
    if len([l for l in lines if l.strip()]) > DECISIONS_MAX_LINES:
        v.append(dict(file=path, line=1, level="warn", rule="D3", msg=f"decisions.md over {DECISIONS_MAX_LINES} lines — rationale belongs in notes.md"))
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if re.match(r"^#{2,}\s", s) or re.match(r"^\s{2,}[-*]\s", line) or "~~" in s:
            v.append(dict(file=path, line=i, level="warn", rule="D3", msg="heading / nested bullet / strikethrough — one flat line per decision, edit in place"))
        if not s.startswith(("- ", "* ")):
            continue
        if SELF_REF.search(s) and SELF_TOPICS.search(s):
            v.append(dict(file=path, line=i, level="warn", rule="D1", msg=f"reads as a note about the agent, not the project: {s[:60]!r}"))
        if len(strip_code(s)) > LINE_MAX_CHARS:
            v.append(dict(file=path, line=i, level="warn", rule="D2", msg=f"{len(s)} chars — one line per decision"))
    return v


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    if not os.path.exists(path):
        print(f"no such file: {path}")
        return 2
    dec = argv[argv.index("--decisions") + 1] if "--decisions" in argv else None
    v = lint_handoff(path, "--all" in argv)
    if dec and os.path.exists(dec):
        v += lint_decisions(dec)
    errs = [x for x in v if x["level"] == "error"]
    if "--json" in argv:
        print(json.dumps(dict(errors=len(errs), warnings=len(v) - len(errs), findings=v), indent=1))
    else:
        for x in sorted(v, key=lambda x: (x["file"], x["line"])):
            print(f"{x['file']}:{x['line']}: {x['level']} {x['rule']}: {x['msg']}")
        print(f"-- {len(errs)} errors, {len(v) - len(errs)} warnings")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
