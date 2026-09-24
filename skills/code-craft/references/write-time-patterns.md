# Write-time patterns — consistency at the seam

Consistency rules that catch a recurring class of subtle bugs. Each is a
review finding codified so it lands at write time; the review lens walks them
again. They sit alongside the always-on rules' § DRY.

## Lifecycle pairing

Every long-lived resource has its teardown wired in the SAME diff that
introduces it.

- Each subscription, listener, observer, timer or background job stores a
  handle that the dispose / close / cancel path releases.
- Each pool, buffer, cache or map that grows has a hard cap or an idle
  shrink, OR an explicit bound argument (what it scales with, and the worst
  case) where it is defined.
- Each view, slice or borrowed reference returned across a method boundary
  either states its lifetime ("invalidated after grow / close") or returns a
  copy.
- Replacement counts as teardown: swapping a resource mid-session releases
  the one it replaced.

## Sibling symmetry

Two sibling functions, helpers or branches are defensively symmetric. Typical
pairs: encode / decode, serialise / parse, schema v1 / v2, primary / fallback
path, read / write of the same format.

If one clamps inputs, the other clamps. If one asserts a budget, the other
asserts. If one logs on degenerate input, the other logs. Asymmetry invites
"just call the other one — same shape" mistakes downstream. An asymmetry that
is intended is stated as an invariant where both siblings can see it.

## Sentinel-init for dirty-tracking and caches

When introducing a dirty-check, memo or cache:

- The initial "last value" MUST fail the comparison on the first write, so the
  first write lands. Choose a value the real input can never equal (NaN, a
  poison string, a dedicated "never set" variant) — not the natural default,
  which steady state can legitimately match.
- Hide / dispose / reset paths reset every cached input and every sentinel,
  not just visibility flags.
- Cache keys include every input dimension that affects the output — not only
  the obvious one.

## Single source of truth for shared state

Anything several modules read — the clock, current user, configuration,
feature flags, a shared coordinate frame — is read through its one owner,
never re-derived locally (a direct system-clock call where the app has an
injected clock is the canonical offender). A struct mutated mid-operation
either stays coherent as a whole, or carries an invariant stating which fields
are valid in which phase.

## Named constants

The law is *extract at second usage* (always-on rules § DRY). The operational
rules that follow:

1. **Hoist numeric literals at the first sight of a second usage.** Any
   literal referenced in more than one place — or that encodes a tuned or
   calibrated value (thresholds, timeouts, retry counts, bit positions) —
   gets a named constant in its canonical source module. A value calibrated
   by feel MUST be named; the name documents intent.
2. **Tests IMPORT constants from production code, never redefine them.** A
   test's own copy of a magic number divorces it from the production value
   and lets calibration drift go undetected.
3. **Mostly-identical schemas, structures or functions share a builder.** Two
   versions of a wire schema differing in a few entries, two parsers
   differing only in field projection, two solvers differing only in
   tolerance — extract the builder and parameterise the differences.
   "Slightly different X and Y" between two call sites is the case FOR
   extracting, not against it.
4. **Comment-DRY counts.** The same caveat verbatim in two consumer files
   moves to the source helper.
5. **A quantity the system can compute is never a literal in prose or UI.**
   A count, size or version that changes when data or code changes is read
   live where a user sees it; docs that cannot read it round it, and a test
   re-derives the rounding.

## Rename and stale-prose sweep

When a change renames or removes an API surface (function, method, event,
class, mechanism, named threshold), substantively changes the **semantics**
of code in a folder, or **moves a file or a doc section**, treat it as a
sweep, not just a refactor.

1. Search the whole repo for the old name (skip vendored and generated
   trees) and triage every hit.
2. **Open every README and design doc covering a folder the diff touches.**
   Read as if seeing it for the first time. Prose is where search misses
   stale claims — data flow, file rosters, "X feeds Y", "X doesn't handle Y".
3. Re-read the other docs in the diff's context (top-level README,
   architecture docs, agent instructions, release docs).
4. When changing the semantics of a quantity a docblock describes, re-read
   the docblock's rationale and update it if the change invalidates it.
5. Worked numerical examples in docs are recomputed, not eyeballed.
6. A user-visible behaviour change is weighed against the project's
   versioning policy even when the diff is small.
7. **A move's real cost is its inbound references.** The compiler rewrites
   imports and proves nothing about prose. Search for the moved file's name
   and every moved heading across docs and code, and repoint each hit at
   where the content now lives. Leaving the old heading behind as a pointer
   does not discharge this: the reference resolves, the claim it was attached
   to is gone.

## Test coverage at write time

Tests land **in the same PR** as the code, for:

- **Pure helpers** — lifted to module scope, or a separate file, so they are
  testable, then tested.
- **Numeric headline claims** in the PR description — pinned with an
  exact-equality assertion, never an upper-bound one. A bound catches
  regressions past it, not the value the headline claims.
- **Integration paths through new state machinery** — allocate / grow /
  write / flush cycles for buffers, multi-tier reducers, lifecycle state
  machines: each gets a read-back assertion at known values, not a "does not
  throw" smoke.
- **Migration and auto-upgrade paths** flagged as "manual smoke" — promoted to
  automated tests.
- **Every tier of a tiered path** (primary vs fallback) — each exercised, and
  priority asserted separately.

Manual smoke regresses between releases; automated tests don't.

## Pattern coverage across peers

When a change is framed as "apply pattern X to all the Y in this layer"
(every handler, every entry point, every screen, every endpoint), **enumerate
the set of Y explicitly in the PR description and verify each is covered.**
One missed peer makes the headline false.

1. Before starting, write the peer list, from the folder's docs and a search.
2. After implementing, search for the OLD pattern and confirm zero remaining
   sites in scope. Non-zero → convert them, or name them as deliberately
   deferred with a ticket.
3. Two peers that ended up with two strategies → reconcile, or record the
   chosen strategy in the layer's design doc.
4. Extending a feature for one host → check the sibling hosts with the same
   surface; file the sibling work even if out of scope.

## Doc updates — defer descriptions, write decisions now

Don't edit docs to *describe* code still being written: file rosters,
parameter values, data flow, option names — anything that tracks the
implementation. Mid-session description edits churn as direction shifts, and
the paragraph written early ends up describing something that no longer
exists. Sweep them at commit time.

**A settled decision goes into the design doc the moment it is settled.** An
invariant, a rejected alternative and why it lost, why a key is ranked the way
it is — none of that churns once decided. Deferring it has a hidden cost:
until the doc section exists, the only place the reasoning can go is a code
comment, which passes the comment gate honestly because there is no doc yet to
restate, the same reasoning lands in the doc an hour later, and nobody goes
back. That is how a diff ends up half prose.

- Still moving? Code and tests only. Sweep the docs at commit.
- Just settled something that would otherwise be explained in a comment?
  Write the doc section **now**; the code carries a pointer or nothing.
- The tell is the audience. Prose a future reader needs *before* touching the
  code belongs in the doc. Prose that only means anything beside the line it
  sits on is the rare comment that earns its keep.
- A decision that took an argument to reach is the highest-value doc content
  there is. The PR body gets it too — that is where a reviewer meets it.
- At commit time, search the final diff for renames, removed options,
  behavioural shifts and anything user-visible; update only what is now
  stale, and delete the comments the doc now covers.
