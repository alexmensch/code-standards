---
name: pr-cleanup
description: Land a pull request and finish every follow-up — merge the default branch into it if behind, check commit signatures, squash-merge it (watching only if checks are still pending), close its tickets, remove its worktree, and fast-forward the local default branch. Use when asked to merge, land, or clean up after a PR ("merge PR 123 and clean up", "land this one", "/pr-cleanup 123").
---

# Landing a PR

Run the steps in order; stop and ask the moment anything leaves the happy
path ([Deviations](#deviations--stop-and-ask)).

**Project extension — check before Ground truth.** If the available skills include
one whose name ends `-pr-cleanup` and that is scoped to the repository being
landed, load it now. It carries that project's gates, ticket tracker and
post-landing steps, and its sections narrow this skill's; it never replaces
them.

`<main>` below is the repository's default branch:
`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

## What this skill authorises — and only this

For **the PR named at invocation**, or the stack a caller pinned, and
nothing else:

- **Merge it**, squash only — or, when the caller armed it, never merge:
  wait for it, and disarm with `--disable-auto` on a failed or cancelled
  check or an unresolved review thread ([Ground truth](#ground-truth-first)).
  A pinned stack: `gh stack merge`, only once the watch prints `STACK GREEN`.
- **Merge `origin/<main>` into its branch and push**
  ([Bring main in](#bring-main-in--always-check-even-when-nothing-suggests-it)).
- **Force-push it, with `--force-with-lease`, only for the re-sign in
  [The signature trap](#the-signature-trap--check-before-arming-the-merge).**
  No other force-push is authorised; neither is `--force`.
- **Close its tickets, remove its worktree, fast-forward local `<main>`.**

Still never: push or commit to `<main>`, merge a PR the user did not name,
merge anything with a failing check, or `git push --delete` a remote branch.

The authorisation is per-invocation. It does not carry to the next PR.

### Invoked with no PR number

Resolve it, do not guess:

```bash
gh pr list --state open --json number,title,headRefName -q '.[] | "#\(.number)  \(.headRefName)  \(.title)"'
```

Take it as **this session's own PR** — the branch this session created, or the
one just discussed — when that is unambiguous, and **say which you picked and
why** so a wrong pick is cheap to correct. Otherwise show the list and ask.

**Never default to a PR another session owns**, however plausible it looks.
Several are usually open at once and the others are someone else's in-flight
work; merging one is not recoverable by an apology.

## Ground truth first

```bash
gh pr view <N> --json number,title,state,headRefName,mergeable,mergeStateStatus,autoMergeRequest,isDraft
git worktree list                      # which worktree holds headRefName
git fetch origin
```

**Check `state` before anything else — it may already be merged.** Auto-merge
can fire between two of your own commands. If `MERGED`, the work left is
[Close the tickets](#close-the-tickets) and
[Worktree, branches, main](#worktree-branches-main) — never
[Merge](#merge--never-sit-on-ci).

**Armed by the caller** — invoked with "auto-merge is armed at `<sha>`": the
caller holds the approval and ran the pre-arm checks. Run
[Review threads](#review-threads--check-before-arming-the-merge), then go
straight to [The watch](#the-watch--only-for-the---auto-case-and-a-pinned-stack), skipping
Bring main in, The signature trap and Merge — the first two would move the
armed head — and once `MERGED`, take the route above. Never re-arm and
never merge; on a failed or cancelled check or an unresolved review thread,
run `gh pr merge <N> --disable-auto` and report it.

**A stack pinned by the caller** — invoked with "a stack lands at pinned
heads `<N>=<sha>`…", bottom first: the caller holds the approval for every
member and ran the pre-merge checks at those heads. Run
[Review threads](#review-threads--check-before-arming-the-merge) for each
member, then [The watch](#the-watch--only-for-the---auto-case-and-a-pinned-stack)
with every member and its pinned head, skipping Bring main in, The
signature trap and Merge. On `STACK GREEN`, and never before, in one
command — `gh stack merge` has no head guard, so `stack-pins.sh` is it, read
as late as it can be:

```bash
bash <this skill's folder>/scripts/stack-pins.sh <N>=<sha>... && gh stack merge <top N> --squash --yes
git fetch -q origin && git log --format='%h %s' -<members> origin/<main>   # one squash per member, top first
```

`stack-pins.sh` prints each difference between the pinned list and the
stack's open members — a moved head, an unpinned member below the top or
any open member above it — and exits non-zero, so nothing merges. Then take
the `MERGED` route above for every member. Any other exit of the watch, or
a difference → merge nothing and report it. The `gh-stack` skill, if installed,
carries the merge's mechanics; its `gh stack` commands that rewrite or push
branches are not authorised here.

Collect the tickets: their IDs appear in the PR title, body and commit
subjects, in the pattern the project's tracker uses. Gather all three and
de-duplicate:

```bash
gh pr view <N> --json title,body,commits -q '.title, .body, (.commits[].messageHeadline)'
```

Read each ticket rather than trusting the ID: a PR sometimes *mentions* a
ticket it does not close.

## Review threads — check before arming the merge

An unresolved review thread blocks the landing, whoever opened it: a person,
or a bot such as code scanning (CodeQL posts as `github-advanced-security`).
Green checks say nothing here — the code-scanning check passes while it
posts alerts, and it posts after its analysis, often after the review. The
code-scanning alerts endpoint filtered to the PR's merge ref has returned an
empty list while an alert's thread stood unresolved, so the thread is the
signal. An outdated thread counts: its lines moved, its point is unanswered.

Run, from inside the repository:

```bash
bash <this skill's folder>/scripts/threads.sh <N>
```

One line per unresolved thread — id, author, file, link — and nothing when
none is open. Any line, or a non-zero exit → [deviation](#deviations--stop-and-ask).
Triaging and resolving a thread is the PR owner's work, never this skill's.

These checks cannot see a thread posted after the arm: auto-merge fires once
the required checks pass, before a late alert or between two watch passes.
Only the host closes that gap, by refusing the merge while a thread is open:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/<main>' \
  -q '.[] | select(.type=="pull_request") | .parameters.required_review_thread_resolution'
```

Anything but `true` — `false`, or nothing when no rule requires pull
requests — → [deviation](#deviations--stop-and-ask): name the race, and that
turning the rule on, with code scanning's analysis a required check so its
threads exist before the merge, is the user's call.

## Bring main in — always check, even when nothing suggests it

`<wt>` is the worktree holding `headRefName` (Ground truth's
`git worktree list`):

```bash
git -C <wt> status --porcelain                     # must be empty — merge refuses a dirty tree
git -C <wt> rev-list --count HEAD..origin/<main>   # 0 → current; skip to the signature trap
git -C <wt> merge --no-edit origin/<main>
```

Merge, never rebase. The squash lands one commit titled by the PR, so the
branch's own history never reaches `<main>`, and a merge resolves each
conflict once against `<main>`'s tip where a rebase replays it per commit.

Re-run the project's gates after the merge, then:

```bash
git -C <wt> push origin <headRefName>
```

## The signature trap — check before arming the merge

When the branch rules require signed commits, an unsigned commit blocks the
merge **with every check green**, which reads exactly like the
orphaned-context failure in [Deviations](#deviations--stop-and-ask) and is a
different cause. Check every PR — first whether the rules require signing,
then the commits:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/<main>' -q '.[] | select(.type=="required_signatures") | .type'
# empty → signing not required; skip to Merge
git log --format='%h %G? %s' origin/<main>..<headRefOid>
```

Only `N` (no signature) and `B` (bad signature) need the re-sign below; any
other letter is a signature git cannot verify locally, and GitHub checks it
on its side. An `N` comes from a plumbing rewrite (`git
commit-tree` ignores `commit.gpgsign`) or from a `-c commit.gpgsign=false`
carried over from somewhere that legitimately passes it, such as a test
suite. Never pass a flag that disables signing (`-c commit.gpgsign=false`,
`--no-gpg-sign`) on a branch that will be merged.

The fix below is a rebase, so it flattens merge commits and replays every
commit, conflicts and all. A branch carrying a merge from `<main>` is a
[deviation](#deviations--stop-and-ask) here, not a re-sign. Otherwise fix,
and verify the fix changed nothing but signatures:

```bash
BEFORE=$(git -C <wt> rev-parse HEAD^{tree})
git -C <wt> rebase -f -S origin/<main>
[ "$BEFORE" = "$(git -C <wt> rev-parse HEAD^{tree})" ] || echo "TREE CHANGED — STOP"
git -C <wt> log --format='%h %G?' origin/<main>..HEAD      # no N or B now
git -C <wt> push --force-with-lease origin <headRefName>
```

Do this **before** arming auto-merge: re-signing rewrites every SHA, so every
check re-runs.

## Merge — never sit on CI

Never wait for green before acting: merge now if `CLEAN`, otherwise arm
auto-merge and let the watch report the outcome. Everything below turns on
`mergeStateStatus` — read it, do not infer it from the checks page.

**First, check stack membership — `gh pr merge` is refused on any PR in a
stack**, whatever its position, including a bottom PR that already targets
`<main>` and reads `CLEAN`. The route is `gh stack merge` (same `--squash`),
which lands the whole chain up to that PR atomically — so it is the *stack*
the user must have named, not just this PR:

```bash
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
  query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) {
    pullRequest(number: <N>) { stack { number size } } } }'   # null => not stacked
```

Non-null → unless invoked with a pinned stack
([Ground truth](#ground-truth-first)), hand off to the `gh-stack` skill if
one is installed, otherwise stop and ask. An error (the host has no `stack` field) → stop and ask. The
rest of this section assumes a standalone PR.

| | |
|---|---|
| `CLEAN` | mergeable, all required checks passed — merge now |
| `BLOCKED` | required checks pending **or** [Deviations](#deviations--stop-and-ask)' blocked-with-no-failing-check |
| `UNSTABLE` | mergeable, but something is failing — a [deviation](#deviations--stop-and-ask), never merge over it |
| `BEHIND` / `DIRTY` | out of date / conflicting — back to [Bring main in](#bring-main-in--always-check-even-when-nothing-suggests-it) |
| `UNKNOWN` | not computed yet — ordinary after a push; re-query, do not act |

**Checks already green** (`CLEAN`) — merge and go straight to
[Close the tickets](#close-the-tickets). The merge is synchronous, so there
is nothing to watch:

```bash
gh pr merge <N> --squash
```

**Checks still pending** — arm auto-merge, then watch, because now there IS
an outcome you do not yet know:

```bash
gh pr merge <N> --squash --auto
```

Never pass `--delete-branch`: the local side fails while the worktree still
holds the branch, and the remote side is the repo's auto-delete setting.

### The watch — only for the `--auto` case and a pinned stack

**The watch exits on every terminal state** — a monitor that only matches
success is silent through a failure, and silence looks identical to "still
running". Hand `Monitor` the plain command, a pinned stack with every
member and its pinned head, bottom first:

```bash
bash <this skill's folder>/scripts/watch.sh <main> <N>
bash <this skill's folder>/scripts/watch.sh <main> <N>=<pinned head>...
```

It prints what ended it — for a stack, every member's: `MERGED`, `STACK
GREEN`, or what stopped it — closed, auto-merge not armed, a moved head, a failed or
cancelled check, an unresolved thread, or a required check that never
reported.

`cancel` is a terminal bucket and is **not** `fail` — a cancelled required
check blocks the merge for good while auto-merge stays armed, so a
`fail`-only filter polls a PR that will never move. Nor does one whose
required check never reports, once nothing is pending: the orphaned context
in [Deviations](#deviations--stop-and-ask).

Auto-merge does not wait for a thread: one posted after the arm — a late
code-scanning alert — merges with the PR unless the branch rules require
conversation resolution, which § Review threads requires; the watch stops it
only when it posts before the merge. `Monitor` with
`persistent: true`. Only `MERGED` — or, for a pinned stack, `STACK GREEN`
and the merge — continues to [Close the tickets](#close-the-tickets); every
other exit is a [deviation](#deviations--stop-and-ask).

## Close the tickets

Only once the PR is actually `MERGED` — whether the watch reported it or
[Ground truth](#ground-truth-first) found it already merged. Close each with
a reason naming the PR, in the project's tracker.

Leave a ticket open when the PR only advanced it. Say which, and why.

**No tickets at all is normal, not a deviation.** A tooling, CI, or docs PR
often has none. Say so and move on.

## Worktree, branches, main

Order matters — you cannot remove the worktree from inside it. **What decides
the route is who OWNS the worktree, not whether the session is pinned.**
`ExitWorktree` removes only what this session's own `EnterWorktree` *created*.

- **This session created it** (`EnterWorktree` with a `name`): `cd` is not
  enough — the working directory is pinned. Use `ExitWorktree` with
  `action: "remove"`.

  **It will refuse after a squash merge** — the squash is a *new* commit, so
  the branch is not an ancestor and the tool reads it as unmerged work. That
  refusal is the last thing between the merge and `discard_changes: true`
  deleting work permanently, so override it only when all three of these
  landing checks pass — each fails on what the squash would not carry, and
  they pass only when together they print nothing:

  ```bash
  git fetch -q origin
  git -C <wt> status --porcelain
  [ "$(git -C <wt> rev-parse HEAD)" = "$(gh pr view <N> --json headRefOid -q .headRefOid)" ] \
    || echo "commits after the merged head"
  git merge-base --is-ancestor "$(gh pr view <N> --json mergeCommit -q .mergeCommit.oid)" \
    origin/<main> || echo "squash not on <main>"
  ```

  Never substitute `git cat-file -e origin/<main>:<path>`: `-e` asks only
  whether the path exists, which it may have before the PR too.

- **An earlier session created it** — the usual case, since the PR's worktree
  often predates this session. Reaching it with `EnterWorktree({path})` does
  **not** confer ownership, so `ExitWorktree` refuses on ownership grounds,
  naming `EnterWorktree({path})` or another session's liveness lock.
  **`discard_changes: true` cannot override that refusal** — it answers the
  unmerged-work check above, a different gate — so do not reach for it here,
  and do not read the refusal as the squash-merge one. Leave with
  `action: "keep"` (plain `cd` if the session never entered), then
  `git worktree remove <path>` from the main checkout.

  Still run the landing checks before removing: `git worktree remove`
  drops the directory whether or not the work landed.

Then, from the main checkout:

```bash
git fetch --prune                  # drops the remote branch, if auto-deleted
git branch -D <headRefName>        # no-op if ExitWorktree took it
git pull --ff-only                 # main checkout, <main> branch
gh repo view --json deleteBranchOnMerge -q .deleteBranchOnMerge
```

`false` → the remote branch remains; report it. Deleting it is the user's
call.

Then run the project's sanity check against what actually landed.

Never remove a worktree the PR did not own.

**`locked` does not mean "hands off".** `EnterWorktree` locks what it creates,
so the PR's own worktree is locked whenever a session is in it. The one to
avoid is locked by *another* session — the tell is `git worktree list` naming
a branch that is not this PR's `headRefName`.

## Deviations — stop and ask

Do not improvise past any of these. Say what you found, what you would do, and
wait.

**Blocked with no failing check.** Four known causes, in the order to check
them: an unresolved review thread, posted after the arm
([Review threads](#review-threads--check-before-arming-the-merge));
unsigned commits ([The signature trap](#the-signature-trap--check-before-arming-the-merge));
an open code-scanning alert at or above a `code_scanning` rule's threshold
(`gh api 'repos/{owner}/{repo}/rules/branches/<main>' -q '.[] |
select(.type=="code_scanning") | .parameters'`; the alert links from its
review thread); then an orphaned required-status context — a renamed CI job
strands its old name as a required check forever. The watch's `required
check never reported` exit names the last; outside a watch, compare the
branch rules' required contexts with the PR's `statusCheckRollup` names, as
`scripts/watch.sh` does.

Report the cause; changing branch rules is the user's call, never yours.

**Anything else off the path:**

- PR is a draft, has requested changes, or has unresolved review threads
  ([Review threads](#review-threads--check-before-arming-the-merge)).
- A check failed or was cancelled, or the monitor exited `CLOSED` / not-armed
  / head moved.
- `mergeStateStatus` is `UNSTABLE` — something is failing even though GitHub
  would let the merge through.
- Merge conflicts the project's extension does not give a rule for.
- Gates fail after the merge — `<main>`'s changes broke the branch; do not
  push.
- Unsigned commits on a branch that carries a merge from `<main>`.
- No worktree holds the branch, or the branch is checked out in the **main
  checkout** (never remove that worktree).
- A ticket ID resolves to work this PR does not actually close, or is already
  closed.
- Local `<main>` has uncommitted changes, or is ahead of origin — do not pull
  over it.

When the user answers, that answer covers that PR only.
