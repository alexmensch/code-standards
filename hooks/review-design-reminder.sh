#!/usr/bin/env bash
# UserPromptSubmit + PreToolUse(Skill) hook: once a review starts in a session, every later prompt carries a
# one-line reminder to run the design pass. Never blocks; fails open. See hooks/README.md.

set -uo pipefail

. "$(dirname "$0")/skill-name.sh"

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

case "$event" in
  PreToolUse)
    skill="$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')"
    if is_skill "$skill" "$REVIEW_SKILL"; then : > "$MARKER"; fi
    ;;
  UserPromptSubmit)
    prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
    command="${prompt#"${prompt%%[![:space:]]*}"}"
    command="${command%%[[:space:]]*}"
    if [ "${command:0:1}" = / ] && is_skill "${command#/}" "$REVIEW_SKILL"; then
      : > "$MARKER"
    fi
    if [ -f "$MARKER" ]; then
      jq -n --arg ctx "$REMINDER" \
        '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
    fi
    ;;
esac
exit 0
