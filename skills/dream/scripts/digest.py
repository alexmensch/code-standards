#!/usr/bin/env python3
"""Raw cross-PR facts for a window of merged PRs, for a dream pass to read.

Run from the repo root: digest.py [--kaizen <epic>] (last <N> | <A>..<B> | <N>...)
"""
import collections
import json
import re
import subprocess
import sys
from dataclasses import dataclass

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
FOLLOWUPS = re.compile(r"^##\s*Follow-?ups?\s*$(.*?)(?=^##\s|\Z)", re.S | re.M | re.I)
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


def capped(rows, cap):
    return rows[:cap] + ([f"... {len(rows) - cap} more"] if len(rows) > cap else [])


@dataclass
class Window:
    prs: list
    beads: dict
    start: str
    end: str

    def __post_init__(self):
        self.created = [b for b in self.beads.values() if self.start <= b["created_at"] <= self.end]
        self.closed = [b for b in self.beads.values()
                       if b.get("closed_at") and self.start <= b["closed_at"] <= self.end]
        self.open_end = [b for b in self.beads.values() if open_at(b, self.end)]
        self.active = {b["id"] for b in self.created + self.closed}
        self.bead_ids = bead_id_pattern(self.beads)

    def lines(self, b, rx=None):
        """Note lines dated inside the window, matching rx when given."""
        for line in (b.get("notes") or "").splitlines():
            m = DATED.match(line)
            if m and self.start[:10] <= m.group(1) <= self.end[:10] and (rx is None or rx.search(line)):
                yield line


def prs_section(w):
    return "PRs (merge order): number, +/-, files, title", [
        f"#{p['number']} +{p['additions']}/-{p['deletions']} {len({f['path'] for f in p['files']})}f "
        f"{p['title'][:120]}" for p in w.prs]


def hot_files_section(w):
    filecount = collections.Counter(path for p in w.prs for path in {f["path"] for f in p["files"]})
    hot_min = max(3, round(len(w.prs) * 0.3))
    return f"Hot files (touched by >= {hot_min} PRs)", [
        f"{c} {path}" for path, c in filecount.most_common() if c >= hot_min]


def flow_section(w):
    flow = collections.defaultdict(lambda: [0, 0])
    for b in w.created:
        flow[parent_of(b)][0] += 1
    for b in w.closed:
        flow[parent_of(b)][1] += 1
    rows = ["per parent (created/closed), parents with >= 3 movements:"]
    for k, (c, d) in sorted(flow.items(), key=lambda kv: -sum(kv[1])):
        if c + d >= 3:
            rows.append(f"  {k} +{c}/-{d}  {w.beads.get(k, {}).get('title', '')[:70]}")
    return (f"Bead flow: created {len(w.created)}, closed {len(w.closed)}, "
            f"open at window end {len(w.open_end)}"), rows


def created_section(w):
    return "Beads created in window: id | parent | type | P | status-at-end | title", [
        f"{b['id']} | {parent_of(b)} | {b['issue_type']} | P{b['priority']} | "
        f"{'open' if open_at(b, w.end) else 'closed'} | {b['title'][:110]}"
        for b in sorted(w.created, key=lambda b: b["id"])]


def close_reasons_section(w):
    return "Non-trivial close reasons in window", [
        f"{b['id']}: {r[:220]}" for b in w.closed
        if (r := (b.get("close_reason") or "").strip()) and not TRIVIAL_CLOSE.match(r)]


def decisions_section(w):
    tally = []
    for b in w.beads.values():
        lines = list(w.lines(b))
        c = {k: sum(1 for l in lines if re.search(rx, l, re.I)) for k, rx in KINDS}
        if sum(c.values()) >= 2:
            tally.append((sum(c.values()), b["id"], c, b["title"][:80]))
    rows = [f"{i} ans{c['ans']} ask{c['ask']} fix{c['fix']} ref{c['ref']}  {t}"
            for _, i, c, t in sorted(tally, reverse=True)[:20]]
    rows.append("decision lines (first 160 chars):")
    owner = re.compile(r"\bOWNER\b", re.I)
    lines = [f"{b['id']}: {l[11:171]}" for b in w.beads.values() for l in w.lines(b, owner)]
    lines += [f"{b['id']} [close]: {b['close_reason'][:200]}" for b in w.closed
              if "owner" in (b.get("close_reason") or "").lower()]
    return ("Mid-flight decisions per bead in window: owner answers / open questions / "
            "corrections / refuted premises"), rows + capped(lines, CAPS["decisions"])


def revisions_section(w):
    return ("Revisions: decision lines in window that supersede, re-ask, correct or move scope "
            "(classify the cause)"), capped(
        [f"{b['id']}: {l[11:251]}" for b in w.beads.values() for l in w.lines(b, REVISION)],
        CAPS["revisions"])


def recurring(label, extract, mn):
    def section_(w):
        idx = collections.defaultdict(set)
        for b in w.beads.values():
            if b["id"] in w.active or open_at(b, w.end):
                for tok in extract(w, text(b)):
                    idx[tok].add(b["id"])
        rows = []
        for tok, ids in idx.items():
            parents = {parent_of(w.beads[i]) for i in ids}
            if len(ids) >= mn and len(parents) >= 2 and ids & w.active:
                rows.append((len(ids), tok, sorted(ids), len(parents)))
        return f"{label}: in >= {mn} beads under >= 2 parents, >= 1 active in window", [
            f"{tok} ({n} beads, {np} parents): {' '.join(ids[:10])}"
            for n, tok, ids, np in sorted(rows, reverse=True)[:CAPS["recurring"]]]
    return section_


def inversions_section(w):
    return "Priority inversions at window end: instance more urgent than its open caused-by mechanism", [
        f"{b['id']} P{b['priority']} -> mechanism {m['id']} P{m['priority']} {m['title'][:80]}"
        for b in w.open_end for d in b.get("dependencies") or []
        if d.get("type") == "caused-by" and (m := w.beads.get(d["depends_on_id"]))
        and open_at(m, w.end) and m["priority"] > b["priority"]]


def retired_section(w):
    oids = [(p.get("mergeCommit") or {}).get("oid") for p in (w.prs[0], w.prs[-1])]
    title = "Retired vocabulary: backticked terms removed from *.md, absent from the tree at window end"
    if not all(oids):
        return f"{title}: skipped, a PR has no merge commit", []
    s0, s1 = f"{oids[0]}~1", oids[1]
    diff = sh("git", "diff", s0, s1, "--", "*.md", check=False)
    removed = collections.Counter(BACKTICK.findall(
        "\n".join(l for l in diff.splitlines() if l.startswith("-") and not l.startswith("---"))))
    retired = [t for t, _ in removed.most_common(200)
               if not re.search(r"\s", t) and not w.bead_ids.fullmatch(t)
               and subprocess.run(["git", "grep", "-q", "-F", t, s1], capture_output=True).returncode == 1]
    rows = [" ".join(retired[:CAPS["retired"]]), "open beads still citing a retired term:"]
    for b in w.open_end:
        found = [t for t in retired if t in text(b)]
        if found:
            rows.append(f"{b['id']} P{b['priority']} [{', '.join(found[:4])}] {b['title'][:90]}")
    return f"{title} ({len(retired)})", rows


def followups_section(w):
    return "PR follow-ups sections", [
        f"#{p['number']}: {re.sub(r'\s+', ' ', m.group(1)).strip()[:500]}"
        for p in w.prs if (m := FOLLOWUPS.search(p.get("body") or ""))]


def kaizen_sections(epic):
    def record(w):
        return (f"Previous dream's record ({epic} metadata {RECORD_KEY})",
                [(w.beads[epic].get("metadata") or {}).get(RECORD_KEY) or "none: first run"])

    def open_kaizen(w):
        return "Open kaizen beads: id | P | dream checks so far | title", [
            f"{b['id']} | P{b['priority']} | "
            f"{sum('KAIZEN CHECK' in l for l in (b.get('notes') or '').splitlines())} | {b['title'][:110]}"
            for b in sorted(w.beads.values(), key=lambda b: b["id"])
            if parent_of(b) == epic and b["status"] != "closed"]
    return [record, open_kaizen]


SECTIONS = [
    prs_section, hot_files_section, flow_section, created_section, close_reasons_section,
    decisions_section, revisions_section,
    recurring("Recurring identifiers", lambda w, s: identifiers(s, w.bead_ids), 3),
    recurring("Recurring code paths in bead text", lambda w, s: set(PATH.findall(s)), 4),
    inversions_section, retired_section, followups_section,
]


def digest(nums, kaizen=None):
    prs = load_prs(nums)
    beads = {b["id"]: b for b in json.loads(sh("bd", "list", "--all", "--json", "--limit", "0"))}
    if kaizen and kaizen not in beads:
        raise SystemExit(f"kaizen epic {kaizen} not found")
    w = Window(prs, beads, prs[0]["mergedAt"], prs[-1]["mergedAt"])
    out = [f"# Dream digest: {len(prs)} PRs #{prs[0]['number']}..#{prs[-1]['number']}, "
           f"window {w.start} .. {w.end}",
           "Bead open/closed is as of window end; priority is current."]
    for s in SECTIONS + (kaizen_sections(kaizen) if kaizen else []):
        title, rows = s(w)
        out += [f"\n## {title}", *rows]
    return "\n".join(out)


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
