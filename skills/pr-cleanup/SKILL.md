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

For **the PR named at invocation**, and nothing else:

- **Merge it.** Squash only.
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

Collect the tickets: their IDs appear in the PR title, body and commit
subjects, in the pattern the project's tracker uses. Gather all three and
de-duplicate:

```bash
gh pr view <N> --json title,body,commits -q '.title, .body, (.commits[].messageHeadline)'
```

Read each ticket rather than trusting the ID: a PR sometimes *mentions* a
ticket it does not close.

## Bring main in — always check, even when nothing suggests it

```bash
git status --porcelain                       # must be empty — merge refuses a dirty tree
git rev-list --count HEAD..origin/<main>     # 0 → current; skip to the signature trap
git merge --no-edit origin/<main>
```

Merge, never rebase. The squash lands one commit titled by the PR, so the
branch's own history never reaches `<main>`, and a merge resolves each
conflict once against `<main>`'s tip where a rebase replays it per commit.

Re-run the project's gates after the merge, then:

```bash
git push origin <headRefName>
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
git log --format='%h %G? %s' origin/<main>..HEAD
```

Only `N` (no signature) and `B` (bad signature) need the re-sign below; any
other letter is a signature git cannot verify locally, and GitHub checks it
on its side. An `N` comes from a plumbing rewrite (`git
commit-tree` ignores `commit.gpgsign`) or from a `-c commit.gpgsign=false`
carried over from somewhere that legitimately passes it, such as a test
suite. Pass no signing flag on a branch that will be merged.

The fix below is a rebase, so it flattens merge commits and replays every
commit, conflicts and all. A branch carrying a merge from `<main>` is a
[deviation](#deviations--stop-and-ask) here, not a re-sign. Otherwise fix,
and verify the fix changed nothing but signatures:

```bash
BEFORE=$(git rev-parse HEAD^{tree})
git rebase -f -S origin/<main>
[ "$BEFORE" = "$(git rev-parse HEAD^{tree})" ] || echo "TREE CHANGED — STOP"
git log --format='%h %G?' origin/<main>..HEAD      # no N or B now
git push --force-with-lease origin <headRefName>
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

Non-null → hand off to the `gh-stack` skill if one is installed, otherwise
stop and ask; the rest of this section assumes a standalone PR.

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

### The watch — only for the `--auto` case

**The script must exit on every terminal state** — a monitor that only matches
success is silent through a failure, and silence looks identical to "still
running". Write it to `${TMPDIR:-/tmp}/pr-watch-<N>.sh` and hand `Monitor` the
plain command `bash <that path>`: the loop needs `$( )`, which some command
guards reject inline, and the PR number in the filename stops two concurrent
landings sharing one watcher.

```bash
PR=<N>
while true; do
  info=$(gh pr view $PR --json state,mergedAt,autoMergeRequest \
    -q '"\(.state)|\(.mergedAt // "")|\(.autoMergeRequest != null)"' 2>/dev/null || true)
  [ -z "$info" ] && { sleep 30; continue; }     # transient API failure, keep going
  IFS='|' read -r st merged auto <<< "$info"
  case "$st" in
    MERGED) echo "PR $PR MERGED at $merged"; break ;;
    CLOSED) echo "PR $PR CLOSED WITHOUT MERGING — cleanup not run"; break ;;
  esac
  fails=$(gh pr checks $PR --json name,bucket \
    -q '.[] | select(.bucket=="fail" or .bucket=="cancel") | .name' \
    2>/dev/null | tr '\n' ' ' || true)
  if [ -n "$fails" ]; then echo "PR $PR CHECKS FAILED/CANCELLED: $fails"; break; fi
  if [ "$auto" != "true" ]; then echo "PR $PR auto-merge NOT ARMED"; break; fi
  sleep 30
done
```

`cancel` is a terminal bucket and is **not** `fail` — a cancelled required
check blocks the merge for good while auto-merge stays armed, so a
`fail`-only filter polls a PR that will never move. `Monitor` with
`persistent: true`. Only `MERGED` continues to
[Close the tickets](#close-the-tickets); every other exit is a
[deviation](#deviations--stop-and-ask).

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
  landing checks pass — each fails on what the squash would not carry:

  ```bash
  git fetch origin
  git -C <wt> status --porcelain                          # empty: nothing uncommitted
  [ "$(git -C <wt> rev-parse HEAD)" = "$(gh pr view <N> --json headRefOid -q .headRefOid)" ] \
    && echo "head matches"                                # nothing committed after the merged head
  git merge-base --is-ancestor "$(gh pr view <N> --json mergeCommit -q .mergeCommit.oid)" \
    origin/<main> && echo "squash on <main>"
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

**Blocked with no failing check.** Two known causes, in the order to check
them: unsigned commits ([The signature trap](#the-signature-trap--check-before-arming-the-merge)),
then an orphaned required-status context — a renamed CI job strands its old
name as a required check forever. Compare required against reported:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/<main>' \
  -q '.[] | select(.type=="required_status_checks")
      | .parameters.required_status_checks[].context' | sort
gh pr view <N> --json statusCheckRollup -q '.statusCheckRollup[]? | (.name // .context)' | sort
```

Report the cause; changing branch rules is the user's call, never yours.

**Anything else off the path:**

- PR is a draft, has requested changes, or unresolved review threads.
- A check failed or was cancelled, or the monitor exited `CLOSED` / not-armed.
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
