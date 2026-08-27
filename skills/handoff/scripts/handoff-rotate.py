#!/usr/bin/env python3
"""handoff-rotate: apply the archive gate mechanically and idempotently.

usage: handoff-rotate.py <handoff.md> [--threshold 180] [--keep 2] [--force] [--dry-run] [--json]

If the handoff file exceeds --threshold lines and holds more than --keep entries, every entry after the first --keep
moves to the `-archive` sibling (`handoff-archive.md` / `NN-handoff-archive.md`), verbatim, newest on top — above whatever
the archive already holds. The preamble before the first entry stays in place. Running twice is a no-op.
exit 0 rotated or nothing to do · 2 refused (no entries parsed)
"""
import json
import os
import re
import sys

HEADER_RE = re.compile(r"^## Handoff (\d{4}-\d{2}-\d{2})")
ARCHIVE_PREAMBLE = "# Handoff archive\n\nCold storage. Entries verbatim, newest on top. Pickup never reads this file.\n\n---\n\n"


def split(text):
    """(preamble, [entry_text...], trailer). An entry runs from its header to just before the next header;
    trailing `---` dividers belong to the separator. A hand-written trailer after the last entry stays with the file."""
    lines = text.split("\n")
    fence = False
    idx = []
    for i, line in enumerate(lines):
        if line.startswith("```"):
            fence = not fence
        if not fence and HEADER_RE.match(line):
            idx.append(i)
    if not idx:
        return text, [], ""
    pre = "\n".join(lines[:idx[0]])
    ents, trailer = [], ""
    for k, s in enumerate(idx):
        e = idx[k + 1] if k + 1 < len(idx) else len(lines)
        chunk = lines[s:e]
        if k == len(idx) - 1:
            for t in range(len(chunk) - 1, 0, -1):
                if chunk[t].strip() == "---" and any(x.strip() for x in chunk[t + 1:]):
                    trailer = "\n".join(chunk[t + 1:]).strip()
                    chunk = chunk[:t]
                    break
        while chunk and chunk[-1].strip() in ("", "---"):
            chunk.pop()
        ents.append("\n".join(chunk))
    return pre, ents, trailer


def join(pre, ents, trailer=""):
    pre = pre.rstrip("\n")
    body = "\n\n---\n\n".join(ents)
    out = (pre + "\n\n" + body) if pre.strip() else body
    if trailer:
        out += "\n\n---\n\n" + trailer
    return out + "\n"


def archive_path(p):
    d, f = os.path.split(p)
    stem, ext = os.path.splitext(f)
    return os.path.join(d, f"{stem}-archive{ext}")


def rotate(path, threshold, keep, force, dry):
    text = open(path).read()
    nlines = text.count("\n") + (0 if text.endswith("\n") else 1)
    pre, ents, trailer = split(text)
    res = dict(file=path, lines=nlines, entries=len(ents), rotated=False, moved=0)
    if not ents:
        res["error"] = "no entries parsed"
        return res
    if len(ents) <= keep or (nlines <= threshold and not force):
        res["reason"] = f"{nlines} lines, {len(ents)} entries: under the gate"
        return res
    kept, moved = ents[:keep], ents[keep:]
    ap = archive_path(path)
    apre, aents, atrail = split(open(ap).read()) if os.path.exists(ap) else (ARCHIVE_PREAMBLE, [], "")
    new_handoff = join(pre, kept, trailer)
    new_archive = join(apre, moved + aents, atrail)
    assert all(m in new_archive for m in moved), "verbatim guarantee violated"
    res.update(rotated=True, moved=len(moved), archive=ap, handoff_lines=new_handoff.count("\n"),
               archive_lines=new_archive.count("\n"), archive_entries=len(moved) + len(aents),
               moved_dates=[HEADER_RE.match(m).group(1) for m in moved])
    if not dry:
        open(ap, "w").write(new_archive)
        open(path, "w").write(new_handoff)
    return res


def main(argv):
    if len(argv) < 2 or not os.path.exists(argv[1]):
        print(__doc__)
        return 2
    a = argv[1:]

    def opt(name, default):
        return type(default)(a[a.index(name) + 1]) if name in a else default

    res = rotate(a[0], opt("--threshold", 180), opt("--keep", 2), "--force" in a, "--dry-run" in a)
    if "--json" in a:
        print(json.dumps(res, indent=1))
    else:
        print(f"{'rotated' if res['rotated'] else 'no-op'}: " + ", ".join(f"{k}={v}" for k, v in res.items() if k not in ("file", "rotated")))
    return 2 if "error" in res else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
