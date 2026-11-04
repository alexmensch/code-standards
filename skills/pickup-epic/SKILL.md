---
name: pickup-epic
description: Work through an already-planned epic — or an epic of epics — with several `pickup-task` sessions in parallel, driven from one coordinating session. Keeps a just-in-time queue over the epic's dependency graph, preflights each item right before it starts, keeps sessions off each other's files, lands one PR at a time with the user's approval for each, and replans on every report from a worker; hibernates idle workers before their prompt cache expires, or the whole run into durable state, and resumes it with fresh sessions. Claude Code only. Use for "/pickup-epic <epic>" with or without free text, "work through epic X", "run epic X in parallel", and any plain-language request to wind the run down so it can resume later ("hibernate", "I'm stepping away", "pause for the night"). One item at a time is `pickup-task`.
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
| An item's code, branch, worktree, PR, handoff | its worker |
| Findings and new items filed mid-work | the worker that found them |
| The main checkout, merges, post-landing steps | the coordinator |
| Claims, preflight answers, closing sub-epics, the run state, the coordinator field | the coordinator |

## What invoking this authorises — and only this

For items in the tree under the named epic, and items the user brings into
the run: file an item under the named epic for such work that has none
(§ 5), claim them, write the user's preflight answers into them, launch
workers, stop and remove a worker's session (§ Removing a worker's session),
send the coordinator's message kinds,
close a sub-epic once all its children are closed. Each merge still needs the
user's answer for that PR (§ 7).

Never: merge without that answer, edit code, write in a worker's worktree,
answer a question a worker put to the user (§ 6 `QUESTION`), close the
named epic without asking, remove a session before its checks pass, or stop
or remove the user's own session, its worktree or its branch.

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

- items in the run from outside the tree, and why;
- items whose work is in another repo, each with that repo's main checkout,
  until it lands;
- the user's own items: worked interactively in the user's own session,
  each with that session's worktree. Brought into the run and claimed, held
  and given shared resources like any item, never launched; their PRs land
  through § 7 when the user says so;
- holds, each with its reason and what lifts it;
- workers waiting on the user: a `NEEDS_INPUT` with no later `UNBLOCKED`;
- questions this session put to the user and not yet answered — a landing
  approval, a preflight, a `PLAN_CHANGE` — asked again at § Resume;
- landing approvals given and the landing queue;
- pre-merges sent (§ 7 Pre-merge): each later item, the approved PR, and
  the head sent — or `told the user` for one of the user's own items —
  dropped when that item lands, or on `UNMERGED`;
- workers sent `HIBERNATE`, until their session is removed (§ Hand-off);
- hibernated items (§ Hand-off), each with its branch, PR, handoff phase and
  what relaunches it: `resume`, `<X> lands` (met at X's approval, § 1), or
  for one hibernated idle the event § Watchers names. Idle ones are marked
  `idle` and keep their slot under the cap;
- the mark `HIBERNATED` while the whole run is hibernated (§ Hibernate);
- a landing in progress, and its step;
- the last commit main's post-landing step ran on.

Anything only this conversation knows is lost at a resume and may be lost at
a compaction. Write it here first.

## The coordinator field

This session's name — the one workers and every other session message — lives in its own field on the named epic, never in
the run state, so there is one copy to keep current. Set it at kickoff and on
resume. **Ending the run** — at § 8, at § Hibernate, and when the user tells
this session to stop or abandon the run — is one step before the final
message: stop both watchers and delete the idle watcher's watch file
(§ Watchers), then clear the field.

A coordinator killed mid-run cannot clear it, so the field may outlive its
session: a reader never trusts it alone. A session outside the run finds a
live coordinator by listing epics with the field set and confirming the name
in `ListAgents` on a row that is busy, idle or waiting — a stopped session
stays listed as `offline`. A name missing or offline means no coordinator.
The tracker skill maps all three operations.

## 1. Read the state

- **The run state**, first, then **the coordinator field**.
- **The tree** under the epic, at every depth: status, type, parent and open
  blockers, from the tracker's list view. Parentage comes from the tracker's
  parent field, never from the shape of an ID. Epics are containers and never
  launch. Read an item in full only at its preflight (§ 3). **A blocker whose
  PR the user has approved (§ 7.1) and that has not landed counts as
  satisfied** everywhere this skill ranks, fills or relaunches: its content
  is final, and § Pre-merge carries it into the dependent's branch.
- **Open PRs** naming an item in the tree or the run:
  `gh pr list --state open --json number,title,headRefName,body`. Also
  **merged PRs whose items are still open or whose worker still runs**: a
  landing cut off mid-way — finish it with § 7.3's brief, whose `pr-cleanup`
  takes the already-merged route.
- **Workers**: `claude agents --json`, named `pickup-<item>`; each one listed
  is a **live worker**.

An item in progress with no worker, no PR and no place on the hibernated or
the user's-own list → ask the user whether it is another session's work or should be released.

## 2. Rank

Among items with no open blocker (§ 1 says which count as satisfied):

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
  until that worker lands, or ask whether to bundle it into that PR. Overlap
  with an approved, unlanded PR holds nothing: § 5 pre-merges it.
- **Outside blocker** — it waits on an item outside the tree → say so once,
  and ask whether to bring that item in.

Ask only decisions the item **leaves open in writing**. Never recommend an
option you have not checked against the code it touches. A proposed
dependency is a recommendation too: read both items in full before putting
it to the user — through a subagent when there are many. A decision that
only appears once the code is read belongs to the worker, who asks the user
directly. Ask with the question tool, batched across the items about to
launch, each question standing alone in the shape of `pickup-task` § Asking
about a finding. **Write each answer into the item's notes before launching
it**: the worker treats notes as written down and does not re-ask.

## Lanes

One command, run from the main checkout, over open PRs, worktrees and
hibernated items' pushed branches, listed from the run state; a worktree or
branch with an open PR is that PR's lane, its local changes included.
With `n` empty it prints every file two lanes share; with `n=<N>` it prints
each other lane that shares a file with PR N, and those files — the lanes
§ Pre-merge picks its recipients from. Either prints nothing when nothing is shared.

```bash
n=<N, or nothing for every shared file>
git fetch -q origin; t=$(mktemp); T=$(printf '\t')
prs=$(gh pr list --state open --json number,headRefName -q '.[] | "\(.number) \(.headRefName)"')
lane() { awk -v b="${1}" -v d="${2}" 'b!="" && $(2)==b {l="#"$(1)} END {print (l=="" ? d : l)}' <<< "$prs"; }
for pr in $(cut -d' ' -f1 <<< "$prs"); do
  gh pr diff "$pr" --name-only | sed "s|^|#$pr$T|"; done > "$t"
git worktree list --porcelain | sed -n 's/^worktree //p' | tail -n +2 | while IFS= read -r wt; do
  l=$(lane "$(git -C "$wt" branch --show-current)" "${wt##*/}")
  { git -C "$wt" diff --no-renames --name-only origin/<main>...; git -C "$wt" diff --no-renames --name-only HEAD
    git -C "$wt" ls-files --others --exclude-standard; } \
    | sed "s|^|$l$T|"; done >> "$t"
for b in <each hibernated item's branch>; do
  git diff --no-renames --name-only "origin/<main>...origin/$b" | sed "s|^|$(lane "$b" "$b")$T|"; done >> "$t"
sort -u -o "$t" "$t"
if [ -z "$n" ]; then
  awk -F"$T" '{c[$(2)]++; who[$(2)]=who[$(2)]" "$(1)} END {for (f in c) if (c[f]>1) print f":"who[f]}' "$t"
else
  awk -F"$T" -v pr="#$n" 'NR==FNR {if ($(1)==pr) mine[$(2)]=1; next}
    $(1)!=pr && ($(2) in mine) {s[$(1)]=s[$(1)]" "$(2)}
    END {for (l in s) print l":"s[l]}' "$t" "$t"
fi
```

A shared file is a hazard to sequence, not a conflict to predict. A lane
the run state lists as holding an unlanded pre-merge shows that PR's files
as its own: take its files from `git diff --no-renames --name-only <the
pre-merged head>...origin/<its branch>` instead.

## 4. Kickoff

Read the state and rank, then show the user: the first items to launch with
their preflight questions, any outside blockers, and the parallel cap
(default 5; the user's attention is the limit). Start on their answer: set
the coordinator field first, unless it names another live session (§ The
coordinator field) — a deviation.

**Compaction.** The run state makes compaction safe at any moment. After a
compaction summary, re-run § 1 before acting on anything, and restart the
watchers (§ Watchers).

## 5. Launch

New worktrees are seeded from the main checkout, so a launch waits only
while the project's post-landing step is running and rewriting what they are
seeded from — never on a landing in progress, and never for main to catch up
with an approved PR. A main checkout one landing behind seeds a worktree
whose seeding detects the stale artifacts; a project extension whose seeding
cannot narrows this. Claim the item and, from the main checkout's root:

```bash
claude --bg -n pickup-<item> --permission-mode <this session's mode> \
  "/pickup-task <item> — coordinated by \"<this session's name>\""
```

Every session this skill launches runs this command — never a freeform
prompt, which gets none of `pickup-task`'s review, triage, messages or
landing flow. Work with no item, such as a change in another repo, gets one
first: file it under the named epic, shovel-ready by `pickup-task` § 2, and
launch it by that ID. An item whose work is in another repo launches from
that repo's main checkout with ` — tracker in <this repo's main checkout>`
appended to its prompt; every git and `gh` step for it — lanes, review
check, landing — runs from that checkout, and the project's post-landing
step does not apply to it.

A hibernated item (§ Hand-off) keeps its claim and was preflighted at its
first launch: relaunch it with ` — resume from handoff` appended to that
prompt, and check only its lane, from its pushed branch.

Right after any launch, send the worker `PREMERGE` for each approved,
unlanded PR it waits on or shares a file with (§ 7 Pre-merge), so it starts
on the approved content.

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
| `NEEDS_INPUT` | tell the user only that `pickup-<item>` needs them — never a summary of its question, which they read in the worker's session. Add context only when it is cross-worker: lanes, order, another worker's state. Record "waiting on the user"; hold launches that would overlap it |
| `UNBLOCKED` | clear that worker's "waiting on the user" |
| `QUESTION` | answer what the run's state answers (lanes, who owns what, order) by `SendMessage`; anything else → tell the worker to ask the user, even when a written rule seems to settle it |
| `NOTE` | read; act only if it changes the run state |
| `FILED` | the new items are in the tree; rank them with the rest. The worker's item now waits on one → the park row below |
| `PLAN_CHANGE` | hold every item downstream of the affected ones, and their lane-mates, anywhere in the tree; tell the user; launch none until the user settles it and it is written into the items |
| `READY_TO_LAND` | ask the user now (§ 7.1); on approval, pre-merge in the same step (§ 7 Pre-merge); queue it |
| A report that the item now waits on another item, X, to land | X's PR approved and unlanded → § Pre-merge sends it X's head instead. Otherwise park it: § Hand-off with `HIBERNATE <item> — parked on <X>` |
| `ABANDONED` | § Hand-off with `RELEASED <item>`; tell the user, naming any PR it left open |
| `HIBERNATED` | § Hand-off, steps 2–3 |
| Idle notice with no report | ask the user to look at that worker |
| A watcher exits printing | § Watchers |

Report to the user only what changes what they do next: a question, a
landing to approve, a hold, a deviation, a free slot left empty. Never
restate a worker's report.

**Then fill free slots — never silently.** A slot is free while live workers
and idle-hibernated items number fewer than the cap. Fill it: first
hibernated items whose relaunch event has happened, then rank, preflight,
launch. A slot still free with nothing launching → tell the user each
candidate and why it cannot start: blocked by X, an open decision, a lane
hold, parked on X. Nothing in the tree launchable → also propose the items
outside it that would unblock it, for the user to bring in. Every slot held
by an idle-hibernated item → name each and what relaunches it. That report
is the fill step's result: an event that ends with a slot free or held that
way, no launch and no report has skipped the step —
unless the report would repeat the last one word for word.

## Watchers — idle workers and open questions

Two background shells, each started with `run_in_background` so its exit
re-invokes this session. Each script opens with these lines, `<watcher>`
being `idle` or `remind`:

```bash
p=${TMPDIR:-/tmp}/pickup-epic-<epic>-<watcher>.pid; echo $$ > "$p"
mine() { [ "$(cat "$p" 2>/dev/null)" = "$$" ]; }
trap 'mine && rm -f "$p"' EXIT
```

A watcher exits silently within a minute once its file holds another pid or
none, so starting one retires the one before and removing the file stops
it; every exit frees a file still its own. Only an exit that prints is an
event. `watcher:` printed → tell the user; the watcher cannot see.

At every § 1, match each to its condition — the idle watcher runs while this
run has a live worker; the reminder timer while the run state lists a worker
waiting on the user and the user has written in this session since the last
reminder. Should run with no pid file → start it; should not → remove the
file. After a compaction and at § Resume, start each that should run even
with a pid file: a shell that died leaves one behind.

**Idle watcher.** Hands a worker off at `limit` seconds idle, inside the
prompt cache's one-hour lifetime (§ Hibernate gives the cost). Idle time is
the age of the worker's transcript, which every model call writes — the
user typing in the worker's session included; `claude agents --json`
carries no idle timestamp. It reads a file this session rewrites with every
run-state write: one line per live worker of this run, `<item>`, or `<item>
waiting` while it waits on the user. Left out: the item landing now, a
worker owed a reply to `SYNC`, `PREMERGE`, `UNMERGE` or `CI_FAILED`, one
sent `HIBERNATE`, one already reported with no transcript.

```bash
w=${p%.pid}.watch; limit=3300; missing=' '
while sleep 60; do
  mine || exit 0
  [ -f "$w" ] || { echo "watcher: $w missing"; exit 1; }
  a=$(claude agents --json) || { echo "watcher: claude agents failed"; exit 1; }
  rows=$(jq -r '.[] | select(.status == "idle") | "\(.name // "") \(.sessionId)"' <<< "$a") \
    || { echo "watcher: jq failed"; exit 1; }
  out=''; was=$missing; missing=' '
  while read -r name sid; do
    case "$name" in pickup-*) ;; *) continue ;; esac
    mark=$(awk -v i="${name#pickup-}" '$(1) == i {print ($(2) == "" ? "watch" : $(2))}' "$w")
    case "$mark" in
      waiting) out="$out$name dismissed"$'\n' ;;
      watch)
        f=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -name "$sid.jsonl" -print -quit)
        if [ -z "$f" ]; then
          case "$was" in *" $name "*) out="$out$name no transcript"$'\n' ;; *) missing="$missing$name " ;; esac
        else
          age=$(( $(date +%s) - $(date -r "$f" +%s) ))
          [ "$age" -lt "$limit" ] || out="$out$name idle ${age}s"$'\n'
        fi ;;
    esac
  done <<< "$rows"
  [ -z "$out" ] || { printf %s "$out"; exit 0; }
done
```

The idle watcher never hands off a worker waiting on the user: it reads no
message until its question is settled, and once answered it works on with
the answer. Per line printed:

- `idle` → § Hand-off with `HIBERNATE <item>`.
- `dismissed` — the user dismissed its question, so its turn ended → the
  same, now. No event if it has sent `UNBLOCKED` since.
- `no transcript` (two passes running) → ask the user to look at that worker.

An idle hand-off records what relaunches the item:

| Handoff phase | Relaunched by |
| --- | --- |
| `ready to land` | its landing turn — § 7.2 relaunches it only to sync or fix CI |
| `awaiting owner answer` | the user saying, in this session, that they will answer it |
| anything else | `resume`: the user's word, or § Resume |

**Reminder timer.** Reminds the user every 15 minutes, naming each worker
waiting on the user — a hibernated one whose question was dismissed included
— never its question:

```bash
for i in $(seq 15); do sleep 60; mine || exit 0; done; echo remind
```

Once the fill step launches nothing and idle hand-offs have left no live
worker, with the landing queue empty, no landing in progress and no
shared-resource grant running, § Hibernate runs from its step 3 unasked.

## Removing a worker's session

Stop, check, remove — in that order, so nothing of the worker can still be
changing the worktree once it is checked. From the main checkout, with the
worker's id — the 8-character short id `claude agents --json` prints, never
the full session UUID, which matches no entry — and its worktree (`git
worktree list`):

1. **Stop and check.** Write this to `${TMPDIR:-/tmp}/rm-check-<id>.sh`,
   append the gate's own check — § 7.3's landing checks or § Hand-off's
   pushed check — and run `bash <path>`. Every appended check prints
   nothing when it passes and something when it fails:

   ```bash
   id=<id>; wt=<worktree>
   entry=$(claude agents --json --all | jq -c --arg id "$id" '.[] | select(.id==$id)')
   [ -n "$entry" ] || { echo "session $id not found"; exit 1; }
   pid=$(jq -r '.pid // empty' <<< "$entry")
   claude stop "$id" >/dev/null || { echo "claude stop $id failed"; exit 1; }
   end=$((SECONDS+60))
   while [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$SECONDS" -lt "$end" ]; do sleep 1; done
   out=$( { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "session process $pid still running"
            git -C "$wt" status --porcelain
            lsof +D "$wt" 2>/dev/null; } )
   [ -z "$out" ] || { echo "$out"; exit 1; }
   ```

   The pid is read before the stop because `claude agents` reports it null
   as soon as the stop is accepted, while the process is still exiting.
   `claude stop`'s success message is discarded; its exit status catches a
   failed stop. Exit 0 and empty output: the session's process has exited,
   nothing is uncommitted, and no background shell, task, subagent or other
   process has its working directory or a file open under the worktree.
   Any output →
   stop and ask; the session stays stopped and is never removed. `lsof`
   exits 1 whether or not it finds anything, so its output decides.
2. `claude rm <id>`. It deletes the worktree, git's record of it and the
   local branch. A `kept` reply or a non-zero exit → stop and ask.

## Hand-off — hibernate, park and release

One procedure moves a worker's state into the durable record — its pushed
branch, the handoff note on its item, the run state — and removes its
session. A later worker starts fresh from that record (§ 5).

1. **Trigger**: `HIBERNATE <item>` (§ Hibernate), `HIBERNATE <item> — parked
   on <X>`, or `RELEASED <item>`. The worker runs
   `pickup-task` § Hand off and replies `HIBERNATED <item>`. From the
   message until its session is removed, the worker counts as hibernated
   for everything else this session would send it: § 7.2 waits for the
   removal and takes the hibernated path, and § Pre-merge sends it nothing.
2. **Remove** the session (§ Removing a worker's session). Its gate, with
   the branch the item's latest handoff names:

   ```bash
   [ "$(git -C "$wt" rev-parse HEAD)" = "$(git ls-remote origin "refs/heads/<branch>" | cut -f1)" ] \
     || echo "origin lacks the local head of <branch>"
   ```

   No handoff naming the branch also fails it. A handoff with
   `branch: none` has this gate instead:

   ```bash
   [ "$(git -C "$wt" rev-list --count origin/<main>..HEAD)" = 0 ] \
     || echo "commits not on origin/<main>"
   ```

   The branch stays on origin; for a released item, report it to the user —
   deleting a remote branch is theirs.
3. **Run state**: a hibernated or parked item joins the hibernated list,
   with what relaunches it (§ The run state). A released item does not:
   release its claim now, never earlier — a replan before the old session is
   gone could launch a second worker on it — and it ranks with the rest.

## Hibernate

With many workers running, an owner stepping away leaves sessions whose
prompt caches go cold, and resuming each later reloads its whole transcript
uncached. Hibernating removes every session instead; resume launches fresh
workers that load only their item, handoff and branch. Never resume old
workers with `claude --resume`.

Triggered by any request from the user, in plain words, to wind the run
down so it can resume later — stepping away, pausing for the night,
"hibernate" — said in this session or written as free text after
`/pickup-epic <epic>` here. The intent decides; there is no fixed syntax or
argument order. It also runs unasked once idle hand-offs leave no live
worker (§ Watchers). Only the coordinator hibernates: the request anywhere else
would make a second coordinator (§ Deviations). A wind-down, not an
immediate stop:

1. Launch nothing new. Wait for a landing in progress to finish, and for
   each shared-resource grant a project extension made (a GPU grant runs to
   its end) — never cut one short.
2. Once step 1 is done — never mid-landing or mid-`SYNC` — § Hand-off for
   every live worker not already sent it, with `HIBERNATE <item>`. Each reaches
   its next commit boundary before replying, so replies arrive over minutes.
   A worker recorded "waiting on the user", or `blocked` in `claude agents
   --json`, acts on no message until its question is answered or dismissed:
   tell the user which ones. The user's own items stay listed in the run
   state as they are; hibernate never messages, stops or removes the user's
   session.
3. Once every worker is removed: mark the run state `HIBERNATED`, end the
   run (§ The coordinator field), and say in the final message that this
   coordinator session is finished and safe to delete.

## 7. Land — one at a time

Every landing moves the default branch, and the next PR must sync onto it;
version files and lockfiles conflict between any two PRs that both bump them.

1. **Ask at `READY_TO_LAND`**, not at the head of the queue — the approval is
   then ready when its turn comes. First check the review covers the PR
   head, from the main checkout after `git fetch origin pull/<N>/head`:

   ```bash
   r=<the REVIEWED sha>; h=<the PR's headRefOid>
   git merge-base --is-ancestor "$r" "$h" || echo "$r is not an ancestor of $h"
   git log --first-parent --format=%H "$r..$h"
   ```

   An ancestor line, or a printed sha that no commit listed under
   `REVIEWED:` is a prefix of → tell the worker to run `pickup-task` § 4 and
   § 5 again, and ask nothing yet.

   **Recording the approval is one step**: write it into the run state,
   then run § Pre-merge for that PR before anything else.

   When the report's `SMOKE:` line lists steps, quote them and offer only
   "smoked, land it" and "not yet": never a plain "land it" while a manual
   smoke is owed.
2. **Pre-merged PRs first.** For each PR M the run state lists as
   pre-merged into this lane, `[ "$(gh pr view <M> --json state -q .state)"
   = MERGED ] || echo "#<M> not merged"`. Any output → the lane waits
   behind M in the queue.

   **Sync only if behind.** `git fetch origin`, then `git -C <worktree>
   rev-list --count HEAD..origin/<main>`. Zero → go to step 3. Otherwise
   `SYNC #N` to its worker — `SYNC #N base <head>` when a PR pre-merged
   into it has landed since, with the final head of the one that landed
   last — and wait for `SYNCED #N`. For one of the user's own
   items, tell the user it is behind instead.

   A hibernated item has no worktree: count with `git rev-list --count
   origin/<branch>..origin/<main>`. Zero → step 3. Otherwise relaunch it (§ 5), then `SYNC`. A `CI_FAILED` for it:
   relaunch it, then `CI_FAILED`.
3. **Land through a subagent**, so `pr-cleanup`'s detail stays out of this
   context. Its brief: run `pr-cleanup` for #N from the main checkout; the
   user approved this merge; worker `pickup-<item>` (id from `claude agents
   --json`) owns the worktree — for one of the user's own items, the user's
   session does; skip the project extension's post-landing
   step (the coordinator runs it after the landing, step 4). In order:
   1. `pr-cleanup` up to § Merge, waiting for the merge in foreground calls
      of at most ten minutes each.
   2. § Close the tickets.
   3. Remove the session: § Removing a worker's session, copied into the
      brief, with § Worktree, branches, main's three landing checks as its
      gate. A failed check → stop and return it.
   4. From the main checkout: `git fetch --prune`, `git pull --ff-only` on
      `<main>`, and `gh repo view --json deleteBranchOnMerge -q
      .deleteBranchOnMerge` — `false` → report the remote branch left
      behind. `claude rm` already deleted the local branch.
   5. Return `merged`, `CI_FAILED <checks>`, the check that failed, or the
      deviation `pr-cleanup` stopped on.

   **Hold.** The brief also gives the subagent its reply to the
   coordinator's `HOLD` and `RESUME`: on `HOLD`, finish the current command,
   then run nothing local — gates, builds, tests, worktree or session removal
   — until `RESUME`; a merge already armed on the host may complete; reply
   with the step it stopped at. A message reaches the subagent only between
   its tool calls, so `HOLD` takes effect up to one call late — one merge
   wait of at most ten minutes. That wait polls the host and is not local
   work. A project extension maps its own pauses onto this.

   A failed or cancelled check → `CI_FAILED #N <checks>` to the worker, and
   the PR goes to the back of the queue, and every lane holding a pre-merge
   of it goes back behind it. A failed removal check → ask the
   user; the session stays stopped.

   One of the user's own items, or a hibernated item: skip sub-step 3. Landing
   never stops or removes the user's session, its worktree or its branch.

   A landing cut off resumes at step 4 when the session is gone from
   `claude agents --json --all` and its worktree is gone — `claude rm` ran;
   otherwise at step 3.
4. **Update the run state**, start the project's post-landing step on the
   new main with `run_in_background`, so its exit re-invokes this session,
   then § 1. Launches wait only while it runs (§ 5); a non-zero exit is a
   deviation.

**Pre-merge.** Once the user approves a PR at step 1, its content is final;
its head moves only by sync merges and `CI_FAILED` fixes. Every other
worker's lane that lands after #N — later in the landing queue or not yet in
it, at any stage from implementing to approved — gets `PREMERGE #N <head>`,
the head from `gh pr view <N> --json headRefOid`, when § Lanes' command with
`n=<N>` lists it or its item waits on #N's item (§ 1). Its worker merges
that head in at its next commit boundary while #N's CI and merge wait run,
so conflict resolution leaves the critical path. #N lands as a squash, which git does not see as the commits the lane
merged, so that lane's later `SYNC` names #N's final head as its base
(step 2), and the earlier resolution stands.

- Skip a lane whose run-state entry already has the head — sent, or `told
  the user` — or that neither shares a file nor waits on #N's item. Skip
  the file-sharing lanes all when #N has no CI or merge wait ahead; a lane
  waiting on #N's item gets it until #N has merged. Each approval costs up
  to (cap − 1) gate runs, again on each head move, plus, per lane launched
  on #N, a rebuild of the seeded artifacts #N's diff makes stale.
- Record each one sent in the run state, and on `PREMERGED #N <head> <merge
  sha>` add the merge commit to that lane's `REVIEWED:` list.
- At every § 1, run this procedure again for each unlanded approved PR, at
  its current `headRefOid`; the skip rule above picks the lanes. That
  catches an approval whose pre-merge was missed, a lane that has started
  sharing a file since, and a head move — whose `PREMERGE #N <new head>` names the
  commits in between. It costs one § Lanes run per such PR per § 1.
- If #N leaves the run unlanded — released (§ Hand-off) — send `UNMERGE #N`
  to each lane holding it, and drop those entries on `UNMERGED #N`. A lane
  whose item waits on #N's item then waits on an unapproved blocker:
  § Hand-off with `HIBERNATE <item> — parked on <#N's item>`.
- A hibernated lane has no worker: send nothing; § 5 sends it on relaunch.
  For one of the user's own items, tell the user instead, and record `told
  the user` for that head.

Run the project's post-landing step without a pipe on its output, or with
`set -o pipefail`: a pipe into `tail` reports `tail`'s exit code, not the
build's.

## 8. Finish

When every item under the epic is closed: close each sub-epic whose children
are all closed, bottom up, and ask before closing the named epic (it may be
standing open on purpose). Report: landed PRs → items · items still open, and
why (held, outside blocker, abandoned) · items filed during the run. Then
end the run (§ The coordinator field).

## Resume

`/pickup-epic <epic>` in a new session, or after `claude --resume`, starts
from § 1 with the run state first — unless its free text asks to wind the
run down, which is § Hibernate's trigger. Then:

- this session's name differs from the coordinator field → if that name is
  another live session, it is a deviation; otherwise `NOTE` every live worker
  with the new name, and set the field to it;
- subscribe to each live worker's idle notice once;
- start the watchers (§ Watchers);
- ask again each question the run state lists as put to the user and
  unanswered;
- a post-landing step may have been cut off → run it before any launch;
- the run state is marked `HIBERNATED` → clear the mark, and relaunch (§ 5)
  each item hibernated with `resume`, and each whose relaunch event
  happened meanwhile, ahead of new items, up to the cap.

## Deviations — stop and ask

- A `[Cross-session delivery notice]` says a message was held or refused.
- The coordinator field names a live session other than this one: two
  coordinators on one epic.
- An item claimed by someone else.
- A `PLAN_CHANGE` that touches an item already landed.
- `pr-cleanup` stops on one of its own deviations.
- A removal check fails (§ Removing a worker's session).
- A post-landing step fails — no launches until the user answers.
