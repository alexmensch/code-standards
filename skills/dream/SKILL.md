---
name: dream
description: Step back from a window of merged PRs and find what no single session saw — trends, repeated mistakes, inefficiencies, stale context, plan problems — plus direct feedback on the owner's own consistency, as a short lettered report the owner approves by letter. Approved items become tracker edits or new tickets under a standing kaizen (continuous-improvement) epic, each re-checked by the next two dreams. Projects tracked with `bd` only. Use for "/dream last <N>", "/dream <A>..<B>", "/dream <PR numbers>", and when `pickup-epic` launches it every 10 landings.
---

# Dream

A step back over a window of merged PRs. Each worker saw its own ticket and
the coordinator saw its epic; this pass looks across them. Load the tracker's
skill (`beads`) now.

**Project extension.** If the available skills include one whose name ends
`-dream` and that is scoped to this repository, load it now. It names the
project skills to load before verifying a lead, and the kaizen epic. It never
restates what those skills hold. With none, the run has no kaizen epic: the
digest's kaizen sections and the report's KAIZEN CHECK say `no kaizen epic`,
and § 4 asks the owner where each new ticket goes.

## 1. The window

The argument is `last <N>`, a range `<A>..<B>` (the merged PRs numbered
inside it), or PR numbers. `pickup-epic` launches this with the PR numbers
landed since its previous dream.

## 2. The digest

From the repo root, with the kaizen epic when there is one:

```bash
python3 -I <this skill's folder>/scripts/digest.py --kaizen <epic> <window> > <a temp file>
```

Read all of it. It is raw material, not measures: PRs and hot files, the
ticket flow per parent, owner decisions and revisions per ticket, identifiers
and code paths recurring across parents, `caused-by` priority inversions,
doc terms retired in the window that open tickets still cite, PR follow-ups,
the previous dream's record and the open kaizen tickets. Its sections are
**not a checklist and carry no expected findings**: look for what stands out
in this window, including what no section was built to show.

Decision and revision lines are read from ticket notes by their leading
`YYYY-MM-DD`; an undated note is invisible to the digest.

## 3. The pass — read-only until the owner approves

- **Write nothing** until § 4. Reads only: the tracker's read operations,
  `git log`, `git show`, `git grep`, `gh pr view`.
- **Ticket state is as of the window's end.** When a read shows a problem
  was resolved since, say so in the item rather than dropping it: that is
  calibration.
- **Verify before proposing**: each candidate gets at most 2–3 targeted
  reads (one ticket, one README section, one `git log`). Drop anything not
  confirmed. Spend at most ~25 tool calls in all.
- **Never re-litigate an owner decision recorded in the window.** An owner
  answer is a settled premise; a follow-on it implies is fair.
- **Never read closed kaizen tickets or earlier reports.** The previous
  record's rejects are the only history: an item it rejected comes back only
  on new evidence, and says what is new.

### The gate — no count cap

An item is in only if all three hold:

1. **Forward-acting** — it changes open work (a ticket's description,
   priority, dependency, or whether it should start before a design
   session), a context artifact (README, agent instructions, memory, skill),
   or the process. An observation with no action is out.
2. **Evidenced** — two independent signals in the digest, or one confirmed
   by a read.
3. **Not settled** — no owner decision in the window covers it.

Rank survivors by **leverage**: how many open tickets, future PRs and
sessions the action changes. Show every survivor; never pad, never trim to a
number. One item per run may prune the kaizen epic itself.

Kinds worth looking for, never a quota:

- **design-pause** — a ticket or epic should not launch until a design
  session settles something, such as siblings of a ticket that needed many
  mid-flight owner answers.
- **mechanism** — the same mistake or fix three or more times wants a type,
  a test or a single owner (`code-craft` § Bug classes). Name the instances.
- **process-fix** — the way work runs is costing time: landing contention,
  rework loops, corrected counts.
- **context-sync** — a README, memory, skill or ticket states something the
  window made false.

### Owner feedback — direct, not softened

The owner wants honest feedback on their own consistency. From the
decisions and revisions sections, classify each revision by cause. A
revision on new evidence is healthy and is no inconsistency. Flag: an answer
that contradicted a written rule; the same question answered differently on
two tickets; scope handed back and forth; a question a written rule already
answered, where the fix may be the worker's. Attribute each to whoever
could have prevented it — owner, worker or the question's format — with the
process change that would have.

### Kaizen check

For each open kaizen ticket: did the problem it targets recur in this
window? `worked`, `no change` or `regressed`. A ticket at its second check
(the digest's count is 1) also becomes an item: **standardise** it into the
skill, README or agent instructions that should own it, if it worked;
otherwise **drop** it.

## The report

Present it to the owner under an ASCII-art banner generated from this
window's contents — whatever it suggests, open-ended. Then exactly this
shape, readable in under a minute:

```text
WINDOW: <PR range> (<N> PRs, <date span>)
SIGNALS USED: <which digest sections carried the findings>

A. <one-line headline>
   Why: <one line of evidence, with IDs>
   Do: <one line: the concrete action>

B. ...

OWNER FEEDBACK
   Volume: <owner answers in the window; how many tickets needed 3+>
   Revisions by cause: <only causes that occurred, with counts>
   <1–3 lines, each a specific inconsistency or avoidable question, with
   ticket IDs and the process change that would have prevented it; "none"
   is a valid answer>

KAIZEN CHECK: <each open kaizen ticket: worked | no change | regressed, or "first run">

DROPPED: <count only, e.g. "5 checked and dropped (3 resolved since, 2 settled by owner)">
```

The owner approves, rejects or amends by letter.

## 4. Acting on approved letters

Act only on what the owner approved, as they amended it.

- **An edit to an existing ticket** — priority, dependency, description,
  close, note — is written directly with the tracker's operations.
- **A change to any file** becomes a new ticket under the kaizen epic, never
  a file change or PR from this session. Write it shovel-ready by
  `pickup-task` § 2: outcome, checkable acceptance, no open decision, one
  PR's worth. What the Do line leaves open, ask the owner for.
- **Kaizen checks**: note each open kaizen ticket with `DREAM <window>
  KAIZEN CHECK: <verdict>`. An approved standardise files its new ticket,
  then closes the kaizen ticket naming it; an approved drop closes it with
  the reason.

## 5. The record

Once the owner says they are done, replace the kaizen epic's
`dream_record` field — the tracker skill maps the operation — with one
line: `DREAM <window>: approved <letter> → <IDs written>, …; filed <new
IDs>; rejected <letter> <headline>, …`. It is the only history the next
dream reads, and what `pickup-epic` reads to bring the filed tickets into
its run.

Launched by `pickup-epic`, end by telling the owner to tell the coordinator
the dream is done.
