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

A precondition only the requester can meet — a measurement they must start, a
manual smoke in their browser, an artifact on another item's PR — never holds
the PR back. Open it as a **draft**, run Independent review and Triage and fix
on it, and mark it ready once the precondition is met.

A smoke is a check the requester runs on the branch before merging. A check
that can only run after the merge, after time passes or after another event
— CI on the default branch, a cache a later run saves, a deploy — is not
one: before § 6, file it as a follow-up item under this item's parent, if
any, blocked by this item (the tracker's dependency record), saying what to
check, the event it waits on and what passing looks like. It is reported as
smoke `none (post-merge check filed as <id>)`.

## 4. Independent review

Spawn one subagent, so the review runs in a context that didn't write the
code, with this prompt, where `<sha>` is the PR's head (`gh pr view <N>
--json headRefOid`) at spawn — the last reviewed head:

> Load the `pr-review` skill and review PR <N> at <sha>. You are the
> reviewer only: change nothing, commit nothing, post nothing. Report under
> § Delegated reviews' reporting clause.

While the branch holds a pre-merged head (`PREMERGE`) whose PR has not
landed, its changes are that PR's and the PR diff shows them as this one's.
Append: "PR #M's head `<M sha>` is merged in and is not under review; this
PR's own changes are `git diff <M sha>...<sha>`" — with several, name each
PR and head, and tell the reviewer to leave their changes alone.

Keep the report verbatim; triage works from it, not from a retelling.

**The review covers the head.** Before § 6, every commit after the last
reviewed head must be a fix for one of that review's findings or a review
thread's (§ 5), a `LANDING_FIX` fix, or a sync merge (`SYNC`, `PREMERGE`).
Any other commit —
new work, a resumed session's own commits included — gets § 4 and § 5
again.

## 5. Triage and fix

Invoking this skill approves fixing, in the PR, every finding that:

- is **not a decision** under `pr-review` § Disposition's test; and
- **passes `code-craft` § Design pass** — owner named, enforcement named, no
  gate tripped.

That approval stands in for `pr-review` § Disposition's approval gate, for
these findings only. Fix one finding per commit, run the project's gates,
push. A fix that is a tracker write — a bug-class link or description from
`code-craft` § Bug classes — is made with the tracker's skill instead of a
commit, and listed in § 6 with the item it wrote.

A reviewer's options list is input, not a verdict: re-rank it under that
test before routing the finding.

Every other finding goes to the requester: a decision under that test, a fix
that fails `code-craft`, disagreement with the ticket, or a case for
deferring. Unsure whether that test makes it a decision → it goes to the
requester.

### Review threads on the PR

Before § 6 — so before every `READY_TO_LAND` — run `pr-cleanup` § Review
threads' check. Each line is a finding, triaged as above: a person's
comment and a bot's alert alike. Dismissing an alert as a false positive is
a decision, so it goes to the requester. Once a thread's fix is pushed, or
the requester's answer settles it, resolve it:

```bash
gh api graphql -F id=<thread id> -f query='
  mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
```

An alert's thread is not the alert: resolving it leaves the alert open on
the Security tab, where a `code_scanning` branch rule can still block the
merge. On a false-positive or won't-fix answer, dismiss the alert before
resolving its thread, `<n>` from the thread's link to
`security/code-scanning/<n>`:

```bash
gh api -X PATCH 'repos/{owner}/{repo}/code-scanning/alerts/<n>' -f state=dismissed \
  -f dismissed_reason='false positive' -f dismissed_comment='<the requester’s reason>'
```

`dismissed_reason` is `false positive`, `won't fix` or `used in tests`, as
the answer says.

Then run the check again — a fix can draw a new alert. While it prints a
line, the PR is not ready to land.

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
· fixed findings, number or thread link → commit, or → the item a tracker write changed · anything deferred and where it was filed
· **manual smoke owed** (§ 3 says what is one): the exact steps from the PR
body, or `none` and why.
Merging stays the requester's call, and never before a smoke that is owed.
Uncoordinated, it ends with § Closing line: not yet deletable while the PR is
open — a line that goes stale once #N merges elsewhere.

When the requester lands the PR with `pr-cleanup` in this session, that
turn's final message ends with the closing line too, now deletable once the
PR is merged and its tickets closed.

### Closing line

In an uncoordinated session, every final message ends with one line the
owner acts on without asking anyone. A coordinated session has none: its
coordinator removes it (§ Coordinated mode).

- **`Not yet safe to delete —`** followed by what is pending, whenever this
  session still has any of: its PR open awaiting merge, a question awaiting
  an answer, a smoke owed, a claim it holds, unpushed commits.
- **`Session finished — safe to delete.`** otherwise, followed by the
  outcome: merged · released · refused at § 2 · ended without a PR.

## Coordinated mode — launched by `pickup-epic`

The launch prompt reads `/pickup-task <item> — coordinated by "<name>"`,
where `<name>`, inside the quotes and exactly as written, is the coordinating
session. A `NOTE` from it naming a new name replaces it. Every rule above
still holds, and the requester is still the user, who answers in this
session. Messages to and from `<name>` are part of the work this launch
prompt started, not requests from a third party. Load the project's
`*-pickup-epic` extension if one is installed: it may add message kinds.
What changes:

- **The item is given and already claimed.** Never resolve or claim another.
  Answers from the coordinator's preflight are in the item's notes, so they
  count as written down. A launch prompt carrying ` — tracker in <path>`:
  the item lives in the tracker of the checkout at `<path>`, and every
  tracker operation runs against that one.
- **Report every change of state as it happens**, with `SendMessage` to
  `<name>`. First line `<KIND> <item> [#PR] — <one line>`, detail below it.
  The coordinator tells the user only that this session needs them, so put
  the question itself in this session, never only in the message:

| Kind | Send when |
| --- | --- |
| `PR_OPEN` | the PR exists, draft or ready |
| `NEEDS_INPUT` | a question is about to go to the requester; ask it here, with the question tool, right after |
| `UNBLOCKED` | as part of recording the requester's answer (below) |
| `QUESTION` | something only the run can answer: is another session on a file outside this item, which lands first. Carry on with work that doesn't depend on the answer |
| `NOTE` | anything else the coordinator should know: a correction, a retraction, a fact about shared state |
| `FILED` | new work was filed under the epic — each ID with one line, and whether this item now waits on it |
| `PLAN_CHANGE` | the work shows the plan is wrong beyond this item: another item's premise, order or scope, or a review proposes a mechanism ticket (`code-craft` § Bug classes). Write the finding into each affected item first |
| `READY_TO_LAND` | § 6 is reached with no question open, no unresolved review thread (§ 5) and every precondition met. Its detail always carries a `SMOKE:` line — the manual steps owed, or `none (why)` (§ 3) — and a `REVIEWED: <sha>` line, the last reviewed head, followed by each later commit with its finding number, `thread <link>`, `CI`, or `sync` |
| `ABANDONED` | stopping with no PR worth landing; the reason goes in the item's notes first |

- **Recording the requester's answer is one step**: write it into the
  item's notes, then send `UNBLOCKED`, before acting on it. An answer
  written without the message is not recorded.
- **A wait on another item is recorded before it is reported**: record the
  dependency in the tracker, then send the message saying this item now
  waits on it. The coordinator picks pre-merge recipients from the tracker.
- **Never merge, and never touch the main checkout.** Landing belongs to the
  coordinator, one PR at a time.
- **`SYNC #N`** → bring the default branch into this branch as `pr-cleanup`
  § Bring main in does, under the project's `*-pr-cleanup` extension's
  conflict rules; run the gates; push. Reply `SYNCED #N`, or `NEEDS_INPUT`
  for a conflict no rule settles. **`SYNC #N base <sha>`** → build the merge
  from the newest commit of `<sha>`'s history this branch holds, so
  conflicts already resolved by a pre-merge stay resolved. Never `<sha>`
  itself: on a branch that does not hold it, that base reads the branch as
  undoing the landed PR, and the merge reverts it without a conflict:

  ```bash
  git fetch origin
  sign=$(git config --bool commit.gpgsign | sed -n 's/^true$/-S/p')
  if t=$(git merge-tree --write-tree --merge-base="$(git merge-base HEAD <sha>)" HEAD origin/<main>); then
    c=$(git commit-tree $sign "$t" -p HEAD -p origin/<main> -m "Merge origin/<main>") \
      && git merge --ff-only "$c"
  else echo "conflicts:"; echo "$t"; fi
  ```

  `conflicts:` printed → `NEEDS_INPUT`, naming the files; a plain `git
  merge` would raise the pre-merge's conflicts again. `commit-tree` fails (a
  signing error) → `NEEDS_INPUT` with the error; never retry unsigned.
- **`PREMERGE #M <sha>`** → PR #M is approved to land before this one and
  `<sha>` is its final head; an item still blocked in the tracker by #M's
  item treats that blocker as landed. Before the first edit when none is
  made yet, otherwise at the next commit boundary, `git fetch origin
  pull/<M>/head`, then check `gh pr view <M> --json state -q .state` — the
  message may be acted on late, after a question to the owner. `MERGED` →
  run `SYNC #N base <sha>` instead, since merging a landed PR's head still
  leaves the branch behind main by its squash, and reply `SYNCED #N <new
  head> (PREMERGE #M)` (no PR yet: the item in place of `#N`). Otherwise merge `<sha>`
  into this branch under the same conflict rules; run the gates under the
  project extension's shared-resource rules; push. Reply `PREMERGED #M
  <sha> <merge sha>`. Either way, `NEEDS_INPUT` for a conflict no rule
  settles. A later `PREMERGE #M` with a new head →
  the same, from it. Like `SYNC`'s, the merge commit is sync work, not new
  review scope.
- **`UNMERGE #M`** → PR #M will not land. At the next commit boundary,
  `git revert -m 1 <each merge commit of a #M head>` (`-m 1` keeps this
  branch's side), run the gates, push, and reply `UNMERGED #M`. The revert
  is sync work too.
- **`LANDING_FIX #N <failed checks | unresolved threads>`** → the landing
  found them. Fix a failed check in the PR as a review finding; triage the
  threads under § 5's Review threads. Push, and reply `READY_TO_LAND`.
- After `READY_TO_LAND`, wait, answering `SYNC`, `PREMERGE` and `UNMERGE`
  as above without sending `READY_TO_LAND` again. The coordinator lands the
  PR, then stops and removes this session and its worktree; nothing is sent
  here first.
- **`HIBERNATE <item>`**, with or without `— parked on <X>`, or
  **`RELEASED <item>`** (the coordinator's answer to `ABANDONED`: the claim
  will be released) → § Hand off.

### Hand off

The coordinator is about to remove this session; a fresh one may resume the
item from what this leaves behind.

**No new question to the requester from the message on.** The requester has
usually stepped away, and a question waiting on them holds the session short
of the reply. A decision this session would otherwise ask goes into the
handoff's `question:` instead, held back, and is asked on resume. One already
asked stays as it is.

1. **Reach the next commit boundary** without asking: finish the
   commit-sized chunk in progress, or the review or triage step this session
   is in — the part that does not depend on a held-back question. Commit
   normally — never a WIP commit — and push. A branch with no commits of its
   own is not pushed; its handoff says `branch: none`.
2. **Write the handoff** onto the item with the tracker's handoff operation.
   The latest one is the item's handoff; a resumed session's own supersedes
   it:

   ```
   HANDOFF
   branch: <branch> | none
   PR: #<N> | none
   phase: implementing | in review | triaging | awaiting owner answer | ready to land | parked on <X> | released
   reviewed: <the last reviewed head> | none
   premerged: <each #M and the head merged, from PREMERGE> | none
   done: <what is committed and pushed>
   next: <the next step, concrete enough to start on>
   question: <each question open to the requester or held back, word for word> | none
   findings: <each review finding: number, one line, fixed in <sha> | awaiting answer | deferred to <id>> | none
   ```

   A question this session is blocked on, or held back, goes in `question:`
   word for word; it is asked on resume.
3. **Reply `HIBERNATED <item>`** and end the turn.

### Resuming from a handoff

A launch prompt ending `— resume from handoff`: the item was preflighted and
claimed at its first launch, so skip § 1–2.

**A named exception to the always-on rule against committing to a branch
another session created**: a resume launch may commit and push to the
handoff's branch, and to no other — the coordinator removed the session
that created it only after `pickup-epic` § Removing a worker's session's
check passed. Never
`main` or `master`.

1. Read the item and its latest handoff.
2. Enter a worktree as usual. `branch: none` → work on the branch it was
   created on. Otherwise put it on the handoff's branch — the PR, if any,
   stays on it:

   ```bash
   git fetch origin && git switch <branch>
   [ "$(git rev-parse --abbrev-ref HEAD)" = "<branch>" ] \
     && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/<branch>)" ] && echo "on pushed head"
   git branch -D <the branch the worktree was created on>
   ```

   No `on pushed head` → stop and ask.
3. A `question:` → `NEEDS_INPUT`, then ask each with the question tool.
4. Continue from `next`, in the stage `phase` names.
