---
name: pickup-epic
description: Work through an already-planned epic — or an epic of epics — with several `pickup-task` sessions in parallel, driven from one coordinating session. Keeps a just-in-time queue over the epic's dependency graph, preflights each item right before it starts, keeps sessions off each other's files, lands one PR at a time with the user's approval for each, and replans on every report from a worker. Claude Code only. Use for "/pickup-epic <epic>", "work through epic X", "run epic X in parallel". One item at a time is `pickup-task`.
---

# Coordinate an epic

This session is the **coordinator**: it plans, launches, lands and replans,
and never writes code. Each item goes to a **worker** — a background Claude
Code session running `pickup-task` in coordinated mode. That section owns the
message vocabulary both sides use; load `pickup-task` now for it, and the
tracker's skill if one is installed.

## One writer per thing

| Thing | Sole writer |
| --- | --- |
| An item's code, branch, worktree, PR | its worker |
| Findings and new items filed mid-work | the worker that found them |
| The main checkout, merges, post-landing steps | the coordinator |
| Claims, preflight answers, closing sub-epics | the coordinator |

## What invoking this authorises — and only this

For items in the tree under the named epic: claim them, write the user's
preflight answers into them, launch and stop workers, send `SYNC` and
`CI_FAILED`, close a sub-epic once all its children are closed. Each merge
still needs the user's answer for that PR (§ 7).

Never: merge without that answer, edit code, write in a worker's worktree,
answer a worker's question, or close the named epic without asking.

## The plan is just-in-time

The epic is a queue re-read at every event, not a schedule fixed at the
start. Items change as work lands: workers file new ones, a finding rewrites
another item's premise, a dependency appears.

- **State lives in the tracker, the PRs and the session list, never in this
  conversation.** Every replan re-reads all three (§ 1). A restarted
  coordinator — `/pickup-epic <epic>` again — resumes from them.
- **Preflight an item right before it launches, never earlier.** An answer
  given now for an item five landings away is a guess about what those
  landings change.
- **Lanes are a forecast**, predicted from item text and corrected against
  real diffs as workers push.

## 1. Read the state

- **The tree** under the epic, at every depth: each item's status, type,
  parent and open blockers. Parentage comes from the tracker's parent field,
  never from the shape of an ID. Epics are containers and never launch.
- **Open PRs** naming an item in the tree:
  `gh pr list --state open --json number,title,headRefName,body`.
- **Workers**: `claude agents --json`, named `pickup-<item>`.

An item in progress with no worker and no PR → ask the user whether it is
another session's work or should be released.

## 2. Rank

Among items with no open blocker:

1. **Unblocks the most** — open items waiting on it, directly or through
   others. Priority alone often ties across a whole epic.
2. **The epic's stated order**, when its description gives one (phases, a
   session order).
3. Priority, then tree order.

## 3. Preflight — per item, at launch time

All four, against the item, its notes and its parent chain:

- **Readiness** — `pickup-task` § 2's four criteria.
- **Unrecorded dependency** — it builds on something an open item delivers
  (a module, a rule, a file it names) with no dependency recorded → propose
  recording it.
- **Lane** — the files and folders it will touch, from its text and the code
  it names, against each running worker's actual changes:
  `gh pr diff <N> --name-only`, or `git -C <worktree> diff --name-only
  origin/<main>...` before a PR exists. Overlap → hold it until that worker
  lands, or ask whether to bundle it into that PR.
- **Outside blocker** — it waits on an item outside the tree → say so once,
  and ask whether to bring that item in.

Ask with the question tool, batched across the items about to launch, each
question standing alone in the shape of `pickup-task` § Asking about a
finding. **Write each answer into the item's notes before launching it**: the
worker treats notes as written down and does not re-ask.

## 4. Kickoff

Read the state and rank, then show the user: the first items to launch with
their preflight questions, the lanes forecast for the next few, any outside
blockers, and the parallel cap (default 3; the user's attention is the
limit). Start on their answer.

## 5. Launch

Claim the item, then from the main checkout's root:

```bash
claude --bg -n pickup-<item> --permission-mode <this session's mode> \
  "/pickup-task <item> — coordinated by <this session's name>"
```

`ListAgents` prints this session's name. A different permission mode holds
every message between the two sessions for approval. Then `SendMessage` to
`pickup-<item>` with `notify_when_idle: true` and no message, for a one-time
notice when it stops. Message workers by name: `ListAgents` shows a
different ID for a session than `claude agents` does.

The worker enters its own worktree under the always-on rules, so the
project's worktree seeding applies.

## 6. React — replan on every event

On every report, idle notice, landing or user answer: § 1 again, then:

| Event | Coordinator |
| --- | --- |
| `PR_OPEN` | lanes now use that PR's diff |
| `NEEDS_INPUT` | tell the user in one line: `claude attach pickup-<item>`. Hold launches that would overlap it |
| `FILED` | the new items are in the tree; rank them with the rest |
| `PLAN_CHANGE` | hold every item downstream of the affected ones, and their lane-mates, anywhere in the tree; tell the user; launch none until the user settles it and it is written into the items |
| `READY_TO_LAND` | queue it for § 7 |
| `ABANDONED` | stop the worker, release its claim if still held |
| Idle notice with no report | ask the user to look at that worker |

Then fill free slots up to the cap: rank, preflight, launch.

## 7. Land — one at a time

Every landing moves the default branch, and the next PR must sync onto it;
version files and lockfiles conflict between any two PRs that both bump them.

1. **Ask per PR.** Every PR waiting, one question each, batched. An
   unapproved PR keeps waiting.
2. **Sync.** `SYNC #N` to its worker; wait for `SYNCED #N`.
3. **Run `pr-cleanup` for #N** from the main checkout, which finds the branch
   already current. A failed or cancelled check → `CI_FAILED #N <checks>` to
   the worker, and the PR goes to the back of the queue. Before removing the
   worktree, `claude stop <id>`, with the `id` that `claude agents --json`
   lists for `pickup-<item>`; then take `pr-cleanup`'s "an earlier session
   created it" route.
4. **Wait for the post-landing steps** `pr-cleanup` started in the background
   (a project extension's rebuild of seeded artifacts) to exit 0 before the
   next launch: new worktrees are seeded from the main checkout.

## 8. Finish

When every item under the epic is closed: close each sub-epic whose children
are all closed, bottom up, and ask before closing the named epic (it may be
standing open on purpose). Report: landed PRs → items · items still open, and
why (held, outside blocker, abandoned) · items filed during the run.

## Deviations — stop and ask

- A `[Cross-session delivery notice]` says a message was held or refused.
- An item claimed by someone else.
- A `PLAN_CHANGE` that touches an item already landed.
- `pr-cleanup` stops on one of its own deviations.
- A post-landing step fails — no launches until the user answers.
