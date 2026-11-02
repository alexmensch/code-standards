---
name: beads
description: >
  Exact `bd` (beads issue tracker) command syntax — creating beads and epics,
  closing with a reason, wiring dependencies in the correct argument order,
  appending notes, updating fields, and storing memories. Use whenever a session
  runs or plans to run `bd`, or the user mentions beads, bd, a bead, or an issue
  ID like `foo-a3f8`. Read this instead of reaching for `bd --help`. Also the
  tracker reference `pickup-task` and `pickup-epic` load in a bd project.
---

Syntax reference for `bd`. Verified against **bd 1.2.2**.

Covers the common operations only. The `bd prime` output is loaded every
session and carries the workflow rules, priority scale and command inventory —
none of that is repeated here.

## Tracker operations — what the pickup skills name, in bd

`pickup-task` and `pickup-epic` name tracker operations, never commands. In a
bd project:

| Operation | bd |
| --- | --- |
| Read an item and its parent chain | `bd show <id>`; repeat on its `PARENT` line to the root |
| Ready items under an epic, any depth | `bd ready --parent <epic> --exclude-type epic --limit 0` |
| The whole tree under an epic | `bd list --all --json --limit 0`, walked down the `parent` key from the epic ([never by ID](#a-hierarchical-id-never-follows-a-reparent--read-the-parent-not-the-id)) |
| What an item waits on · what waits on it | `bd dep list <id>` · `bd dep list <id> --direction=up` |
| Record a dependency | `bd dep add <blocked> <blocker>`, then verify ([order](#dependencies--argument-order-is-the-trap)) |
| Claim · release | `bd update <id> --claim` · `bd update <id> -s open -a ""` |
| Append a decision or finding | `bd note <id> "text"` |
| File new work under an epic | `bd create "Title" --parent <epic> -p <n> -d "…"` |
| Close | `bd close <id> -r "Shipped in PR #N"` |
| Replace · read the epic's run state | `bd update <epic> --set-metadata "run_state=<text>"` · `bd show <epic> --json \| jq -r '.[0].metadata.run_state'` |

`bd ready --parent` without `--exclude-type epic` returns the sub-epics too,
and without `--limit 0` stops at 100. In the `--json` tree, an item's open
blockers are its `dependencies[]` entries with `type == "blocks"` whose
`depends_on_id` is not `closed`; `parent-child` and `relates-to` entries never
block.

## Create

```bash
bd create "Title" -t bug -p 1 -d "Description"
bd create "Title" --parent <epic-id> --labels perf,gpu
bd create "Title" --silent      # prints ONLY the new ID — use to capture into a var
bd create "Title" --dry-run     # preview; creates nothing
```

- `-t`: `bug|feature|task|epic|chore|decision` (default `task`). Aliases:
  `enhancement`/`feat`→feature, `dec`/`adr`→decision.
- `--due` / `--defer` accept `+6h`, `+1d`, `+2w`, `tomorrow`, `next monday`,
  `2025-01-15`.
- Also settable at create time: `--acceptance`, `--design`, `--notes`,
  `--context`, `--estimate <minutes>`, `--external-ref`, `--assignee`,
  `--id <explicit-id>`.
- Batch: `-f/--file <markdown>`, `--graph <plan.json>`.

### `--deps` inverts on `blocks:`

`--deps` takes `id` or `type:id`, comma-separated:

| Form | Effect |
| --- | --- |
| `--deps=<id>` | new bead **depends on** `<id>` |
| `--deps=blocks:<id>` | new bead **blocks** `<id>` — the reverse |

Other edge types attach as written (`--deps=discovered-from:<id>`). Confirm
with `bd dep list <new-id>`.

## Epics and hierarchy

There is no `--epic` flag; an epic is just `-t epic`.

```bash
bd create "Epic title" -t epic
bd create "Child" --parent <epic-id>    # child inherits the parent's labels
bd update <id> -t epic                  # promote an existing bead
bd update <child> --parent <new-epic>   # reparent; --parent "" removes the parent
```

`--no-inherit-labels` opts a child out of label inheritance.
Read-only: `bd children <epic-id>` · `bd epic status`.

**`bd epic close-eligible` is a WRITE, and it takes no confirmation.** Despite
reading like a query beside those two, it closes every epic whose children are
all complete, in one go. A **standing** epic — one deliberately left open so
future waves of work accumulate under it — sits at all-children-complete as its
normal resting state between waves, so it is exactly what this command
silently closes. Never reach for it to survey or list; use `bd epic status`.

### A hierarchical ID never follows a reparent — read the parent, not the ID

`bd` assigns `parent.N` IDs at creation and **never renumbers**, so a reparent
leaves the ID advertising an epic the bead no longer belongs to: `foo-abc.41`
can live under a completely different epic. Reading parentage off the ID prefix
is therefore wrong, and it is wrong silently — a prefix filter over `bd list`
returns a plausible set that is not the epic's children.

Authoritative parentage: `bd children <epic-id>`, or the `parent` field in
`bd list --json` (**the key is `parent`, not `parent_id`** — `parent_id` reads
empty for every bead and a script keying on it reports every bead as an
orphan). `bd show <id>` prints it under `PARENT`.

Before any bead move, re-derive the set from one of those, never from the IDs —
and on the moves themselves, `bd note` the new parent, since the ID will
mislead every future reader.

### Never create a bead outside an epic — law

Every bead gets a parent at **creation** time: `--parent <epic-id>` on the
`bd create`, not a reparent afterwards. An orphan is a defect — the graph is
how work gets planned, and a top-level bead is invisible in it.

No appropriate epic exists → **stop and ask.** Propose one (title, one-line
scope, priority, and where it sits under any existing epic) and let the user
create it or approve creating it. Never invent an epic unasked, and never file
the child orphaned "for now" intending to reparent later.

Applies to beads filed mid-task for follow-up work, which is exactly where the
orphan slips through. Audit with
`bd list --status=open --no-parent --exclude-type=epic` (`--no-parent` shows
only top-level issues; epics are excluded since a root epic is legitimately
parentless); fix with `bd update <id> --parent <epic-id>`.

### `bd orphans` means the other sense of orphan — never `--fix` blind

Unrelated to the parentless orphan above: `bd orphans` lists beads whose ID
appears in a landed commit message while still `open`/`in_progress`, and
`--fix` closes the whole list behind one confirmation.

A commit subject names the epic its work sits under, so an epic is flagged the
moment any ONE of its children ships — on a mature graph most hits are false and
`--fix` closes live epics. Read every hit: `bd show <id>` for children not yet
complete, and its notes for a `REMAINING for close` line, which outranks the
commit reference. Treat the list as a prompt to read, never as a to-do.

`--details` names the matching commit per bead. The parentless audit is the
`bd list` command above, not this.

## Listing commands truncate silently — pass `--limit`

`bd ready` (and the other listers) cap their output well below the real result
set and print no notice that they did, so a grep over the default output
reports a subset as if it were the whole answer — "only one child is ready"
when four are. Nothing in the output distinguishes a short list from a
truncated one.

Pass `--limit <n>` well above the expected count whenever the answer is
"which / how many", rather than a glance at the top of the queue. On a mature
graph a high limit can run long — background it rather than raising the tool
timeout.

## Dependencies — argument order is the trap

```bash
bd dep add <blocked> <blocker>                # FIRST arg depends on / is blocked by the SECOND
bd dep add <blocked> --blocked-by <blocker>   # same thing, flag form
bd dep add <blocked> --depends-on <blocker>   # alias of --blocked-by
bd dep <blocker> --blocks <blocked>           # the INVERSE form
```

`--blocks` exists on `bd dep` only — **not** on `bd dep add`.

- `-t/--type`: `blocks` (default) `|tracks|related|parent-child|
  discovered-from|until|caused-by|validates|relates-to|supersedes`.
- Inspect: `bd dep list <id>` shows what it depends on;
  `bd dep list <id> --direction=up` shows what depends on it; `-t` filters by
  type. Verify every dep write this way — the direction is easy to invert.
- `bd dep remove <id> <depends-on-id>` · `bd dep relate <a> <b>` (bidirectional
  see-also) · `bd dep unrelate` · `bd dep tree <id>` · `bd dep cycles`.
- **`blocks` only joins like kinds: epic↔epic or non-epic↔non-epic.** A task
  blocked by an epic, or an epic blocked by a task, is refused ("epics can only
  block other epics, not tasks" / "tasks can only block other tasks, not
  epics"). A blocked epic drops **all its descendants** out of `bd ready`, so to
  hold a whole epic's queue behind a set of tasks, make those tasks children of
  an epic and block on that epic.
- **One edge per pair — `bd dep add` will not change an existing edge's type.**
  A pair already linked (commonly by an earlier `bd dep relate`) rejects the
  write: `dependency A -> B already exists with type "relates-to" (requested
  "blocks"); remove it first`. Nothing is written, so the graph is unchanged.
  To upgrade, `bd dep remove` then re-add — and first ask whether the teeth are
  wanted, since `blocks` pulls the bead out of `bd ready` while `relates-to`
  does not. Two beads landing in one PR rarely need the upgrade.
- Bulk: `bd dep add --file <jsonl>`, one
  `{"from":"<blocked>","to":"<blocker>","type":"blocks"}` per line.

## Notes

```bash
bd note <id> "text"        # APPENDS — shorthand for: bd update <id> --append-notes "text"
bd note <id> --file notes.txt
bd note <id> --stdin
```

`--notes` **replaces** the field; `--append-notes` adds with a newline
separator. Default to appending.

## Update

```bash
bd update <id> -s in_progress -p 1 --title "New title"
bd update <id> --claim          # atomic: assignee=you, status=in_progress, idempotent
bd update <id> -s open -a ""    # unclaim: no `unclaim` subcommand exists
bd update <id1> <id2> -p 2      # batch
```

- Labels: `--add-label a,b` · `--remove-label a` · `--set-labels a,b` (replaces
  all existing). `bd tag` takes exactly `<id> <label>` — one bead per call;
  labelling several beads at once is `bd update <id...> --add-label <label>`.
  Whole-graph inventory reads (`bd label list-all`, and `bd stats` / `bd stale`
  on a mature graph) can run past a 120 s tool timeout — launch them in the
  background rather than raising the timeout.
- Metadata: `--set-metadata k=v` (repeatable) · `--unset-metadata k`. Keys must
  match `[a-zA-Z_][a-zA-Z0-9_.]*` — **no hyphens**, so `prior-art-pr` is
  rejected while `prior_art_pr` is accepted. A batch update fails on the first
  bad key and writes nothing.
- With **no ID**, `bd update` / `bd close` act on the **last touched** bead
  (most recent create, update, show or close). Always pass the ID explicitly.
- `bd reopen <id>` reverses a close. `bd assign` / `bd priority` / `bd tag` /
  `bd label` are single-field shortcuts.

## Close, with a reason

```bash
bd close <id> -r "Shipped in PR #123"
bd close <id> --reason-file reason.md
bd close <id1> <id2> <id3> -r "one reason covering all"
bd close <id1> <id2> -r "reason for id1" -r "reason for id2"
```

Reasons map **positionally** to IDs, regardless of where the flags sit on the
command line. Supply either one `-r` for all IDs, or exactly one per ID.

`--suggest-next` lists newly unblocked beads · `--claim-next` claims the next
one · `-f/--force` closes pinned beads or unsatisfied gates.

### There is no close type — the reason IS the type

`bd close` has no resolution, outcome or close-type flag, and the status enum
carries no `wont_do`. Valid statuses: `open in_progress blocked deferred closed
pinned hooked`. So a close that is *not* a completion — abandoned, superseded,
invalid, obsoleted — has only one place to say so: say it in the first line of
`-r`, since that line is what `bd show` and `bd list` surface.

Asked for "the appropriate close type", answer with a reason whose opening
words name the outcome, and pick the operation that matches the intent:

| Intent | Operation |
| --- | --- |
| Shipped | `bd close <id> -r "Shipped in PR #N"` |
| Abandoned, may return | `bd close <id> -r "Not done — abandoned unshipped. <why>"` |
| Coming back on a known date | `bd defer <id> --until=<date>` — stays open, hidden from `bd ready` |
| Replaced by another bead | `bd supersede <id> --with=<new-id>`, then `bd close <id> -r ...` |

**`bd supersede` closes the bead with an EMPTY `close_reason`.** It writes the
replacement link and nothing a reader sees in `bd show` / `bd list`, which is
where a close's outcome is meant to live. Follow it with
`bd close <id> -r "Superseded by <new-id> — ..."`; `bd close` accepts an
already-closed bead and fills the reason in place, no reopen needed.

Before closing unshipped, append the findings with `bd note` — a close reason
is one paragraph, and whatever a future attempt would otherwise re-derive
belongs in the notes. Correct any "Delivered" / "Implemented" claim the
description now contradicts in the same note.

## Memories

```bash
bd remember "the insight" --key <slug>   # updates in place if <slug> already exists
bd memories [search-term]
bd recall <key>
bd forget <key>
```

`bd remember <bare-existing-key>` with no `--key` **recalls** that memory rather
than storing it, so pass `--key` whenever the content itself is slug-like. There
is no file flag — the content must be an inline string.

## Deleting throwaway beads

`bd delete <id...> --force` removes beads and all their dependency links; it is
permanent. Useful for cleaning up beads created to verify CLI behaviour. It
refuses when a bead has dependents outside the deletion set unless `--cascade`.

## Long or multi-line field values

`bd create` and `bd update` take `--body-file <path>` (description),
`--design-file <path>` and `--stdin` (alias for `--body-file -`); `bd close`
takes `--reason-file`. Prefer these for ANY multi-line value.

- **`--description "$(cmd)"` silently WIPES the field when `cmd` fails.**
  Command substitution yields an empty string and bd accepts it, blanking a
  whole description. Stage the body to a file, verify it separately (`wc -l`),
  then run the bd command on its own.
- There is **no `--notes-file`**, and `bd remember` has **no file flag** at all.
  Both need an inline string: single-quote it and keep apostrophes out of the
  text, or the shell fights you.
- **Inside a git worktree**, the worktree guard rejects any command containing
  `$( )` — it objects to the substitution, not the path. So `--body-file` /
  `--design-file` is the only workable route for a long field there, and chains
  like `test -s body.md && bd update ...` are rejected too.

## Sizing a bead

Size a bead to ONE focused chunk of work plus a stated smoke/test step — small
enough to land inside a compact context window, so a session reset between beads
costs nothing.

That is a **sizing** heuristic, not a packaging rule. Several beads may ship in
one PR. Never cite bead sizing as grounds to split a PR, defer a bead, or call a
multi-bead PR wrong; there is no one-bead-one-PR rule. Granularity *within* a PR
is a separate concern: topical commits, one concept each.

Work bigger than one focused chunk becomes an epic with children **at creation
time**, not a re-split later.

Seams to decompose along: research/decision → implementation (the decision is
its own deliverable) · data pipeline → runtime · independent affordances bundled
together · distinct sub-system additions under one epic · per-source ingest where
each source ships independently.

Do **not** decompose genuinely indivisible work: a single bug fix, a focused
refactor, a one-output decision, a one-DOM-change UX tweak.

Wiring at creation time: convert a parent to `-t epic` once it has children ·
parent holds the master spec, children carry scope + acceptance criteria + smoke
step · use `bd dep` between siblings rather than "see issue X" prose · if the
parent is deferred, defer the children too.

## Spawning subagents in a bd project

Subagents start with **no bd memories and no workflow context** — the
SessionStart hook does not fire for them, and a subagent weighing tradeoffs
without project memories produces confused reports it cannot be redirected out
of.

Put this at the top of any subagent prompt whose work could be informed by
project conventions:

    Before starting, run `bd prime`. If the output ends with a truncation
    notice — "Output too large (NN.NKB). Full output saved to: <path>"
    followed by "Preview (first 2KB):" — Read the full file at the absolute
    path given. The preview is NOT representative; memories and workflow
    protocols are past the cutoff.

Exempt: pure mechanical lookups (grep for X, report file:line). Not exempt:
anything proposing code changes, restructuring beads, weighing tradeoffs, or
evaluating validation patterns.

## Keep this skill current — do this without being asked

This file is the record of what the CLI actually does, so it has to track the
CLI. While using `bd`, if you ever:

- ran `bd ... --help` because this skill did not answer the question,
- found something here wrong, stale, or contradicted by real behaviour,
- used a `bd` feature worth having on hand next time, or
- **had the user correct a `bd` action of yours.**

then **change it at the source in that same session**: the installed copy's
notice names the bundle repo, and the installed copy itself is guarded. Edit
`skills/beads/SKILL.md` there on a branch in its own worktree and open a PR. Do
not ask permission and do not defer it to a follow-up; an unrecorded lookup is
a lookup every future session repeats.

That last trigger is the one that gets skipped, because the rule usually *does*
exist somewhere and the miss reads as carelessness rather than a documentation
gap. Treat a correction as a defect in this file until proven otherwise: fix
the thing, then ask why the skill let you get it wrong. If a rule was written
down and still got violated, the pickup point is what failed.

How to edit it well:

- **Fix the principle, not the incident.** Write the rule that catches the
  class, not a note about what happened once. An incident is evidence that a
  gap exists, not a description of its shape — ask what general rule the miss
  is an instance of, and whether the right fix is a rule change, a pointer, or
  different trigger wording. A file that accretes one paragraph per past
  mistake becomes a changelog nobody reads; the incident belongs in the commit
  message, not here.

- **Verify against the running CLI before writing** — run the command, read its
  `--help`, or create a throwaway bead and `bd delete --force` it afterwards.
  Never record remembered syntax.
- Keep the register: syntax, accepted values, and gotchas. No prose, no
  rationale, no worked examples beyond a command line.
- Do not restate anything already in `bd prime` output.
- Update the "Verified against" version at the top if the CLI version moved.
- Say in one line that you updated the skill, and what changed.
