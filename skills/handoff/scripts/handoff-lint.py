#!/usr/bin/env python3
"""handoff-lint: mechanical checks on a project's handoff docs.

usage: handoff-lint.py <project-dir | handoff.md> [--session S] [--snapshot] [--all] [--json]
exit 0 clean · 1 errors found · 2 usage / parse error

Files, resolved in the project dir (the 00- name first, the older name as a fallback):
  handoff    00-handoff.md | handoff.md | NN-handoff.md   top entry only (--all: every new-format entry)
  decisions  00-decisions.md | decisions.md
  state      00-state.md
  notes      00-notes.md

Ownership. A line-level doc finding is an error when this session wrote the line, a warning otherwise.
This session wrote a line when:
  - the line carries this session's id (--session, default: first 8 chars of $CLAUDE_CODE_SESSION_ID), or
  - a snapshot exists and the line is not in it. `--snapshot` (run at pickup) records every doc line, writes nothing else.
Without a session id or a snapshot, line-level doc findings can only warn. Caps and entry findings are always errors.

Entry (the top entry is always this session's):
  H1  heading is `## YYYY-MM-DD HH:MM` plus an optional 8-hex session id, nothing else
  H2  every entry after the first is preceded by a `---` divider
  H3  entries are newest on top (old `## Handoff DATE` entries sort by date)
  E1  the body is one ```diff block and nothing else
  E2  each line is `+|-|~ <noun>: <fact>`, `stopped: …` or `next: …`
  E3  exactly one `stopped:`, at most one `next:`, both after the change lines
  E4  no placeholder value (`none`, `n/a`, `tbd` …) and no optional next — omit the line instead
  E5  no reference to a `00-` doc — they change, so restate the fact
  B1  entry ≤ 1,200 characters
  L1  no line over 120 characters
  L3  no `;`
  L2  more than one sentence in a line                                       (warn)
  P1  first person                                                           (warn)

Docs:
  C1  more lines than the file's `<!-- max-lines: N -->` cap (defaults: decisions 40, state 80, notes 100)   (error)
  C2  the cap line changed since the snapshot — only the user may raise it                                (error)
  D1  decision reads as a note about the agent, not the project
  D2  decision text over 160 characters — the `[who]` tag and the date/session suffix are not counted
  D3  heading, nested bullet or strikethrough in decisions
  D4  decision is not `- [who] Decision. — YYYY-MM-DD[ HH:MM][ session8]`
  D5  session id in a decision suffix is not exactly 8 hex characters
  L1  doc line over 160 characters
  L2  more than one sentence in a bullet
  S1  a bullet under Known / Known, to verify has no source tag `[…]`
"""
import argparse
import glob
import hashlib
import json
import os
import re
import sys
import tempfile

ENTRY_MAX_CHARS = 1200
ENTRY_LINE_MAX = 120
DOC_LINE_MAX = 160
DEFAULT_CAPS = {"decisions": 40, "state": 80, "notes": 100}
WARN_COLLAPSE = 3

ANY_HEADER_RE = re.compile(r"^## (Handoff )?\d{4}-\d{2}-\d{2}")
HEADER_RE = re.compile(r"^## (\d{4}-\d{2}-\d{2}) (\d{2}:\d{2})( [0-9a-f]{8})?(.*)$")
OLD_HEADER_RE = re.compile(r"^## Handoff (\d{4}-\d{2}-\d{2})( \d{2}:\d{2})?")
CAP_RE = re.compile(r"^<!--\s*max-lines:\s*(\d+)\s*-->")
CHANGE_RE = re.compile(r"^([+~-]) ([a-z][a-z0-9 -]{0,23}): (\S.*)$")
STOP_RE = re.compile(r"^stopped: (\S.*)$")
NEXT_RE = re.compile(r"^next: (\S.*)$")
PLACEHOLDER_RE = re.compile(r"^(none|none new|n/?a|tbd|todo|nothing|nil|-|—|\.\.\.|…)[.!]?$", re.I)
ZERO_REF_RE = re.compile(r"(?<![\w-])00-[a-z][a-z0-9-]*")
FIRST_PERSON_RE = re.compile(r"\b(I|I'm|I've|[Ww]e|[Ww]e're|[Ww]e've|[Mm]y|[Oo]ur)\b")
DEC_SUFFIX_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})( \d{2}:\d{2})?( (\S+))?$")
DEC_TAG_RE = re.compile(r"^[-*] \[([^\]]+)\] (.*)$")
SOURCE_TAG_RE = re.compile(r"\[[^\]]+\]")
CODE_RE = re.compile(r"`[^`]*`")
SELF_REF = re.compile(r"\b(I|I'm|me|my|myself|you|your|this session|the model|the agent)\b", re.I)
SELF_TOPICS = re.compile(r"\b(fetch|cite|spawn|subagent|concise|verbose|doc style|communication|workflow|tooling|lesson|always|never)\b", re.I)


def strip_code(s):
    return CODE_RE.sub("`x`", s)


def sentences(s):
    s = strip_code(s).strip()
    return len([p for p in re.split(r"(?<=[.!?])\s+(?=[A-Z`(\"'*])", s) if p.strip()])


def finding(path, line, level, rule, msg):
    return dict(file=path, line=line, level=level, rule=rule, msg=msg)


# ---------- files ----------

def resolve(arg):
    if os.path.isfile(arg):
        d, handoff = os.path.dirname(os.path.abspath(arg)), arg
    else:
        d, handoff = arg, None

    def first(*patterns):
        for p in patterns:
            hits = sorted(glob.glob(os.path.join(d, p)))
            if hits:
                return hits[0]
        return None

    return d, dict(handoff=handoff or first("00-handoff.md", "handoff.md", "[0-9][0-9]-handoff.md"),
                   decisions=first("00-decisions.md", "decisions.md"),
                   state=first("00-state.md"), notes=first("00-notes.md"))


def line_key(s):
    return hashlib.sha1(s.strip().encode()).hexdigest()[:16]


def snapshot_path(d, session):
    tag = hashlib.sha1(os.path.realpath(d).encode()).hexdigest()[:8]
    return os.path.join(tempfile.gettempdir(), "handoff-lint", f"{session}-{tag}.json")


def write_snapshot(d, files, session):
    snap = {}
    for kind in ("decisions", "state", "notes"):
        if files[kind]:
            snap[kind] = sorted({line_key(l) for l in open(files[kind]).read().split("\n") if l.strip()})
    p = snapshot_path(d, session)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as fh:
        json.dump(snap, fh)
    return p


class Owner:
    """Decides whether this session wrote a doc line — the line between an error and a warning."""

    def __init__(self, d, session):
        self.session = session
        self.snap = None
        if session and os.path.exists(snapshot_path(d, session)):
            self.snap = {k: set(v) for k, v in json.load(open(snapshot_path(d, session))).items()}

    def mine(self, kind, line):
        if self.session and self.session in line:
            return True
        if self.snap is not None:
            return kind not in self.snap or line_key(line) not in self.snap[kind]
        return False


# ---------- handoff entries ----------

def split_entries(text):
    """[(start_line, header_line, body_lines)] — headers inside fenced code are ignored."""
    lines = text.split("\n")
    fence = False
    entries = []
    for i, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = not fence
        if not fence and ANY_HEADER_RE.match(line):
            entries.append([i, line, []])
        elif entries:
            entries[-1][2].append(line)
    return lines, entries


def stamp(header):
    m = HEADER_RE.match(header)
    if m:
        return f"{m.group(1)} {m.group(2)}"
    m = OLD_HEADER_RE.match(header)
    return m.group(1) + (m.group(2) or "") if m else ""


def lint_entry(path, start, header, body, is_top, prev_nonblank):
    v = []

    def err(line, rule, msg):
        v.append(finding(path, line, "error", rule, msg))

    def warn(line, rule, msg):
        v.append(finding(path, line, "warn", rule, msg))

    m = HEADER_RE.match(header)
    if not m or m.group(4).strip():
        err(start, "H1", f"heading must be `## YYYY-MM-DD HH:MM` plus an optional 8-hex session id: {header!r}")
    if not is_top and prev_nonblank != "---":
        err(start, "H2", "entry is not preceded by a `---` divider")

    content, fence = [], False
    for line in body:
        if line.startswith("```"):
            fence = not fence
        if not fence and line.strip() == "---":
            break
        content.append(line)
    chars = sum(len(l) for l in content if l.strip())
    if chars > ENTRY_MAX_CHARS:
        err(start, "B1", f"entry is {chars} chars (cap {ENTRY_MAX_CHARS}) — detail belongs in a numbered doc")

    # Collect the lines inside the one ```diff block; anything outside it is E1.
    rows, phase, has_fence = [], "before", False
    for j, line in enumerate(content):
        ln, s = start + 1 + j, line.strip()
        if phase == "before" and s == "```diff":
            phase, has_fence = "inside", True
        elif phase == "inside" and s == "```":
            phase = "after"
        elif phase == "inside":
            if s:
                rows.append((ln, line.rstrip()))
        elif s:
            err(ln, "E1", f"text outside the ```diff block: {s[:50]!r}")
    if not has_fence:
        err(start, "E1", "the body must be one ```diff block")
        rows = [(start + 1 + j, l.rstrip()) for j, l in enumerate(content) if l.strip() and not l.startswith("```")]
    elif phase == "inside":
        err(start, "E1", "the ```diff block is never closed")

    stops = nexts = 0
    after = None  # None while change lines are allowed, then "stopped", then "next"
    for ln, line in rows:
        cm, sm, nm = CHANGE_RE.match(line), STOP_RE.match(line), NEXT_RE.match(line)
        if cm:
            value = cm.group(3)
            if after:
                err(ln, "E3", f"change line after `{after}:` — changes come first")
        elif sm:
            value, stops = sm.group(1), stops + 1
            if after == "next":
                err(ln, "E3", "`stopped:` after `next:`")
            after = "stopped"
        elif nm:
            value, nexts = nm.group(1), nexts + 1
            if after != "stopped":
                err(ln, "E3", "`next:` must follow `stopped:`")
            after = "next"
            if re.search(r"\boptional\b", value, re.I):
                err(ln, "E4", "next names optional work — leave `next:` out")
        else:
            err(ln, "E2", f"not `+|-|~ <noun>: <fact>`, `stopped:` or `next:`: {line[:50]!r}")
            continue
        if PLACEHOLDER_RE.match(value.strip()):
            err(ln, "E4", f"placeholder {value.strip()!r} — omit the line instead")
        if ZERO_REF_RE.search(line):
            err(ln, "E5", "points at a 00- doc, which changes — restate the fact in a few words")
        if len(line) > ENTRY_LINE_MAX:
            err(ln, "L1", f"{len(line)} chars (max {ENTRY_LINE_MAX}) — a few words, detail goes in a numbered doc")
        if ";" in line:
            err(ln, "L3", "semicolon — split into two lines or cut")
        if sentences(value) > 1:
            warn(ln, "L2", f"{sentences(value)} sentences in one line")
        if FIRST_PERSON_RE.search(strip_code(value)):
            warn(ln, "P1", "first person — state the fact")
    if stops != 1:
        err(start, "E3", f"{stops} `stopped:` lines — exactly one")
    if nexts > 1:
        err(start, "E3", f"{nexts} `next:` lines — at most one, the rest belongs in a plan doc")
    return v


def lint_handoff(path, all_entries):
    text = open(path).read()
    lines, entries = split_entries(text)
    if not entries:
        return [finding(path, 1, "error", "H0", "no `## YYYY-MM-DD HH:MM` entries found")]
    v = []
    stamps = [stamp(e[1]) for e in entries]
    for i in range(1, len(stamps)):
        if stamps[i] > stamps[i - 1]:
            v.append(finding(path, entries[i][0], "error", "H3",
                             f"'{stamps[i]}' at line {entries[i][0]} sorts above '{stamps[i - 1]}' at line {entries[i - 1][0]} — newest on top"))
            break
    for k, (start, header, body) in enumerate(entries):
        if k > 0 and not all_entries:
            break
        if k > 0 and OLD_HEADER_RE.match(header):
            continue  # old-format history is left as written
        prev = next((lines[i].strip() for i in range(start - 2, -1, -1) if lines[i].strip()), "")
        v += lint_entry(path, start, header, body, k == 0, prev)
    return v


# ---------- docs ----------

def lint_doc(path, kind, owner):
    v = []
    lines = open(path).read().split("\n")
    cap = DEFAULT_CAPS[kind]
    body_start = 0
    for i, line in enumerate(lines):
        cm = CAP_RE.match(line.strip())
        if cm:
            cap = int(cm.group(1))
            if owner.snap is not None and kind in owner.snap and line_key(line) not in owner.snap[kind]:
                v.append(finding(path, i + 1, "error", "C2",
                                 f"cap changed to {cap} this session — revert unless the user explicitly approved it"))
        if line.strip() and not line.startswith(">") and not cm:
            body_start = i
            break
    else:
        body_start = len(lines)
    counted = [l for l in lines[body_start:] if l.strip() and not l.lstrip().startswith("#")]
    if len(counted) > cap:
        v.append(finding(path, 1, "error", "C1",
                         f"{len(counted)} lines, cap {cap} — trim, or ask the user to raise the cap on line 1"))

    section = None
    for i in range(body_start, len(lines)):
        line, ln = lines[i], i + 1
        s = line.strip()
        if not s:
            continue
        lvl = "error" if owner.mine(kind, line) else "warn"
        if s.startswith("#"):
            section = s.lstrip("#").strip().lower()
            if kind == "decisions" and re.match(r"^#{2,}\s", s):
                v.append(finding(path, ln, lvl, "D3", "heading — one flat line per decision"))
            continue
        bullet = s.startswith(("- ", "* "))
        if kind == "decisions":
            if re.match(r"^\s{2,}[-*]\s", line) or "~~" in s:
                v.append(finding(path, ln, lvl, "D3", "nested bullet or strikethrough — edit in place or delete"))
            if not bullet:
                continue
            tm = DEC_TAG_RE.match(s)
            head, sep, suffix = (tm.group(2) if tm else s[2:]).rpartition(" — ")
            sm = DEC_SUFFIX_RE.match(suffix) if sep else None
            text = head if sm else (tm.group(2) if tm else s[2:])
            if not tm or not sm:
                v.append(finding(path, ln, lvl, "D4", "not `- [who] Decision. — YYYY-MM-DD[ HH:MM][ session8]`"))
            elif sm.group(4) and not re.fullmatch(r"[0-9a-f]{8}", sm.group(4)):
                v.append(finding(path, ln, lvl, "D5", f"session id {sm.group(4)[:20]!r} — first 8 hex characters only"))
            if SELF_REF.search(text) and SELF_TOPICS.search(text):
                v.append(finding(path, ln, lvl, "D1", f"reads as a note about the agent, not the project: {text[:50]!r}"))
            if len(strip_code(text)) > DOC_LINE_MAX:
                v.append(finding(path, ln, lvl, "D2", f"{len(strip_code(text))} chars of decision text (max {DOC_LINE_MAX})"))
            if sentences(text) > 1:
                v.append(finding(path, ln, lvl, "L2", f"{sentences(text)} sentences — one decision, rationale in a numbered doc"))
            continue
        if len(strip_code(s)) > DOC_LINE_MAX:
            v.append(finding(path, ln, lvl, "L1", f"{len(strip_code(s))} chars (max {DOC_LINE_MAX}) — one fact per line"))
        if bullet and sentences(s[2:]) > 1:
            v.append(finding(path, ln, lvl, "L2", f"{sentences(s[2:])} sentences in one bullet"))
        if kind == "state" and bullet and section in ("known", "known, to verify") and not SOURCE_TAG_RE.search(s):
            v.append(finding(path, ln, lvl, "S1", "fact has no source tag — `[verified <ref>]`, `[POC]` or `[per user, unverified]`"))
    return v


def collapse(v):
    """Pre-existing warnings repeat per line on older files; past a few per rule, report a count."""
    out, groups = [], {}
    for x in v:
        if x["level"] == "warn":
            groups.setdefault((x["file"], x["rule"]), []).append(x)
        else:
            out.append(x)
    for (f, rule), xs in groups.items():
        if len(xs) <= WARN_COLLAPSE:
            out += xs
        else:
            lines = ", ".join(str(x["line"]) for x in xs[:8]) + (" …" if len(xs) > 8 else "")
            out.append(finding(f, xs[0]["line"], "warn", rule, f"{len(xs)} pre-existing lines (lines {lines}) — {xs[0]['msg']}"))
    return out


def main(argv):
    ap = argparse.ArgumentParser(prog="handoff-lint", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("target", help="project dir, or a handoff file inside it")
    ap.add_argument("--session", default=os.environ.get("CLAUDE_CODE_SESSION_ID", "")[:8],
                    help="this session's 8-char id (default: from $CLAUDE_CODE_SESSION_ID)")
    ap.add_argument("--snapshot", action="store_true", help="record the docs' current lines for this session, then exit")
    ap.add_argument("--all", action="store_true", help="lint every new-format entry, not only the top one")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv[1:])
    if not os.path.exists(a.target):
        print(f"no such file or dir: {a.target}")
        return 2
    session = a.session if re.fullmatch(r"[0-9a-f]{8}", a.session or "") else ""
    d, files = resolve(a.target)

    if a.snapshot:
        if not session:
            print("no session id — snapshot skipped, line findings in state/notes will only warn")
            return 0
        print(f"snapshot: {write_snapshot(d, files, session)}")
        return 0

    if not files["handoff"]:
        print(f"no handoff file in {d}")
        return 2
    owner = Owner(d, session)
    v = lint_handoff(files["handoff"], a.all)
    for kind in ("decisions", "state", "notes"):
        if files[kind]:
            v += lint_doc(files[kind], kind, owner)
    v = collapse(v)
    errs = [x for x in v if x["level"] == "error"]
    basis = "snapshot" if owner.snap is not None else ("session id" if session else "none — doc lines only warn")
    if a.json:
        print(json.dumps(dict(errors=len(errs), warnings=len(v) - len(errs), ownership=basis, findings=v), indent=1))
    else:
        for x in sorted(v, key=lambda x: (x["file"], x["line"])):
            print(f"{x['file']}:{x['line']}: {x['level']} {x['rule']}: {x['msg']}")
        print(f"-- {len(errs)} error(s): yours, fix and re-run. {len(v) - len(errs)} warning(s): pre-existing, "
              f"fix any on a line you edit. Ownership basis: {basis}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
