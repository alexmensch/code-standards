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
| `UNRESOLVED` notes (§ 3) | the coordinator at preflight; a worker on `RELEASED`, for its held-back questions |
| The main checkout, merges, post-landing steps | the coordinator |
| Claims, an epic's goals given at preflight, closing sub-epics, the run state, the coordinator field | the coordinator |

## What invoking this authorises — and only this

For items in the tree under the named epic, and items the user brings into
the run: file an item under the named epic for such work that has none
(§ 5), claim them, write preflight's `UNRESOLVED` notes into them, the
dependencies the user approves into the tracker and the goals they give
into an epic (§ 3), launch
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
- **Preflight an item right before it launches, never earlier.** A gap
  noted now for an item five landings away misses what those landings
  change.
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
- workers in a pull wait: a `PULL_WAIT` with no later `PULL_DONE`, each as
  `pulling — <what>, ETA <time>` from its latest `PULL_WAIT` or `PULL_ETA`;
- questions this session put to the user, or held back during a hibernate
  (§ Hibernate), and not yet answered — a landing approval, a preflight, a
  `PLAN_CHANGE`, a deviation — asked at § Resume;
- landing approvals given and the landing queue;
- stacks the user chose (§ Stacks): each one's members bottom first — item,
  PR, branch — and the items the user named to land in it. A restructure
  re-allocates a stack's number, so it is read from any member when needed
  (`gh-stack` § Finding the stack);
- pre-merges sent (§ 7 Pre-merge): each later item, the approved PR, and
  the head sent — or `told the user` for one of the user's own items —
  dropped when that item lands, on `UNMERGED`, or on a `SYNCED` in place
  of `PREMERGED`;
- workers sent `HIBERNATE`, until their session is removed (§ Hand-off);
- hibernated items (§ Hand-off), each with its branch, PR, handoff phase and
  what relaunches it: `resume`, `<X> lands` (met at X's approval, § 1), or
  for one hibernated idle the event § Watchers names. Idle ones are marked
  `idle`; § 6's fill step says which of them hold a slot under the cap;
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
message: stop every watcher and delete the idle watcher's watch file
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
  landing cut off mid-way — finish it through § 7.4, whose `pr-cleanup`
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

Read the item in full, with its notes and parent chain.

**Identify gaps; never resolve them.** The worker reads all the code the
item touches; this session reads the item and a little of it, so an option
it researches or recommends rests on less than the worker will see. Never
research options for an item's content, recommend one, or put its content
decisions to the user. A gap is any of:

- an open decision written in the item;
- a conflict between the item and another item, an epic's goals, or an
  owner decision in force;
- a dependency on what an open item delivers (a module, a rule, a file it
  names) that the tracker does not record, and the user chose not to
  record (below);
- a premise that another item's landing has changed.

Write each gap into the item's notes, one note each, starting `UNRESOLVED`:
the open decision quoted, or what conflicts with what with a pointer to
each side — item IDs, files, the owner decision's text — and no proposed
answer. A gap already in an `UNRESOLVED` note with no later answer is not
noted again. Launch it with
` — UNRESOLVED in notes` (§ 5); the worker investigates each and asks the
user itself.

**Run-level checks** — each needs only the run's state:

- **Readiness** — `pickup-task` § 2's outcome, acceptance and bounded
  criteria. One fails → the item does not launch; § 6's fill step names it.
  An open decision is a gap, not a readiness failure.
- **Unrecorded dependency** — ask whether to record it, naming both items
  and what this one uses from the other, with no recommended option. Read
  both items in full first — through a subagent when there are many.
  Recorded → the item waits on it.
- **Lane** — the files it will touch, from its text and the code it names,
  against every running worker's actual changes (§ Lanes). Overlap → hold it
  until that worker lands, or ask whether to bundle it into that PR. Overlap
  with an approved, unlanded PR holds nothing: § 5 pre-merges it.
- **Outside blocker** — it waits on an item outside the tree → say so once,
  and ask whether to bring that item in.
- **Epic goals** — its parent epic's description states no outcome →
  ask the user for one, once per epic, and write the answer into that
  epic's description: `pr-review` checks every diff against it. A one-line
  outcome, as a holding container has, is enough.

These checks' questions, and which item takes a slot, are the only questions
this session asks at preflight. Ask with the question tool, batched across
the items about to launch, each question standing alone in the shape of
`pickup-task` § Asking about a finding. Record each answer where the run
reads it: a dependency in the tracker, a goal in the epic, the rest in the
run state.

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
pre-merged head>...origin/<its branch>` instead. A stack member's worktree
and branch lines show every member below it as its own the same way: take
them from `origin/<its base branch>...` in place of `origin/<main>...`.

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
step does not apply to it. An item preflight wrote an `UNRESOLVED` note on
gets ` — UNRESOLVED in notes` appended after any ` — tracker in` and
` — stacked on` suffixes (§ Stacks) and before ` — resume from handoff`.

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
| `PULL_WAIT` | record the pull wait |
| `PULL_ETA` | update that worker's ETA in the run state; ignored once `PULL_DONE` has cleared its pull wait |
| `PULL_DONE` | clear the pull wait |
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

**Then fill free slots — never silently.** A live worker or an
idle-hibernated item holds a slot under the cap until its PR is approved
(§ 7.1). From approval until it lands it holds none, whatever it still
owes — a `LANDING_FIX` or a `SYNC` whose conflict goes to the user is its to
finish. Live sessions, and the gate runs a pre-merge starts in each, can therefore
reach the cap plus the live approved lanes. A slot is free while the items
holding one number
fewer than the cap. Fill it: first
hibernated items whose relaunch event has happened, then rank, preflight,
launch. A slot still free with nothing launching → tell the user each
candidate and why it cannot start: blocked by X, not ready (§ 3), a lane
hold, parked on X. Nothing in the tree launchable → also propose the items
outside it that would unblock it, for the user to bring in. Every slot held
by an idle-hibernated item → name each and what relaunches it. That report
is the fill step's result: an event that ends with a slot free or held that
way, no launch and no report has skipped the step —
unless the report would repeat the last one word for word.

## Watchers — idle workers, open questions and pull waits

Three background shells, each started with `run_in_background` so its exit
re-invokes this session. Each script opens with these lines, `<watcher>`
being `idle`, `remind` or `pull`:

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
reminder; the pull timer while it lists a worker in a pull wait. Should run with no pid file → start it; should not → remove the
file. After a compaction and at § Resume, start each that should run even
with a pid file: a shell that died leaves one behind. A pull timer started
that way first sends `PULL_PING` to each worker in a pull wait, since the
restart resets its count while the worker's cache clock runs on.

**Idle watcher.** Hands a worker off at `limit` seconds idle, inside the
prompt cache's one-hour lifetime (§ Hibernate gives the cost). Idle time is
the age of the worker's transcript, which every model call writes — the
user typing in the worker's session included; `claude agents --json`
carries no idle timestamp. It reads a file this session rewrites with every
run-state write: one line per live worker of this run, `<item>`, `<item>
waiting` while it waits on the user, or `<item> pulling` while it is in a
pull wait, even one also waiting on the user — a dismissed question must
not hand off a worker whose command still runs. Left out: the item landing now, a
worker owed a reply to `SYNC`, `PREMERGE`, `UNMERGE` or `LANDING_FIX`, one
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
the answer. Nor one in a pull wait: its `pulling` mark matches no case, so it
is neither timed nor dismissed — a hand-off would stop its command, and the
pull timer keeps it warm instead. Per line printed:

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

**Timers.** The reminder and pull timers are one script, `<minutes>` being
15 for `remind` and, for `pull`, the idle watcher's `limit` in minutes; it
prints its own name:

```bash
for i in $(seq <minutes>); do sleep 60; mine || exit 0; done; echo <watcher>
```

- `remind` → remind the user, naming each worker waiting on the user — a
  hibernated one whose question was dismissed included — never its
  question.
- `pull` → send `PULL_PING <item>` to each worker in a pull wait. Its
  `PULL_ETA` reply, and this exit, keep both sessions' prompt caches inside
  their one-hour lifetime.

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
   append the gate's own check — § 7.4's landing checks or § Hand-off's
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
3. **Run state**: any pull wait of the item is cleared. A hibernated or
   parked item joins the hibernated list, with what relaunches it (§ The
   run state). A released item does not:
   release its claim now, never earlier — a replan before the old session is
   gone could launch a second worker on it — and it ranks with the rest.
   A handoff whose `question:` is not `none` also lists the item as waiting
   on the user, and the user is told that `pickup-<item>`'s handoff holds a
   question — in a whole-run hibernate, in § Hibernate's final message — never
   the question itself.

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
immediate stop.

**No question to the user once it starts** — from the request, or from the
unasked start. The user has stepped away, and a question waiting on them
holds the run open short of step 3. A decision this skill would otherwise
ask, of any kind § The run state lists, goes into the run state as held
back, and § Resume asks it. An approved PR whose landing needs the user — a
deviation, or a question open or held back on its item — stops at a safe
point and is recorded, not asked: its merge disarmed (`gh pr merge <N>
--disable-auto`; a stack's landing subagent sent `HOLD` before its merge),
its worker's session kept, and the run state listing it as stopped at its
step, no longer the landing in progress.

1. Launch nothing new — § 7.2's relaunch of a hibernated lane to sync or
   fix it is part of its landing. Finish landing every PR already approved,
   in queue order (§ 7) — the landing in progress first — and wait for each
   shared-resource grant a project extension made (a GPU grant runs to its
   end); never cut one short. A landing stopped at a safe point leaves the
   rest of the queue to land, except lanes waiting behind it (§ 7.2). Step 1
   is done when every approved PR has landed or stopped that way.
2. Once step 1 is done — never mid-landing or mid-`SYNC` — § Hand-off for
   every live worker not already sent it and not kept at a stopped landing,
   with `HIBERNATE <item>`. Each reaches
   its next commit boundary before replying, so replies arrive over minutes.
   A worker recorded "waiting on the user", or `blocked` in `claude agents
   --json`, acts on no message until its question is answered or dismissed:
   tell the user which ones. The user's own items stay listed in the run
   state as they are; hibernate never messages, stops or removes the user's
   session.
3. Once every worker is removed, or kept at a stopped landing: mark the
   run state `HIBERNATED`, end the
   run (§ The coordinator field), and say in the final message that this
   coordinator session is finished and safe to delete.

## 7. Land — one at a time

Every landing moves the default branch, and the next PR must sync onto it;
version files and lockfiles conflict between any two PRs that both bump them.

1. **Ask at `READY_TO_LAND`**, not at the head of the queue — the approval is
   then ready when its turn comes. First check the review covers the PR
   head, from the main checkout:

   ```bash
   git fetch -q origin pull/<N>/head
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
   smoke is owed. A post-merge check filed as an item (`pickup-task` § 3) is
   not owed before the merge: offer "land it", and name that item.
2. **Pre-merged PRs first.** For each PR M the run state lists as
   pre-merged into this lane, `[ "$(gh pr view <M> --json state -q .state)"
   = MERGED ] || echo "#<M> not merged"`. Any output → the lane waits
   behind M in the queue.

   **Sync only if behind.** `git fetch origin`, then `git -C <worktree>
   rev-list --count HEAD..origin/<main>`. Zero → go to step 3. Otherwise
   `SYNC #N` to its worker — `SYNC #N base <head>...` when a PR pre-merged
   into it has landed since, with every one of the lane's landed pre-merged
   heads (`pickup-task` § Coordinated mode defines them, the lane's head as
   `HEAD`) — and wait for `SYNCED #N`, then add the PR's new `headRefOid`, the
   sync merge, to the lane's `REVIEWED:` list. For one of the user's own
   items, tell the user it is behind instead, and add the sync merge once
   they report it pushed.

   A hibernated item has no worktree: count with `git rev-list --count
   origin/<branch>..origin/<main>`. Zero → step 3. Otherwise relaunch it
   (§ 5), then `SYNC`. A `LANDING_FIX` for it: relaunch it, then
   `LANDING_FIX`.
3. **Arm the merge here, never in the subagent** — this session holds the
   user's approval and the review check. A stack, which cannot be armed,
   pins its heads here instead (§ Stacks). From the main checkout, re-run
   step 1's check with `h` the PR's current `headRefOid`; it fails → as in
   step 1. Then `pr-cleanup` § Review threads' checks — a thread line → arm
   nothing; `LANDING_FIX #N <threads>` as for step 4's failed check; the
   branch rule not `true` → ask the user, as for any deviation. Then its
   § The signature trap's check and § Merge's stack check and
   `mergeStateStatus` table, with this one command in place of its merge,
   for `CLEAN` and `BLOCKED` alike; every other row as the table says,
   except `BEHIND` / `DIRTY` → back to step 2:

   ```bash
   gh pr merge <N> --squash --auto --match-head-commit <h>
   ```

   GitHub merges once the required checks pass, at once if they already
   have; never wait on CI here. Any `pr-cleanup` deviation, the re-sign
   included (it would write the worker's branch), or a refused command →
   ask the user.
4. **Land through a subagent**, so the merge wait and the cleanup stay out
   of this context. Spawn a fresh agent on Sonnet (`model: "sonnet"` on
   the Agent call), never a fork, which ignores `model`. Its brief: run
   `pr-cleanup` for #N from the main checkout; auto-merge is armed at `<h>`;
   worker `pickup-<item>` (its short id from `claude agents --json`) owns
   the worktree — for one of the user's own items, the user's session does;
   never run `gh pr merge` except to disarm; skip the project extension's
   post-landing step (the coordinator runs it after the landing, step 5).
   In order:
   1. `pr-cleanup`'s route for a caller-armed merge, waiting in foreground
      calls of at most ten minutes each.
   2. § Close the tickets.
   3. Remove the session: § Removing a worker's session, copied into the
      brief, with § Worktree, branches, main's three landing checks as its
      gate. A failed check → stop and return it.
   4. From the main checkout: `git fetch --prune`, `git pull --ff-only` on
      `<main>`, and `gh repo view --json deleteBranchOnMerge -q
      .deleteBranchOnMerge` — `false` → report the remote branch left
      behind. `claude rm` already deleted the local branch.
   5. Return `merged`, `LANDING_FIX <failed checks | unresolved threads>`,
      the check that failed, or the deviation `pr-cleanup` stopped on.

   **Hold.** The brief also gives the subagent its reply to the
   coordinator's `HOLD` and `RESUME`: on `HOLD`, finish the current command,
   then run nothing local — gates, builds, tests, worktree or session removal
   — until `RESUME`; a merge already armed on the host may complete, and a
   stack's `gh stack merge` not yet issued waits for `RESUME`, then for a
   fresh `STACK GREEN` from the watch run again; reply with the step it
   stopped at. A message reaches the subagent only between
   its tool calls, so `HOLD` takes effect up to one call late — one merge
   wait of at most ten minutes. That wait polls the host and is not local
   work. A project extension maps its own pauses onto this.

   A failed or cancelled check, or an unresolved review thread (the subagent
   has disarmed the merge) → `LANDING_FIX #N <them>` to the worker, and
   the PR goes to the back of the queue, and every lane holding a pre-merge
   of it goes back behind it. A failed removal check → ask the
   user; the session stays stopped.

   One of the user's own items, or a hibernated item: skip sub-step 3. Landing
   never stops or removes the user's session, its worktree or its branch.

   A landing cut off resumes at step 5 when the session is gone from
   `claude agents --json --all` and its worktree is gone — `claude rm` ran;
   otherwise at step 4 when the PR is merged or its `autoMergeRequest` is
   set, or a stack's landing subagent is running; otherwise at step 3.
5. **Update the run state**, start the project's post-landing step on the
   new main with `run_in_background`, so its exit re-invokes this session,
   then § 1. Launches wait only while it runs (§ 5); a non-zero exit is a
   deviation.

**Pre-merge.** Once the user approves a PR at step 1, its content is final;
its head moves only by `SYNC` merges, `PREMERGE` merges, `UNMERGE`
reverts and `LANDING_FIX` fixes. Every other worker's lane that lands after
#N — later in the landing queue or not yet in it, at any stage from
implementing to approved — gets `PREMERGE #N <head>`, the head from
`gh pr view <N> --json headRefOid`, when § Lanes' command with `n=<N>`
lists it or its item waits on #N's item (§ 1). Its worker merges that head
in at its next commit boundary while #N's CI and merge wait run, so
conflict resolution leaves the critical path. #N lands as a squash, which
git does not see as the commits the lane merged, so that lane's later
`SYNC` names #N's final head among its landed pre-merged heads (step 2),
and the earlier resolution stands.

A move of #N's head from a lane's held `<old>` is **sync-only** when, after
one `git fetch origin` per § 1,
`bash <pickup-task's folder>/scripts/sync-only.sh <old> <head> origin/<main>`
exits 0: every commit between is a merge of a commit main holds, with the
tree a plain merge of its parents gives — #N's clean `SYNC` merges, and a
fold of a landed pre-merged head only when a plain merge reproduces it. A
`PREMERGE` merge, an `UNMERGE` revert, a `LANDING_FIX` fix, a `SYNC` merge
whose conflicts #N's worker resolved, or a fold over a pre-merge resolved
by hand fails it, and so does any other exit.

- Skip a lane whose run-state entry already has the head — sent, or `told
  the user` — or an earlier one the head moved from by a sync-only move
  (`sync-only.sh` exits 0), or that neither shares a file nor waits on
  #N's item. A member above #N in #N's stack gets `SYNC` instead
  (§ Stacks). Skip the file-sharing lanes all when #N has no CI or merge
  wait ahead; a lane waiting on #N's item gets it until #N has merged. Each
  approval costs up to the cap's count of gate runs, since #N joins the
  back of the queue; each later head move `sync-only.sh` does not pass, up
  to the cap plus the live approved lanes queued behind #N (§ 6 fill step);
  plus, per lane launched on #N, a rebuild of the seeded artifacts #N's
  diff makes stale.
- Record each one sent in the run state, and on `PREMERGED #N <head> <merge
  sha>` add the merge commit to that lane's `REVIEWED:` list. `SYNCED #<lane>
  <new head> (PREMERGE #N)` in its place means #N had landed before the
  worker acted, and it synced instead: add the reply's new head to that
  lane's `REVIEWED:` list and drop the pre-merge entry.
- At every § 1, run this procedure again for each unlanded approved PR, at
  its current `headRefOid`; the skip rule above picks the lanes. That
  catches an approval whose pre-merge was missed, a lane that has started
  sharing a file since, and a head move `sync-only.sh` does not pass — whose
  `PREMERGE #N <new head>` names the commits in between. It costs one
  § Lanes run per such PR per § 1, plus one `sync-only.sh` run per lane
  holding an earlier #N head. A sync-only move sends nothing to a
  lane holding an earlier #N head: a clean merge carries only main's
  changes, which the lane folds in at its own `SYNC`.
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

## Stacks — a dependent chain landed as one

A chain of items lands as a GitHub stack only when the user chooses it; the
run state records the stack and the items they named to land in it. The
`gh-stack` skill carries `gh stack`'s mechanics — load it, or stop and ask
before any stack step when it is not installed. Everything else in this
skill holds, except:

- **Launch.** A member launches with ` — stacked on #<M>` after any
  ` — tracker in` suffix, `#<M>` being the member directly below it — the
  stack's top at launch, or the PR it starts from. The worker builds on #M's
  branch and links its PR above #M (`pickup-task` § Coordinated mode).
- **No pre-merge inside a stack.** A member is built on every member below
  it. In place of `PREMERGE`, § Pre-merge's procedure for an approved
  member #N sends `SYNC #<member>` to each member above it whose branch
  lacks #N's head (`git merge-base --is-ancestor <head> origin/<its
  branch>` fails), bottom up, each once the one below replied `SYNCED` or
  was skipped; each new head joins that member's `REVIEWED:` list. Skip a
  member when `sync-only.sh` passes from its newest #N commit (`git
  merge-base origin/<#N's branch> origin/<its branch>`) to #N's head, with
  `origin/<#N's base branch>` as the main ref, for § Pre-merge's reason.
  Lanes outside the stack get `PREMERGE` as usual.
- **Approval.** Each member is asked at its `READY_TO_LAND` (§ 7.1) and
  held. A stack lands whole: it takes one place in the landing queue once
  the user has named every open member and each is approved, and lands every
  one of them; none lands alone.
- **Landing**, in place of § 7.2–7.4; a § 7 reference to its steps 2, 3
  and 4 means this landing's steps 1, 2 and 3:
  1. § 7.2 for each member, bottom up — its pre-merged PRs first, then
     `SYNC` when behind its base (`git rev-list --count
     origin/<branch>..origin/<base branch>`), waiting for `SYNCED` before
     the member above, since each merges the branch below.
  2. Pin the heads. From the main checkout, for each member at its current
     `headRefOid`: § 7.1's review check, and § 7.3's `pr-cleanup` checks
     with the stack check naming this stack. A failure → as in § 7.3, for
     that member. Then `pr-cleanup`'s `scripts/stack-pins.sh` with every
     member's `<N>=<head>`, bottom first: a difference other than a moved
     head — an open member not named or not approved — is a deviation.
  3. The landing subagent, briefed as § 7.4 with these changes: run
     `pr-cleanup` for "a stack lands at pinned heads `<N>=<sha>`…",
     bottom first, with the heads pinned in step 2; it issues `gh stack
     merge` itself, and only on the watch's `STACK GREEN`; sub-steps 2–3
     run for every member. It returns `merged`, or the watch's exit — a
     moved head → back to step 1; a failed check, a required check never
     reported (`missing checks`: a member linked after it opened has no run
     on its head) or a thread → `LANDING_FIX` to that member's worker, and
     the stack goes to the back of the queue.
  4. § 7.5 once, for the whole stack.

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
- ask each question the run state lists as unanswered, put to the user or
  held back;
- a post-landing step may have been cut off → run it before any launch;
- the run state is marked `HIBERNATED` → clear the mark, and relaunch (§ 5)
  each item hibernated with `resume`, and each whose relaunch event
  happened meanwhile, ahead of new items, while a slot is free (§ 6 fill
  step).

## Deviations — stop and ask

During a hibernate, record one instead (§ Hibernate), and stop the step it
arose in. Two coordinators → stop before step 3, leaving the coordinator
field as it is. A failed post-landing step → step 1 lands nothing further.

- A `[Cross-session delivery notice]` says a message was held or refused.
- The coordinator field names a live session other than this one: two
  coordinators on one epic.
- An item claimed by someone else.
- A `PLAN_CHANGE` that touches an item already landed.
- `pr-cleanup` stops on one of its own deviations.
- A removal check fails (§ Removing a worker's session).
- A post-landing step fails — no launches until the user answers.
