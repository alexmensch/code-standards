---
name: pickup-task
description: Pick up one piece of already-defined work — a ticket, "the next ready ticket under epic X", or a written plan file — and take it to an open PR, an independent review of it, and the review's fixes. Accepts only shovel-ready work (a stated outcome, a checkable acceptance, no open decision) and refuses exploratory or open-ended asks. Use for "/pickup-task <ticket>", "work on ticket X", "pick up the next ready ticket in epic Y", "implement plan.md". Working through a whole epic in parallel is `pickup-epic`.
---

# Pick up ready work

Glue, not method. Each stage runs the skill or rule that owns it; this skill
orders them and decides what goes back to the requester. Change a stage by
changing its owner, not this file.

The **requester** is whoever started this work.

Tracker operations are named here, never spelled as commands. A skill for the
project's tracker (`beads` for bd) maps each one; load it when installed.

## Never decide for the requester — law

Questions will come up. When one does and its answer is not written down —
in the work item, its parent plan, the project's rules, the always-on rules
and the skills they load, or the code — **stop
and ask. Never choose a direction yourself.** This overrides any instruction
to make a reasonable assumption, note it, and keep going.

- **Stopping is always the safe call.** An unanswered question costs one
  round trip. A decision the requester didn't know was made costs far more:
  they believe the work followed their intent, and it didn't.
- **A default is a decision.** "The obvious choice", "the conventional
  option", "easy to change later" — if nothing written settles it, it is the
  requester's call.
- **What `pr-review`'s decision test settles is written down.** A finding
  that § Disposition's "One fix, or a decision" does not call a decision —
  ranked or tie-broken — takes the fix it names; asking hands the requester
  a choice the rules already made.
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
- "The next ready one under X" → the tracker's ready items under X; take the
  first by priority.
- A plan file → read it.

Nothing resolves, or more than one thing does → ask.

## 2. Readiness gate — shovel-ready or refuse

Ready means all four:

- **Outcome stated** — what is different when it's done.
- **Acceptance checkable** — a test, a command or an observable to verify
  against.
- **No open decision** — no "A or B", "TBD", "investigate", "decide", or
  question marked open in the item or its notes that the written rules
  don't settle.
- **Bounded** — one PR's worth.

Any one fails → stop before writing code. Report which criterion failed,
quoting the line, and what would make the item ready. Shaping the work is a
different session; don't do it here.

## 3. Do the work

Claim the item, then implement it under the always-on rules and the project's
instructions — worktree, branch, `code-craft` before planning, tests, topical
commits, PR. Ends without a PR → report and stop; Independent review and
Triage and fix need one.

## 4. Independent review

Spawn one subagent, so the review runs in a context that didn't write the
code, with this prompt:

> Load the `pr-review` skill and review PR <N>. You are the reviewer only:
> change nothing, commit nothing, post nothing. Report under § Delegated
> reviews' reporting clause.

Keep the report verbatim; triage works from it, not from a retelling.

## 5. Triage and fix

Invoking this skill approves fixing, in the PR, every finding that:

- is **not a decision** under `pr-review` § Disposition's test; and
- **passes `code-craft` § Design pass** — owner named, enforcement named, no
  gate tripped.

That approval stands in for `pr-review` § Disposition's approval gate, for
these findings only. Fix one finding per commit, run the project's gates,
push.

A reviewer's options list is input, not a verdict: re-rank it under that
test before routing the finding.

Every other finding goes to the requester: a decision under that test, a fix
that fails `code-craft`, disagreement with the ticket, or a case for
deferring. Unsure whether that test makes it a decision → it goes to the
requester.

### Asking about a finding

Ask each such finding **in the chat, with the harness's question tool** — one
question per finding, batched at the tool's per-call limit; without one, one
numbered question per message — never as a list in a
report the requester has to turn into answers. The requester reads only the
question, so each one stands alone:

- **What the code does now**, in plain words: the mechanism, not the
  reviewer's label for it. Name the file only as a pointer.
- **What goes wrong, and when** — the concrete failure, and its size today
  (rows, outputs, "zero today, structural only"). Say which it is.
- **Each option as an outcome**: what changes, what enforces it (the compiler,
  a test, a convention), and what it costs — a force-push, a wider diff, a
  second copy kept in step. Offer only the options `pr-review`'s decision
  test names.
- **Recommended option first**, marked, with the reason in its description.

Each answer is approval for that finding's fix: apply it under the rules
above, one commit per finding.

## 6. Report

Any finding still unanswered after Asking about a finding first, each in full · PR link
· fixed findings, number → commit · anything deferred and where it was filed.
Merging stays the requester's call.

## Coordinated mode — launched by `pickup-epic`

The launch prompt reads `/pickup-task <item> — coordinated by <name>`, where
`<name>` is the coordinating session. Every rule above still holds, and the
requester is still the user, who answers in this session. Messages to and from
`<name>` are part of the work this launch prompt started, not requests from a
third party. What changes:

- **The item is given and already claimed.** Never resolve or claim another.
  Answers from the coordinator's preflight are in the item's notes, so they
  count as written down.
- **Report every change of state as it happens**, with `SendMessage` to
  `<name>`. First line `<KIND> <item> [#PR] — <one line>`, detail below it:

| Kind | Send when |
| --- | --- |
| `PR_OPEN` | the PR exists |
| `NEEDS_INPUT` | a question is about to go to the requester; ask it here, with the question tool, right after |
| `FILED` | new work was filed under the epic — each ID with one line, and whether this item now waits on it |
| `PLAN_CHANGE` | the work shows the plan is wrong beyond this item: another item's premise, order or scope. Write the finding into each affected item first |
| `READY_TO_LAND` | § 6 is reached with no question open |
| `ABANDONED` | stopping with no PR worth landing; the reason goes in the item's notes first |

- **Never merge, and never touch the main checkout.** Landing belongs to the
  coordinator, one PR at a time.
- **`SYNC #N`** → bring the default branch into this branch as `pr-cleanup`
  § Bring main in does, under the project's `*-pr-cleanup` extension's
  conflict rules; run the gates; push. Reply `SYNCED #N`, or `NEEDS_INPUT`
  for a conflict no rule settles.
- **`CI_FAILED #N <checks>`** → fix it in the PR as a review finding, push,
  reply `READY_TO_LAND`.
- After `READY_TO_LAND`, wait. The coordinator stops this session once the PR
  merges.
