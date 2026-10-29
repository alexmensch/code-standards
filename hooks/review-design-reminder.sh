#!/usr/bin/env bash
# UserPromptSubmit + PreToolUse(Skill) hook: once a review starts in a session, every later prompt carries a
# one-line reminder to run the design pass. Never blocks; fails open. See hooks/README.md.

set -uo pipefail

. "$(dirname "$0")/hook-lib.sh"

REVIEW_SKILL="${REVIEW_SKILL:-pr-review}"
DESIGN_SKILL="${DESIGN_SKILL:-code-craft}"

REMINDER="Review in progress: before proposing any change this turn (fix, test, guard, doc, alternative), apply $DESIGN_SKILL § Design pass and state *owner* and *enforced by* for it. Load $DESIGN_SKILL first if it is no longer in context."

input="$(cat)"
session="$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)"
[ -n "$session" ] || exit 0

STATE_DIR="${TMPDIR:-/tmp}/claude-review-design-reminder"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
MARKER="$STATE_DIR/active-$session"

event="$(printf '%s' "$input" | jq -r '.hook_event_name // ""')"

if is_skill "$(invoked_skill "$input")" "$REVIEW_SKILL"; then : > "$MARKER"; fi
if [ "$event" = UserPromptSubmit ] && [ -f "$MARKER" ]; then
  jq -n --arg ctx "$REMINDER" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi
exit 0
