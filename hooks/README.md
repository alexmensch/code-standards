# Review design reminder hook

A Claude Code hook. A review runs over many turns, but `code-craft` is loaded
once, at its start. Every later turn that proposes a fix, a test or an
alternative is a design decision made against a skill that is by then far back
in the context. Once a review starts, this hook adds one line to every later
prompt in that session: apply `code-craft` § Design pass, and state the owner
and what enforces each proposed change.

It is a pointer, not a reload: the skill is already in context, and invoking
it again would append another full copy every turn. The line says to load it
only if it is gone, which is the case after context compaction.

## Files

```
review-design-reminder.sh   the hook; skill names in REVIEW_SKILL / DESIGN_SKILL
skill-name.sh               is_skill: matches a skill name under any scope prefix (x, prefix:x)
settings.snippet.json       the two settings.json entries, with a <HOOK_DIR> placeholder
test.sh                     behavioural tests: bash test.sh
```

## How it arms

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

## Disabling

Remove both entries from `settings.json` (one under `PreToolUse`, one under
`UserPromptSubmit`). To silence it for the rest of one session without editing
settings, delete that session's `active-<session_id>` marker.
