# Hooks

Three Claude Code hooks, installed together by `INSTALL.md` § 6.

## Files

```
review-design-reminder.sh   review reminder; skill names in REVIEW_SKILL / DESIGN_SKILL
skill-name.sh               is_skill: matches a skill name under any scope prefix (x, prefix:x)
installed-copy-guard.sh     denies edits to installed copies of this bundle
skill-guard.sh              denies an edit until the skill its file needs is loaded; rules in SKILL_GUARD_RULES
settings.snippet.json       the settings.json entries, with a <HOOK_DIR> placeholder
test.sh                     behavioural tests for all three: bash test.sh
```

## Review design reminder

A review runs over many turns, but `code-craft` is loaded once, at its start.
Every later turn that proposes a fix, a test or an alternative is a design
decision made against a skill that is by then far back in the context. Once a
review starts, this hook adds one line to every later prompt in that session:
apply `code-craft` § Design pass, and state the owner and what enforces each
proposed change.

It is a pointer, not a reload: the skill is already in context, and invoking
it again would append another full copy every turn. The line says to load it
only if it is gone, which is the case after context compaction.

### How it arms

A marker file at
`${TMPDIR:-/tmp}/claude-review-design-reminder/active-<session_id>`, keyed on
the payload's `session_id`, because a prompt hook and a tool hook are not
guaranteed to share a parent process. A review starts two ways, so two routes
set it:

1. **A prompt whose first word is `/pr-review`**, scoped spellings included.
   A slash command expands inline, with no Skill tool call. A mention later in
   the prompt, a longer name, or a path ending in the name does not arm.
2. **A `Skill` tool call naming `pr-review`** (PreToolUse, matcher `Skill`),
   for a review the skill's own description triggered.

Once armed, every prompt in that session carries the line, including the
arming turn. Nothing clears it: fixes after the review are design turns too,
and the marker dies with the session's temp files.

**Fails open.** No `session_id`, no `jq`, an unwritable state folder — each
exits silently, and it never blocks a tool call. A missing reminder costs less
than a broken prompt.

## Installed-copy guard

The bundle repo is the one owner of every installed file. An edit made to an
installed copy drifts from it silently, and the next update has to merge it
back by hand. This hook denies `Edit`, `Write`, `MultiEdit` and `NotebookEdit`
on:

- any file in an installed skill folder (from the marker's `skills=`, renames
  and skips applied),
- any file in this hook folder,
- the rules file, when the edit would change the `code-standards:begin`…`end`
  block (markers count only at the start of a line). Edits elsewhere in that
  file pass, including ones that use a marker line as their anchor.

It also denies a `Bash` command that contains a known write form (a redirect
other than to `/dev/null`, `sed -i`, `perl -i`, `tee`, `cp`, `mv`, `rm`,
`install`, `ln`, `rsync`, `truncate`) and names one of those paths, or the
rules file as a whole — each path-like word, with `~`, `$HOME` and the
payload's `cwd` resolved, goes through the same path check. Commands without a
write form pass, so reads are never blocked; a write tool not on that list
passes too.

The denial names the bundle path and the source repo (the marker's
`source=`), so the agent makes the change there and opens a PR, then syncs
with `UPDATE.md`. It finds the rules file from its own location: the scope
folder two levels up (`~/.claude` or `<repo>/.claude`), then `CLAUDE.md` in
it, or `CLAUDE.md` / `AGENTS.md` beside it.

**Syncing.** `INSTALL.md` and `UPDATE.md` write installed copies, so they hold
the guard open with a `.sync-in-progress` file in this folder, and remove it
when done. The file is not per session: while it is under 15 minutes old,
every session's edits pass. An older one is ignored, so an abandoned sync
re-arms the guard by itself.

**Fails open.** No `jq`, no rules file with a marker, or a payload with no
path — each exits silently.

## Skill guard

A rule in prose — load `cube-css` before touching a stylesheet, `code-craft`
before any code change — is skipped exactly when the edit looks too small to
need it. This hook makes it a gate: an `Edit`, `Write`, `MultiEdit` or
`NotebookEdit` on a file a rule names is denied until that rule's skill has
been invoked in the session.

Rules are one per line in `SKILL_GUARD_RULES` — a skill name, then the file
globs it covers; the first rule whose glob matches the path wins. Defaults:

```
cube-css    *.scss *.css
code-craft  *.ts *.tsx *.js *.mjs *.cjs *.py *.sh *.wgsl *.glsl
```

**How it arms.** A `Skill` call (PreToolUse, matcher `Skill`) naming a rule's
skill, scoped spellings included (`is_skill`), writes
`${TMPDIR:-/tmp}/claude-skill-guard/<skill>-<session_id>`. An edit passes once
that marker exists. The denial names the marker, so a harness that never runs
PreToolUse on `Skill` calls can arm by hand instead of looping on the skill.

**Fails closed.** No `jq`, or a guarded edit whose payload has no
`session_id`, exits 2 with the reason on stderr: an edit made without the
skill is the failure this hook exists to stop. A `Skill` call is never
blocked, and a file no rule names always passes.

## Disabling

Remove the entries from `settings.json`: the reminder has one under
`PreToolUse` (matcher `Skill`) and one under `UserPromptSubmit`; the
installed-copy guard has one under `PreToolUse` (matcher
`Edit|Write|MultiEdit|NotebookEdit|Bash`); the skill guard has one under
`PreToolUse` (matcher `Skill|Edit|Write|MultiEdit|NotebookEdit`). To silence
the reminder for the rest of one session without editing settings, delete
that session's `active-<session_id>` marker.
