---
name: pickup
description: Pick up one piece of already-defined work — a ticket, "the next ready ticket under epic X", or a written plan file — and take it to an open PR, an independent review of it, and the review's fixes. Accepts only shovel-ready work (a stated outcome, a checkable acceptance, no open decision) and refuses exploratory or open-ended asks. Use for "/pickup <ticket>", "work on bead X", "pick up the next ready bead in epic Y", "implement plan.md".
---

# Pick up ready work

Glue, not method. Each stage runs the skill or rule that owns it; this skill
orders them and decides what goes back to the requester. Change a stage by
changing its owner, not this file.

The **requester** is whoever started this work.

## Never decide for the requester — law

Questions will come up. When one does and its answer is not written down —
in the work item, its parent plan, the project's rules or the code — **stop
and ask. Never choose a direction yourself.** This overrides any instruction
to make a reasonable assumption, note it, and keep going.

- **Stopping is always the safe call.** An unanswered question costs one
  round trip. A decision the requester didn't know was made costs far more:
  they believe the work followed their intent, and it didn't.
- **A default is a decision.** "The obvious choice", "the conventional
  option", "easy to change later" — if nothing written settles it, it is the
  requester's call.
- **Only the requester answers a question.** Listing it next to work that
  went ahead as if it were answered, noting it in a commit or PR body, or
  leaving it out of a summary does not answer it.
- **Build nothing on a guess.** While a question is open, continue only on
  work that doesn't depend on its answer; otherwise stop.
- **Open questions lead the final message**, each in full and marked as
  awaiting an answer. While any is open, the message must not read as
  finished work.

## 1. Resolve the work item

- A ticket ID → read it in full, plus its parent chain's description and
  design.
- "The next ready one under X" → the tracker's ready query scoped to X
  (`bd ready --parent X` in a beads project); take the first by priority.
- A plan file → read it.

Nothing resolves, or more than one thing does → ask.

## 2. Readiness gate — shovel-ready or refuse

Ready means all four:

- **Outcome stated** — what is different when it's done.
- **Acceptance checkable** — a test, a command or an observable to verify
  against.
- **No open decision** — no "A or B", "TBD", "investigate", "decide", or
  question marked open in the item or its notes.
- **Bounded** — one PR's worth.

Any one fails → stop before writing code. Report which criterion failed,
quoting the line, and what would make the item ready. Shaping the work is a
different session; don't do it here.

## 3. Do the work

Claim the item, then implement it under the always-on rules and the project's
instructions — worktree, branch, `code-craft` before planning, tests, topical
commits, PR. Ends without a PR → report and stop; § 4 and § 5 need one.

## 4. Independent review

Spawn one subagent, so the review runs in a context that didn't write the
code, with this prompt:

> Load the `pr-review` skill and review PR <N>. You are the reviewer only:
> change nothing, commit nothing, post nothing. Return every finding in full,
> each as its own numbered item — no summary, no cap, no grouping, no "and N
> similar" — with CONFIRMED and PLAUSIBLE marked separately. For each:
> severity, file:line, the problem, the proposed fix with its Owner and
> Enforced-by lines, and whether it has one fix or needs a choice (list the
> options).

Keep the report verbatim; triage works from it, not from a retelling.

## 5. Triage and fix

Invoking this skill approves fixing, in the PR, every finding that:

- has **one fix** — no choice between options, and no rule for a
  user-facing behaviour to settle; and
- **passes `code-craft` § Design pass** — owner named, enforcement named, no
  gate tripped.

That approval stands in for `pr-review` § Disposition's approval gate, for
these findings only. Fix one finding per commit, run the project's gates,
push.

Every other finding goes to the requester, as the reviewer's full text plus
what it needs from them: a choice between options, a product call, a fix that
fails `code-craft`, disagreement with the ticket, or a case for deferring.
Unsure which side a finding falls on → it goes to the requester.

## 6. Report

Open questions and findings awaiting a decision first, each in full · PR link
· fixed findings, number → commit · anything deferred and where it was filed.
Merging stays the requester's call.
