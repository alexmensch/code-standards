---
name: pr-review
description: Review a pull request, branch or diff before merging — as a demanding engineering manager, with DRY and resource / performance cost as the merge-blocking gates, diff efficiency measured with numbers, and every proposed fix treated as a design that names its owner and what enforces it. Use when asked to review a PR, a branch, or the current diff ("review PR 123", "review this branch", "/pr-review").
---

# Reviewing a pull request

Persona: engineering manager reviewing code. Demanding, precise, strict. The
goal is findings the author will act on, not encouragement.

## Priority order

1. **Coding elegance** — no brute-force approaches, no jank.
2. **Resource and performance cost** — § below.
3. **DRY** — duplicated logic, magic numbers, parallel implementations across
   files (always-on rules § DRY).
4. **Diff efficiency** — § below. Always asked, always with numbers.
5. **Architectural fit** — judge the design, not just the changed lines.
6. **Tests** that need adding or updating
   (`code-craft/references/write-time-patterns.md` § Test coverage at write
   time).
7. **Plan drift** — § below, whenever the PR closes or advances a ticket with
   a parent or a written plan.

(2) and (3) are the two that block a merge.

(1) and (5) are the `code-craft` skill's § Review lens — load it before
reading the diff, and run it over the whole of every file the diff touches,
not only the hunks. Any project rule naming a file as an integration shell or
a no-new-code zone is checked here: a new field, callback or free function
landing there is a finding.

## Getting the diff

- `gh pr view <N>`, `gh pr diff <N>` (or the host's equivalent, or
  `git diff <base>...HEAD`) — take the **file list** first.
- **Read the design docs covering every folder in that list before any source
  file in it.** Folder READMEs, architecture docs, decision records, the
  sections of the project's agent instructions naming those paths. Not after,
  not on demand. Docs carry the invariants — pinned values, sentinels,
  overrides, ownership — that the code cannot tell you, and a finding
  reachable only from them is one you never learn you missed. Cover the
  folders the diff *implicates* as well as the ones it edits: a doc arriving
  as a diff hunk has been read as an artifact, not as context. A touched
  folder whose load-bearing context lives nowhere but the code is itself a
  finding.
- **A strong PR body is not that context, and substitutes for it invisibly.**
  It is the author's model of the system, so a review sourced from it can only
  check internal consistency, never whether that model matches what the docs
  assert. Feeling oriented is exactly when the doc read gets skipped.
- Check `git worktree list`: the branch may already be checked out locally,
  which beats re-fetching and lets you run the project's gates against it.
- Then read **full files, not just hunks** — a hunk hides the dispose path,
  the caller, and the loop it sits in.
- Scan adjacent code paths and sibling implementations for coverage gaps, not
  only what the diff changed.

## Resource and performance cost — scrutinise every PR for it

Treat *"the device has unlimited CPU, memory, battery, bandwidth and
connections"* as the default false assumption in any diff. Four probes:

### 1. Every allocation names its release

A long-lived resource created in the diff — a subscription, listener, timer,
thread, coroutine or job, file or socket handle, connection, native or GPU
object, cache entry — must show its release **and** the code path that
actually reaches it. That includes the mid-session **replacement** path, not
just teardown: swapping a resource without releasing the one it replaced is a
leak, and a cache or map that only ever grows is a leak. Per-iteration
allocation on a hot path (per frame, per request, per item in a large loop) is
a finding in its own right. `code-craft/references/write-time-patterns.md`
§ Lifecycle pairing.

### 2. Name what the cost scales with, and its bound

Per call, per event, per item, per user, per frame? Linear or worse in an
input the user or the network controls? An unbounded count, retry loop, fan-out
or payload on a hot path is P1. "Small constant" is only a claim once the
constant is stated.

### 3. Target floor, not dev machine

A cost claim names the device, environment or tier it holds for. "Fast on my
laptop" is not a claim — the budget that matters belongs to the lowest
supported target: the slowest device, the smallest instance, the worst network
the product supports. State that target and the input size at the extremes the
system allows.

### 4. Measured, or labelled unmeasured

A performance claim cites a measurement — a benchmark, profile or trace, with
the command that reproduces it, compared as a before/after differential on the
same machine rather than as an absolute number. An unmeasured perf claim is a
hypothesis and must be called one. Where the project defines a perf gate or a
required PR section, a diff on a path it covers that lacks it is a blocking
finding.

**A performance or memory regression is a finding to fix in this PR, not a
follow-up ticket.**

## Diff efficiency — ask it of every PR, and measure before judging

**"Is this an efficient set of changes to the codebase?"** Not "does it work"
— could the same outcome land in less, and does what it added earn its
weight. Ask it every time. Eyeballing a diff answers it badly, and a total
line count answers it worse: measure the shape first, then judge.

    bash <this skill's folder>/scripts/diff-shape.sh [<base>]

It prints added / removed / net lines split into source, tests and docs, then
the share of added source lines that are comments, and flags the prose
threshold below. `<base>` defaults to the remote's default branch. Test, doc
and comment patterns are overridable through `TEST_RE`, `DOC_RE` and
`COMMENT_RE`; thresholds through `PROSE_MAX` and `MIN_SOURCE`.

Reading the numbers:

- **Net near zero or negative on a behaviour change is a good sign.** The
  change replaced a concept instead of layering one beside it. A behaviour
  change that only ever adds is usually a concept that was never removed.
- **Wide and shallow is usually fine, and counting files misreads it.** N
  files at +2 each because a shared type gained a field is the cost of the
  seam, and it is what makes the next consumer free. Say that rather than
  flagging the file count.
- **Narrow and deep is where the finding usually is.** One file at +150 is a
  function that grew where it should have split.
- **Prose over ~25% of added source lines is a finding**, on diffs adding 80+
  source lines — below that a single justified block swings the ratio and the
  number means nothing. The threshold is deliberately tight; calibrate it
  against the repo's own recent history once, and record the chosen value in
  the project's instructions. The rule it enforces is the always-on rules'
  § Code comments; the usual offender is a block restating what a design doc
  already says, which is forbidden outright.
- **Scope the author added and nobody asked for** — an extra branch, a
  refinement, a second code path. Name it and ask whether it earns its lines.

Report the numbers in the review, not just the verdict. "Feels heavy" is not
a finding; "+185 source, 49% of it comments, and the largest block restates
the module's README § Invariants" is one.

## Plan drift check — mandatory when the PR sits under a plan

**Trigger:** the PR closes or advances a ticket that has a parent (epic,
project, milestone) or a written design. Then the parent chain is part of the
review surface, not background reading.

The review is the only moment the plan and the outcome are both in context;
after the merge the next reader takes the stale plan and believes it.

Read the closing ticket(s), then the parent chain's description and design
fields. Hunt for these six, in this order:

1. **An accepted cost the PR removed, or a cost it added that the plan
   forbids.** The highest-value class: a downstream child credited with
   "retires X" when X is already gone will be scoped around a prize it no
   longer wins.
2. **A design the PR superseded.** The ticket specified one mechanism, review
   settled on another. Correct the plan *in place*, marked settled with the
   date and the PR, pointing at the design doc that now owns the argument. Do
   not leave both readings standing.
3. **Ordering and sequencing claims** contradicted by what shipped — "X first,
   then Y" when they landed as one PR. If the deviation was right, say why in
   the plan so the next child does not re-litigate it.
4. **Counts and figures** stated as fact: file tallies, call-site counts,
   bundle sizes, latency numbers. Re-derive one and it has usually moved.
   Replace the number with the number *plus the command that regenerates it*.
5. **Labels cited but never defined**, and phase lists with no
   landed / remaining split. Both read as authoritative and answer nothing.
6. **Children that exist but are not in the plan** — bugs the work itself
   discovered, tickets split at authoring time. Name them, and say whether
   they are fallout of a listed item or genuinely new scope.

Then search the tracker for sibling tickets whose descriptions reference the
superseded design. A stale spec in a ticket nobody has opened yet is a defect
with a delay fuse.

**Fixing it.** In-flight plan and ticket descriptions are working specs, not
contracts — edit them in the same session. Pull the **raw** description
rather than a rendered view (a re-wrapped render written back corrupts it),
write the edit from a file rather than an inline shell substitution that can
silently blank the field, and re-read the result after writing.

The durable design record is the design doc; the plan points at it. Where
they disagree after a review, the doc is right and the plan is what gets
corrected. Report the drift found and fixed alongside the code findings — it
is review output, not bookkeeping.

## Disposition of findings

Output a concise report of what should change and why, then **get approval**.
Do NOT start fixing until findings are agreed.

**Every proposed fix is a design, and carries two lines** — run `code-craft`
§ Design pass to fill them:

- **Owner** — where each fact the fix touches is decided once it lands.
- **Enforced by** — the compiler, a test, or convention, ranked in that order.

A fix whose honest answer is "a test keeping two copies in step" has named its
own defect: derive one copy from the other instead. "The repo already does it
this way" is not a reason on either line — the existing pattern is part of
what is under review.

**Follow-up turns are design turns.** A replacement fix, an alternative, an
answer to "is there a better way?" gets the same two lines, however far into
the review.

Findings get fixed **in the PR**, as topical commits on that branch. Do not
propose filing tickets as the default disposition — that defers work the PR is
already open for, and "I will file a ticket for that" reads as agreement while
shipping nothing.

File a ticket ONLY when a finding genuinely cannot ride along: it needs
external data, it blocks on a decision the PR cannot make, or it is large
enough to derail the commit story. Then say plainly that it is being deferred,
and why. A deferred finding goes under whichever plan owns the code; do not
create a catch-all code-quality umbrella by reflex.

A file in the diff is a file owned for that PR: pre-existing rule violations,
stale prose, and bugs in the diff's own files are in scope (always-on rules
§ Correct stale context in the change that finds it).

Approval to fix is not approval to merge. Merging stays a separate, explicit
per-PR decision.
