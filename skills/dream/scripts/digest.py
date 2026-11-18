#!/usr/bin/env python3
"""Raw cross-PR facts for a window of merged PRs, for a dream pass to read.

Run from the repo root: digest.py [--kaizen <epic>] (last <N> | <A>..<B> | <N>...)
"""
import collections
import json
import re
import subprocess
import sys

TRIVIAL_CLOSE = re.compile(r"^(Shipped|Landed|Merged) (in|by|via) .{0,60}$", re.I)
DATED = re.compile(r"(\d{4}-\d{2}-\d{2})\b")
KINDS = (
    ("ans", r"\bOWNER\b|\(owner\b|owner answer|owner:"),
    ("ask", r"OPEN QUESTION|UNRESOLVED|SAVED_QUESTION|awaiting owner"),
    ("fix", r"CORRECTION|was false|supersede"),
    ("ref", r"refuted|premise"),
)
REVISION = re.compile(
    r"supersede|overrides|re-ask|no longer|moves out of|moved to|instead of|CORRECTION|was false|"
    r"refuted|will undo|impossible under", re.I)
IDENT = re.compile(r"\b[A-Z]{2,}[a-z]*\s?\d(?:[\w.+-]*\w)?|\b(?=\w*[A-Za-z])(?=\w*\d)\w+\b")
NOT_IDENT = re.compile(
    r"^(?:[0-9a-f]{7,}|[A-Za-z]\d{1,2}|\d+(?:\.\d+)?[A-Za-z]{1,3}|PRs?\s?\d+|\d+x|x\d+)$")
BACKTICK = re.compile(r"`([^`\n]{3,60})`")
PATH = re.compile(r"(?<![\w/:.])(?:[\w.-]+/)+[\w.-]+\.[A-Za-z]\w{0,5}\b")
RECORD_KEY = "dream_record"
CAPS = {"decisions": 80, "revisions": 60, "recurring": 15, "retired": 60}


def sh(*args, check=True):
    return subprocess.run(args, capture_output=True, text=True, check=check).stdout


def gh_json(*args):
    return json.loads(sh("gh", *args))


def window(spec):
    """The window's PR numbers from `last N`, `A..B` or a list of numbers."""
    if len(spec) == 2 and spec[0] == "last" and spec[1].isdigit():
        n = int(spec[1])
        merged = gh_json("pr", "list", "--state", "merged", "--limit", str(max(100, 5 * n)),
                         "--json", "number,mergedAt")
        return [p["number"] for p in sorted(merged, key=lambda p: p["mergedAt"])[-n:]]
    if len(spec) == 1 and (m := re.fullmatch(r"#?(\d+)\.\.#?(\d+)", spec[0])):
        lo, hi = int(m.group(1)), int(m.group(2))
        merged = gh_json("pr", "list", "--state", "merged", "--limit", "1000", "--json", "number")
        return [p["number"] for p in merged if lo <= p["number"] <= hi]
    if spec and all(re.fullmatch(r"#?\d+", a) for a in spec):
        return [int(a.lstrip("#")) for a in spec]
    raise SystemExit("usage: digest.py [--kaizen <epic>] (last <N> | <A>..<B> | <N>...)")


def load_prs(nums):
    prs = [gh_json("pr", "view", str(n), "--json",
                   "number,title,body,additions,deletions,files,mergedAt,mergeCommit") for n in nums]
    unmerged = [p["number"] for p in prs if not p.get("mergedAt")]
    if unmerged:
        raise SystemExit(f"not merged: {' '.join(f'#{n}' for n in unmerged)}")
    return sorted(prs, key=lambda p: p["mergedAt"])


def open_at(b, end):
    return b["created_at"] <= end and (not b.get("closed_at") or b["closed_at"] > end)


def parent_of(b):
    if b.get("parent"):
        return b["parent"]
    for d in b.get("dependencies") or []:
        if d.get("type") == "parent-child":
            return d["depends_on_id"]
    return "-"


def text(b):
    return " ".join(b.get(k) or "" for k in ("title", "description", "notes"))


def bead_id_pattern(beads):
    prefixes = {i.split(".")[0].rsplit("-", 1)[0] for i in beads if "-" in i}
    alt = "|".join(sorted(map(re.escape, prefixes), key=len, reverse=True)) or "(?!)"
    return re.compile(rf"\b(?:{alt})-[A-Za-z0-9]+(?:\.\d+)*\b")


def identifiers(s, bead_ids):
    s = bead_ids.sub(" ", s)
    found = {re.sub(r"\s+", " ", m) for m in IDENT.findall(s)}
    return {t for t in found if not NOT_IDENT.match(t)} | set(BACKTICK.findall(s))


def window_lines(b, day0, day1, rx=None):
    for line in (b.get("notes") or "").splitlines():
        m = DATED.match(line)
        if m and day0 <= m.group(1) <= day1 and (rx is None or rx.search(line)):
            yield line


def capped(out, rows, cap):
    out.extend(rows[:cap])
    if len(rows) > cap:
        out.append(f"... {len(rows) - cap} more")


def section(out, title):
    out.append(f"\n## {title}")


def digest(nums, kaizen=None):
    prs = load_prs(nums)
    start, end = prs[0]["mergedAt"], prs[-1]["mergedAt"]
    day0, day1 = start[:10], end[:10]
    beads = {b["id"]: b for b in json.loads(sh("bd", "list", "--all", "--json", "--limit", "0"))}
    out = [f"# Dream digest: {len(prs)} PRs #{prs[0]['number']}..#{prs[-1]['number']}, "
           f"window {start} .. {end}",
           "Bead open/closed is as of window end; priority is current."]

    section(out, "PRs (merge order): number, +/-, files, title")
    filecount = collections.Counter()
    for p in prs:
        paths = {f["path"] for f in p["files"]}
        filecount.update(paths)
        out.append(f"#{p['number']} +{p['additions']}/-{p['deletions']} {len(paths)}f {p['title'][:120]}")

    hot_min = max(3, round(len(prs) * 0.3))
    section(out, f"Hot files (touched by >= {hot_min} PRs)")
    out.extend(f"{c} {path}" for path, c in filecount.most_common() if c >= hot_min)

    created = [b for b in beads.values() if start <= b["created_at"] <= end]
    closed = [b for b in beads.values() if b.get("closed_at") and start <= b["closed_at"] <= end]
    open_end = [b for b in beads.values() if open_at(b, end)]
    section(out, f"Bead flow: created {len(created)}, closed {len(closed)}, open at window end {len(open_end)}")
    flow = collections.defaultdict(lambda: [0, 0])
    for b in created:
        flow[parent_of(b)][0] += 1
    for b in closed:
        flow[parent_of(b)][1] += 1
    out.append("per parent (created/closed), parents with >= 3 movements:")
    for k, (c, d) in sorted(flow.items(), key=lambda kv: -sum(kv[1])):
        if c + d >= 3:
            out.append(f"  {k} +{c}/-{d}  {beads.get(k, {}).get('title', '')[:70]}")

    section(out, "Beads created in window: id | parent | type | P | status-at-end | title")
    for b in sorted(created, key=lambda b: b["id"]):
        st = "open" if open_at(b, end) else "closed"
        out.append(f"{b['id']} | {parent_of(b)} | {b['issue_type']} | P{b['priority']} | {st} | {b['title'][:110]}")

    section(out, "Non-trivial close reasons in window")
    for b in closed:
        r = (b.get("close_reason") or "").strip()
        if r and not TRIVIAL_CLOSE.match(r):
            out.append(f"{b['id']}: {r[:220]}")

    section(out, "Mid-flight decisions per bead in window: owner answers / open questions / "
                 "corrections / refuted premises")
    tally = []
    for b in beads.values():
        lines = list(window_lines(b, day0, day1))
        c = {k: sum(1 for l in lines if re.search(rx, l, re.I)) for k, rx in KINDS}
        if sum(c.values()) >= 2:
            tally.append((sum(c.values()), b["id"], c, b["title"][:80]))
    for _, i, c, t in sorted(tally, reverse=True)[:20]:
        out.append(f"{i} ans{c['ans']} ask{c['ask']} fix{c['fix']} ref{c['ref']}  {t}")
    out.append("decision lines (first 160 chars):")
    owner = re.compile(r"\bOWNER\b", re.I)
    rows = [f"{b['id']}: {l[11:171]}" for b in beads.values() for l in window_lines(b, day0, day1, owner)]
    rows += [f"{b['id']} [close]: {b['close_reason'][:200]}" for b in closed
             if "owner" in (b.get("close_reason") or "").lower()]
    capped(out, rows, CAPS["decisions"])

    section(out, "Revisions: decision lines in window that supersede, re-ask, correct or move scope "
                 "(classify the cause)")
    capped(out, [f"{b['id']}: {l[11:251]}" for b in beads.values()
                 for l in window_lines(b, day0, day1, REVISION)], CAPS["revisions"])

    active = {b["id"] for b in created + closed}
    pool = [b for b in beads.values() if b["id"] in active or open_at(b, end)]
    bead_ids = bead_id_pattern(beads)
    for label, extract, mn in (
            ("Recurring identifiers", lambda s: identifiers(s, bead_ids), 3),
            ("Recurring code paths in bead text", lambda s: set(PATH.findall(s)), 4)):
        idx = collections.defaultdict(set)
        for b in pool:
            for tok in extract(text(b)):
                idx[tok].add(b["id"])
        rows = []
        for tok, ids in idx.items():
            parents = {parent_of(beads[i]) for i in ids}
            if len(ids) >= mn and len(parents) >= 2 and ids & active:
                rows.append((len(ids), tok, sorted(ids), len(parents)))
        section(out, f"{label}: in >= {mn} beads under >= 2 parents, >= 1 active in window")
        for n, tok, ids, np in sorted(rows, reverse=True)[:CAPS["recurring"]]:
            out.append(f"{tok} ({n} beads, {np} parents): {' '.join(ids[:10])}")

    section(out, "Priority inversions at window end: instance more urgent than its open caused-by mechanism")
    for b in open_end:
        for d in b.get("dependencies") or []:
            m = beads.get(d["depends_on_id"])
            if d.get("type") == "caused-by" and m and open_at(m, end) and m["priority"] > b["priority"]:
                out.append(f"{b['id']} P{b['priority']} -> mechanism {m['id']} P{m['priority']} {m['title'][:80]}")

    retired_vocabulary(out, prs, open_end, bead_ids)

    section(out, "PR follow-ups sections")
    for p in prs:
        m = re.search(r"^##\s*Follow-?ups?\s*$(.*?)(?=^##\s|\Z)", p.get("body") or "", re.S | re.M | re.I)
        if m:
            out.append(f"#{p['number']}: {re.sub(r'\s+', ' ', m.group(1)).strip()[:500]}")

    if kaizen:
        kaizen_section(out, beads, kaizen)
    return "\n".join(out)


def retired_vocabulary(out, prs, open_end, bead_ids):
    oids = [(p.get("mergeCommit") or {}).get("oid") for p in (prs[0], prs[-1])]
    title = "Retired vocabulary: backticked terms removed from *.md, absent from the tree at window end"
    if not all(oids):
        section(out, f"{title}: skipped, a PR has no merge commit")
        return
    s0, s1 = f"{oids[0]}~1", oids[1]
    diff = sh("git", "diff", s0, s1, "--", "*.md", check=False)
    removed = collections.Counter(BACKTICK.findall(
        "\n".join(l for l in diff.splitlines() if l.startswith("-") and not l.startswith("---"))))
    retired = [t for t, _ in removed.most_common(200)
               if not re.search(r"\s", t) and not bead_ids.fullmatch(t)
               and subprocess.run(["git", "grep", "-q", "-F", t, s1], capture_output=True).returncode == 1]
    section(out, f"{title} ({len(retired)})")
    out.append(" ".join(retired[:CAPS["retired"]]))
    out.append("open beads still citing a retired term:")
    for b in open_end:
        found = [t for t in retired if t in text(b)]
        if found:
            out.append(f"{b['id']} P{b['priority']} [{', '.join(found[:4])}] {b['title'][:90]}")


def kaizen_section(out, beads, epic):
    if epic not in beads:
        raise SystemExit(f"kaizen epic {epic} not found")
    section(out, f"Previous dream's record ({epic} metadata {RECORD_KEY})")
    out.append((beads[epic].get("metadata") or {}).get(RECORD_KEY) or "none: first run")
    section(out, "Open kaizen beads: id | P | dream checks so far | title")
    for b in sorted(beads.values(), key=lambda b: b["id"]):
        if parent_of(b) == epic and b["status"] != "closed":
            checks = sum("KAIZEN CHECK" in l for l in (b.get("notes") or "").splitlines())
            out.append(f"{b['id']} | P{b['priority']} | {checks} | {b['title'][:110]}")


def main(argv):
    kaizen = None
    if argv[:1] == ["--kaizen"]:
        if len(argv) < 2:
            raise SystemExit("--kaizen needs an epic id")
        kaizen, argv = argv[1], argv[2:]
    nums = window(argv)
    if not nums:
        raise SystemExit("no merged PRs in that window")
    print(digest(nums, kaizen))


if __name__ == "__main__":
    main(sys.argv[1:])
