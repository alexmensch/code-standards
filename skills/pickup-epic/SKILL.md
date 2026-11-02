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

**Project extension.** If the available skills include one whose name ends
`-pickup-epic` and that is scoped to this repository, load it now. Workers
load it too. It adds that project's message kinds and shared-resource rules;
it narrows this skill and never replaces it.

Think of the run as a pipeline. The scarce resources are the user's
attention and the workers' wall-clock; every rule below either removes a
stall (a worker idle on the coordinator), detects a hazard (two sessions on
one file or one machine-wide resource), or prepares an answer before it is
on the critical path.

## One writer per thing

| Thing | Sole writer |
| --- | --- |
| An item's code, branch, worktree, PR | its worker |
| Findings and new items filed mid-work | the worker that found them |
| The main checkout, merges, post-landing steps | the coordinator |
| Claims, preflight answers, closing sub-epics, the run state | the coordinator |

## What invoking this authorises — and only this

For items in the tree under the named epic, and items the user brings into
the run: claim them, write the user's preflight answers into them, launch and
stop workers, send the coordinator's message kinds, close a sub-epic once all
its children are closed. Each merge still needs the user's answer for that PR
(§ 7).

Never: merge without that answer, edit code, write in a worker's worktree,
answer a worker's question for the user, close the named epic without
asking, or delete a session (`claude rm`) — the owner deletes finished ones.

## The plan is just-in-time

The epic is a queue re-read at every event, not a schedule fixed at the
start. Items change as work lands: workers file new ones, a finding rewrites
another item's premise, a dependency appears.

- **State lives in the tracker, the PRs, the session list and the run state —
  never only in this conversation.** Every replan re-reads them (§ 1).
- **Preflight an item right before it launches, never earlier.** An answer
  given now for an item five landings away is a guess about what those
  landings change.
- **Lanes are measured, not forecast**, from real diffs as workers push.
  Never predict a merge conflict; report one only when git does.

## The run state — written at every event

One record on the named epic, **replaced** (not appended) after every event
that changes it — the tracker skill maps the operation. It holds what exists
nowhere else:

- this session's name, which workers message;
- items in the run from outside the tree, and why;
- holds, each with its reason and what lifts it;
- landing approvals given and the landing queue;
- promises to parked workers ("UNBLOCKED when X lands");
- a landing in progress, and its step;
- finished workers, stopped and safe for the owner to delete — name, id,
  whether their final message was confirmed, and for an abandoned one its
  worktree path and any PR it left open;
- the last commit main's post-landing step ran on.

Anything only this conversation knows is lost at a resume and may be lost at
a compaction. Write it here first.

## 1. Read the state

- **The run state**, first.
- **The tree** under the epic, at every depth: status, type, parent and open
  blockers, from the tracker's list view. Parentage comes from the tracker's
  parent field, never from the shape of an ID. Epics are containers and never
  launch. Read an item in full only at its preflight (§ 3).
- **Open PRs** naming an item in the tree or the run:
  `gh pr list --state open --json number,title,headRefName,body`. Also
  **merged PRs whose items are still open or whose worker still runs**: a
  landing cut off mid-way — finish it with § 7.3's brief, whose `pr-cleanup`
  takes the already-merged route; the worker still gets `LANDED`.
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

Read the item in full, with its notes and parent chain, then all four:

- **Readiness** — `pickup-task` § 2's four criteria.
- **Unrecorded dependency** — it builds on something an open item delivers
  (a module, a rule, a file it names) with no dependency recorded → propose
  recording it.
- **Lane** — the files it will touch, from its text and the code it names,
  against every running worker's actual changes (§ Lanes). Overlap → hold it
  until that worker lands, or ask whether to bundle it into that PR.
- **Outside blocker** — it waits on an item outside the tree → say so once,
  and ask whether to bring that item in.

Ask only decisions the item **leaves open in writing**. Never recommend an
option you have not checked against the code it touches; a decision that
only appears once the code is read belongs to the worker, who asks the user
directly. Ask with the question tool, batched across the items about to
launch, each question standing alone in the shape of `pickup-task` § Asking
about a finding. **Write each answer into the item's notes before launching
it**: the worker treats notes as written down and does not re-ask.

## Lanes

One command, run from the main checkout, prints every file two open lanes
share — open PRs and worktrees before their PR:

```bash
git fetch -q origin; t=$(mktemp)
for pr in $(gh pr list --state open --json number -q '.[].number'); do
  gh pr diff "$pr" --name-only | sed "s|^|#$pr |"; done > "$t"
for wt in $(git worktree list --porcelain | awk '/^worktree /{print $2}' | tail -n +2); do
  { git -C "$wt" diff --name-only origin/<main>...; git -C "$wt" status --porcelain | awk '{print $2}'; } \
    | sort -u | sed "s|^|${wt##*/} |"; done >> "$t"
awk '{n[$2]++; who[$2]=who[$2]" "$1} END {for (f in n) if (n[f]>1) print f":"who[f]}' "$t"
```

A shared file is a hazard to sequence, not a conflict to predict.

## 4. Kickoff

Read the state and rank, then show the user: the first items to launch with
their preflight questions, any outside blockers, and the parallel cap
(default 3; the user's attention is the limit). Start on their answer.

**Compaction.** The coordinator cannot run `/compact` itself. In the kickoff,
tell the user once to set a window that suits a long run — `/autocompact
300k` in this session, or `--autocompact 300k` when launching it — since the
default sits near the model's full context. The run state makes compaction
safe at any moment. After a compaction summary, re-run § 1 before acting on
anything.

## 5. Launch

Run the project's post-landing step first if main has moved since it last
ran (run state), and wait for it to exit 0: new worktrees are seeded from the
main checkout. Then claim the item and, from the main checkout's root:

```bash
claude --bg -n pickup-<item> --permission-mode <this session's mode> \
  "/pickup-task <item> — coordinated by \"<this session's name>\""
```

`ListAgents` prints this session's name; quote it exactly, since names
contain spaces. A different permission mode holds every message between the
two sessions for approval. Then `SendMessage` to `pickup-<item>` with
`notify_when_idle: true` and no message, once per worker: an idle notice is a
fallback for a worker that stops without reporting, never a status feed, so
never re-subscribe to a busy worker. Message workers by name: `ListAgents`
shows a different ID for a session than `claude agents` does.

The worker enters its own worktree under the always-on rules, so the
project's worktree seeding applies.

## 6. React — replan on every event

On every report, idle notice, landing or user answer: § 1 again, then:

| Event | Coordinator |
| --- | --- |
| `PR_OPEN` | lanes now use that PR's diff |
| `NEEDS_INPUT` | nothing to the user — they read the worker's session. Record "waiting on the user"; hold launches that would overlap it |
| `UNBLOCKED` | clear that worker's "waiting on the user" |
| `QUESTION` | answer what the run's state answers (lanes, who owns what, order) by `SendMessage`; anything that is the user's decision → tell the worker to ask the user |
| `NOTE` | read; act only if it changes the run state |
| `FILED` | the new items are in the tree; rank them with the rest |
| `PLAN_CHANGE` | hold every item downstream of the affected ones, and their lane-mates, anywhere in the tree; tell the user; launch none until the user settles it and it is written into the items |
| `READY_TO_LAND` | ask the user now (§ 7.1); queue it |
| `ABANDONED` | release its claim if still held, send `RELEASED <item>`, then run § 7.3's final-message wait and act on its result as step 3 there does; the worker joins the finished list; tell the user it is safe to delete, naming any PR it left open |
| Idle notice with no report | ask the user to look at that worker |

Report to the user only what changes what they do next: a question, a
landing to approve, a hold, a deviation. Never restate a worker's report.

Then fill free slots up to the cap: rank, preflight, launch.

## 7. Land — one at a time

Every landing moves the default branch, and the next PR must sync onto it;
version files and lockfiles conflict between any two PRs that both bump them.

1. **Ask at `READY_TO_LAND`**, not at the head of the queue — the approval is
   then ready when its turn comes. Record it in the run state. When the
   report's `SMOKE:` line lists steps, quote them and offer only "smoked,
   land it" and "not yet": never a plain "land it" while a manual smoke is
   owed.
2. **Sync only if behind.** `git fetch origin`, then `git -C <worktree>
   rev-list --count HEAD..origin/<main>`. Zero → go to step 3. Otherwise
   `SYNC #N` to its worker; wait for `SYNCED #N`.
3. **Land through a subagent**, so `pr-cleanup`'s detail stays out of this
   context. Its brief: run `pr-cleanup` for #N from the main checkout; the
   user approved this merge; worker `pickup-<item>` (id from `claude agents
   --json`) owns the worktree; skip the project extension's post-landing
   step (the coordinator runs it before the next launch). In order:
   1. `pr-cleanup` up to § Merge, waiting for the merge in foreground calls
      of at most ten minutes each.
   2. § Close the tickets.
   3. `SendMessage` `LANDED #N` to `pickup-<item>`, then run the final-message
      wait below. `confirmed` or `timed out` → `claude stop <id>`; `gone` →
      nothing to stop; `blocked` → the worker is asking the user something:
      leave it running and return that. Never `claude rm`.
   4. § Worktree, branches, main, by the "an earlier session created it"
      route. The worktree already gone is the owner having deleted the
      finished session (`claude rm` deletes its worktree), not
      `pr-cleanup`'s no-worktree deviation: skip to the branches and main.
   5. Return `merged` with the wait's result, `CI_FAILED <checks>`, or the
      deviation `pr-cleanup` stopped on.

   A failed or cancelled check → `CI_FAILED #N <checks>` to the worker, and
   the PR goes to the back of the queue.

   **The final-message wait.** A worker's `state` reads `done` once its last
   turn ended finished, and `working` while it waits after `READY_TO_LAND`.
   Write this to `${TMPDIR:-/tmp}/final-wait-<id>.sh` and run `bash <path>`
   in the foreground:

   ```bash
   ID=<id>; changed=0; end=$((SECONDS+180))
   while [ "$SECONDS" -lt "$end" ]; do
     json=$(claude agents --json) || { sleep 5; continue; }
     s=$(jq -r --arg id "$ID" '.[] | select(.id==$id) | "\(.status) \(.state)"' <<< "$json")
     case "$s" in
       "") echo gone; exit ;;
       *" blocked") echo blocked; exit ;;
       "idle done") [ "$changed" = 1 ] && { echo confirmed; exit; } ;;
       *) changed=1 ;;
     esac
     sleep 5
   done
   echo "timed out"
   ```

   It prints exactly one line; no output means it was killed, and counts as
   `timed out`. `idle done` before any other reading is the state from
   before `LANDED`, so it confirms nothing.
4. **Update the run state** — the worker joins the finished list — and tell
   the user in one line that `pickup-<item>` is safe to delete (on
   `timed out`: to read its last message first). Then § 1.

Run the project's post-landing step without a pipe on its output, or with
`set -o pipefail`: a pipe into `tail` reports `tail`'s exit code, not the
build's.

## 8. Finish

When every item under the epic is closed: close each sub-epic whose children
are all closed, bottom up, and ask before closing the named epic (it may be
standing open on purpose). Report: landed PRs → items · items still open, and
why (held, outside blocker, abandoned) · items filed during the run ·
finished sessions safe to delete, name and id from the run state, flagging
any whose final message timed out.

## Resume

`/pickup-epic <epic>` in a new session, or after `claude --resume`, starts
from § 1 with the run state first. Then:

- this session's name differs from the run state's → `NOTE` every live
  worker with the new name, and record it;
- subscribe to each live worker's idle notice once;
- a post-landing step may have been cut off → run it before any launch.

## Deviations — stop and ask

- A `[Cross-session delivery notice]` says a message was held or refused.
- An item claimed by someone else.
- A `PLAN_CHANGE` that touches an item already landed.
- `pr-cleanup` stops on one of its own deviations.
- A post-landing step fails — no launches until the user answers.
