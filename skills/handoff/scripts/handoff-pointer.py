#!/usr/bin/env python3
"""handoff-pointer: the only writer of the HANDOFF.md pointer file.

usage:
  handoff-pointer.py <HANDOFF.md> upsert --slug S --branch B --head H --dirty N --state STATE --next "…" --handoff PATH [--updated YYYY-MM-DD] [--dry-run]
  handoff-pointer.py <HANDOFF.md> show   [--slug S | --branch B]      # selected entry as JSON (all entries if neither)
  handoff-pointer.py <HANDOFF.md> check  [--dead]                     # report problems; --dead also tests heads against origin/main
  handoff-pointer.py <HANDOFF.md> remove --slug S
  handoff-pointer.py <HANDOFF.md> prune  [--older-than DAYS] [--dry-run]   # drop done/superseded entries older than DAYS (default 14)
  handoff-pointer.py <HANDOFF.md> migrate [--write]                   # convert a format-1 pointer (## N + status:) to format 2

Format 2:
  <!-- handoff-format: 2 -->
  # Active handoffs

  ## <slug>
  - branch: <git rev-parse --abbrev-ref HEAD>
  - head: <git rev-parse --short HEAD>
  - dirty: <count of `git status --short` lines>
  - state: in-progress | blocked | review | done | parked | superseded
  - next: <one action, ≤80 chars, no ';'>
  - handoff: <path to handoff.md or NN-handoff.md, relative to the repo root>
  - updated: YYYY-MM-DD

Guarantees: upsert replaces the entry with the same slug (or the same handoff path) and moves it to the top; every other entry
is preserved byte-for-byte; a value that fails validation is refused (exit 2) before anything is written.
exit 0 ok · 1 check found problems · 2 refused / usage
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

FORMAT = 2
STAMP = f"<!-- handoff-format: {FORMAT} -->"
FIELDS = ["branch", "head", "dirty", "state", "next", "handoff", "updated"]
STATES = ["in-progress", "blocked", "review", "done", "parked", "superseded"]
NEXT_MAX = 80
HEAD_RE = re.compile(r"^[0-9a-f]{7,40}$")
BRANCH_RE = re.compile(r"^[^\s()]+$")
HANDOFF_NAME_RE = re.compile(r"^(\d\d-)?handoff\.md$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def die(msg, code=2):
    print(f"handoff-pointer: {msg}", file=sys.stderr)
    sys.exit(code)


def write_atomic(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)


def repo_root(pointer_path):
    """The pointer lives at <root>/.context/HANDOFF.md or <root>/HANDOFF.md; handoff: paths are relative to <root>."""
    d = os.path.dirname(os.path.abspath(pointer_path))
    return os.path.dirname(d) if os.path.basename(d) == ".context" else d


# ---------- parsing ----------

def parse(text):
    """Return (stamp_present, title, entries). entries = [(slug, fields_dict, raw_lines)] in file order."""
    lines = text.split("\n")
    stamp = bool(lines) and lines[0].strip() == STAMP
    title = ""
    entries = []
    cur = None
    for line in lines[1 if stamp else 0:]:
        if line.startswith("## "):
            if cur:
                entries.append(cur)
            cur = [line[3:].strip(), {}, []]
            continue
        if cur is None:
            if line.startswith("# ") and not title:
                title = line
            continue
        cur[2].append(line)
        m = re.match(r"^- ([a-z]+): (.*)$", line)
        if m and m.group(1) not in cur[1]:
            cur[1][m.group(1)] = m.group(2).strip()
    if cur:
        entries.append(cur)
    for e in entries:
        while e[2] and not e[2][-1].strip():
            e[2].pop()
    return stamp, title, entries


def render(entries):
    out = [STAMP, "# Active handoffs", ""]
    for slug, _, raw in entries:
        out += [f"## {slug}"] + raw + [""]
    return "\n".join(out).rstrip("\n") + "\n"


def entry_lines(vals):
    return [f"- {f}: {vals[f]}" for f in FIELDS]


# ---------- validation ----------

def validate(vals, root):
    problems = []
    if not SLUG_RE.match(vals.get("slug", "")):
        problems.append(f"slug must be lowercase kebab-case: {vals.get('slug')!r}")
    if not BRANCH_RE.match(vals.get("branch", "")):
        problems.append(f"branch must be a bare branch name, nothing appended: {vals.get('branch')!r}")
    if not HEAD_RE.match(vals.get("head", "")):
        problems.append(f"head must be a bare short sha: {vals.get('head')!r}")
    if not re.match(r"^\d+$", str(vals.get("dirty", ""))):
        problems.append(f"dirty must be a bare count: {vals.get('dirty')!r}")
    if vals.get("state") not in STATES:
        problems.append(f"state must be one of {STATES}: {vals.get('state')!r}")
    nxt = vals.get("next", "")
    if not nxt or len(nxt) > NEXT_MAX or ";" in nxt or "\n" in nxt:
        problems.append(f"next must be one action, 1–{NEXT_MAX} chars, no ';': {nxt!r} ({len(nxt)} chars)")
    if re.search(r"\boptional\b", nxt, re.I):
        problems.append("next names optional work — if the only remaining work is optional, the state is done")
    hp = vals.get("handoff", "")
    if not HANDOFF_NAME_RE.match(os.path.basename(hp)):
        problems.append(f"handoff must end in handoff.md or NN-handoff.md: {hp!r}")
    else:
        full = os.path.realpath(os.path.join(root, hp))
        if not full.startswith(os.path.realpath(root) + os.sep):
            problems.append(f"handoff path escapes the repo root: {hp}")
        elif not os.path.exists(full):
            problems.append(f"handoff file does not exist: {hp}")
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", vals.get("updated", "")):
        problems.append(f"updated must be YYYY-MM-DD: {vals.get('updated')!r}")
    return problems


def merged_into_main(root, head):
    """True if head is an ancestor of origin/main (best-effort; None when unknowable)."""
    try:
        subprocess.run(["git", "-C", root, "fetch", "-q"], capture_output=True, timeout=20)
        r = subprocess.run(["git", "-C", root, "merge-base", "--is-ancestor", head, "origin/main"], capture_output=True)
        if r.returncode in (0, 1):
            return r.returncode == 0
    except Exception:
        pass
    return None


# ---------- commands ----------

def cmd_upsert(path, opts, dry):
    today = datetime.date.today().isoformat()
    vals = {f: opts.get(f) for f in FIELDS}
    vals["slug"] = opts.get("slug")
    vals["updated"] = vals["updated"] or today
    missing = [f for f in ["slug"] + FIELDS if not vals.get(f)]
    if missing:
        die(f"missing: {', '.join('--' + m for m in missing)}")
    root = repo_root(path)
    problems = validate(vals, root)
    if problems:
        die("refusing to write:\n  " + "\n  ".join(problems))
    text = open(path).read() if os.path.exists(path) else ""
    stamp, _, entries = parse(text)
    if entries and not stamp:
        die(f"pointer is format 1 — run `migrate` first so the file does not end up mixed-format")
    others = [e for e in entries if e[0] != vals["slug"] and e[1].get("handoff") != vals["handoff"]]
    new = render([(vals["slug"], vals, entry_lines(vals))] + others)
    if dry:
        print(new, end="")
    else:
        write_atomic(path, new)
    print(f"upserted {vals['slug']} at the top; {len(others)} other entries preserved; {len(entries) - len(others)} replaced")


def cmd_show(path, opts):
    stamp, _, entries = parse(open(path).read())
    if not stamp:
        die(f"pointer is not format {FORMAT} — run `migrate` first", 1)
    sel = entries
    if opts.get("slug"):
        sel = [e for e in entries if e[0] == opts["slug"]]
    elif opts.get("branch"):
        sel = [e for e in entries if e[1].get("branch") == opts["branch"]]
    print(json.dumps([dict(slug=s, **f) for s, f, _ in sel], indent=1))
    sys.exit(0 if sel else 1)


def cmd_check(path, dead):
    text = open(path).read()
    stamp, _, entries = parse(text)
    root = repo_root(path)
    problems = []
    if not stamp:
        problems.append(f"missing `{STAMP}` on line 1 (format 1 file? run `migrate`)")
    seen = set()
    for slug, f, _ in entries:
        if slug in seen:
            problems.append(f"{slug}: duplicate entry")
        seen.add(slug)
        vals = dict(f, slug=slug)
        for k in FIELDS:
            vals.setdefault(k, "")
        problems += [f"{slug}: {p}" for p in validate(vals, root)]
        if f.get("updated"):
            try:
                age = (datetime.date.today() - datetime.date.fromisoformat(f["updated"])).days
                if age > 30:
                    problems.append(f"{slug}: stale — updated {age} days ago")
            except ValueError:
                pass
        if dead and f.get("head") and f.get("state") not in ("done", "superseded"):
            m = merged_into_main(root, f["head"])
            if m:
                problems.append(f"{slug}: dead — head {f['head']} is already in origin/main (state says {f.get('state')})")
    branches = [f.get("branch") for _, f, _ in entries]
    for b in set(b for b in branches if branches.count(b) > 1):
        problems.append(f"branch {b} appears in more than one entry — pickup cannot tell them apart")
    print(json.dumps(dict(format=FORMAT if stamp else 1, entries=len(entries), problems=problems), indent=1))
    sys.exit(1 if problems else 0)


def cmd_remove(path, slug):
    _, _, entries = parse(open(path).read())
    keep = [e for e in entries if e[0] != slug]
    if len(keep) == len(entries):
        die(f"no entry with slug {slug!r}", 1)
    write_atomic(path, render(keep))
    print(f"removed {slug}; {len(keep)} entries remain")


def cmd_prune(path, days, dry):
    _, _, entries = parse(open(path).read())
    today = datetime.date.today()
    keep, drop = [], []
    for e in entries:
        f = e[1]
        try:
            age = (today - datetime.date.fromisoformat(f.get("updated", ""))).days
        except ValueError:
            age = 0
        (drop if f.get("state") in ("done", "superseded") and age >= days else keep).append(e)
    for e in drop:
        print(f"prune {e[0]} ({e[1].get('state')}, updated {e[1].get('updated')})")
    if not drop:
        print("nothing to prune")
    elif not dry:
        write_atomic(path, render(keep))


def cmd_migrate(path, write):
    """Format 1 → 2. Old entries are `## N` with project/branch/head/dirty/status/handoff/updated, or the single-entry
    `# Active handoff` shape. state is derived from the old status; next becomes a TODO — a status is not a next step."""
    text = open(path).read()
    stamp, _, entries = parse(text)
    if stamp:
        print("already format 2")
        return
    root = repo_root(path)
    out, notes = [], []
    for heading, f, _ in entries or [("1", parse("## 1\n" + text)[2][0][1] if "- branch:" in text else {}, [])]:
        if not f:
            continue
        slug = re.sub(r"^\d\d-", "", f.get("project", heading)).strip()
        status = f.get("status", "")
        up = status.upper()
        state = ("superseded" if "SUPERSEDED" in up else "done" if re.search(r"\b(MERGED|COMPLETE|DONE|SHIPPED)\b", up)
                 else "blocked" if re.search(r"\b(BLOCKED|ON HOLD|PARKED)\b", up)
                 else "review" if re.search(r"\b(REVIEW|PR OPEN|AWAITING)\b", up) else "in-progress")
        nxt = "TODO: set with handoff-pointer upsert (old status in the .format1.bak)"
        branch = re.sub(r"\s.*$", "", f.get("branch", ""))
        head = re.match(r"[0-9a-f]+", f.get("head", "")) and re.match(r"[0-9a-f]+", f.get("head", "")).group(0) or ""
        dval = f.get("dirty", "")
        dm = re.search(r"\d+", dval)
        dirty = "0" if dval.startswith("no") or not dval else (dm.group(0) if dm else "1")
        vals = dict(slug=slug, branch=branch, head=head, dirty=dirty, state=state, next=nxt,
                    handoff=f.get("handoff", ""), updated=f.get("updated", ""))
        for p in validate(vals, root):
            notes.append(f"{slug}: {p}")
        if status and len(status) > NEXT_MAX:
            notes.append(f"{slug}: old status was {len(status)} chars — its content stays only in the handoff entry")
        out.append((slug, vals, entry_lines(vals)))
    new = render(out)
    print(new)
    for n in notes:
        print("note:", n, file=sys.stderr)
    if write:
        bak = path + ".format1.bak"
        write_atomic(bak, text)
        write_atomic(path, new)
        print(f"written; format-1 copy at {bak}", file=sys.stderr)
    else:
        print("dry run — pass --write to apply", file=sys.stderr)


def main(argv):
    ap = argparse.ArgumentParser(prog="handoff-pointer", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pointer", help="path to HANDOFF.md")
    sub = ap.add_subparsers(dest="cmd", required=True)
    up = sub.add_parser("upsert")
    for f in ["slug"] + FIELDS:
        up.add_argument("--" + f, required=(f != "updated"))
    up.add_argument("--dry-run", action="store_true")
    sh = sub.add_parser("show")
    sh.add_argument("--slug")
    sh.add_argument("--branch")
    ck = sub.add_parser("check")
    ck.add_argument("--dead", action="store_true")
    rm = sub.add_parser("remove")
    rm.add_argument("--slug", required=True)
    pr = sub.add_parser("prune")
    pr.add_argument("--older-than", type=int, default=14, metavar="DAYS")
    pr.add_argument("--dry-run", action="store_true")
    mg = sub.add_parser("migrate")
    mg.add_argument("--write", action="store_true")
    a = ap.parse_args(argv[1:])
    path = a.pointer
    if a.cmd != "upsert" and not os.path.exists(path):
        die(f"no such file: {path}")
    if a.cmd == "upsert":
        cmd_upsert(path, {k: v for k, v in vars(a).items() if k in ["slug"] + FIELDS}, a.dry_run)
    elif a.cmd == "show":
        cmd_show(path, dict(slug=a.slug, branch=a.branch))
    elif a.cmd == "check":
        cmd_check(path, a.dead)
    elif a.cmd == "remove":
        cmd_remove(path, a.slug)
    elif a.cmd == "prune":
        cmd_prune(path, a.older_than, a.dry_run)
    elif a.cmd == "migrate":
        cmd_migrate(path, a.write)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
