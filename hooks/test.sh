#!/usr/bin/env bash
# Behavioural tests for review-design-reminder.sh. Run: bash hooks/test.sh

set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/review-design-reminder.sh"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT
failures=0

run() { TMPDIR="$STATE" bash "$HOOK" <<< "$1"; }

prompt() {
  run "$(jq -n --arg p "$1" --arg s "${2:-s1}" '{hook_event_name: "UserPromptSubmit", session_id: $s, prompt: $p}')" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

skill() {
  run "$(jq -n --arg k "$1" --arg s "${2:-s1}" \
    '{hook_event_name: "PreToolUse", session_id: $s, tool_name: "Skill", tool_input: {skill: $k}}')"
}

check() {
  if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}

reset() { rm -f "$STATE"/claude-review-design-reminder/*; }

check "silent before a review starts" '[ -z "$(prompt "fix the retry loop")" ]'
reset

check "arms on /pr-review, reminds on that turn" '[[ "$(prompt "/pr-review 610 focus on caching")" == *"code-craft § Design pass"* ]]'
check "reminds on every later turn" '[[ "$(prompt "is there a better way than a regex?")" == *"*enforced by*"* ]]'
reset

check "arms behind leading whitespace" '[ -n "$(prompt "
/pr-review 610")" ]'
reset

check "arms on a scoped slash command" '[ -n "$(prompt "/.claude/worktrees/wt:pr-review 610")" ]'
reset

check "no arm on a mention" '[ -z "$(prompt "please run /pr-review later")" ]'
check "no arm on a longer name" '[ -z "$(prompt "/pr-reviewer 12")" ]'
check "no arm without a slash" '[ -z "$(prompt "pr-review 610")" ]'
check "no arm on a path ending in the name" '[ -z "$(prompt "/Users/me/.claude/skills/pr-review is odd")" ]'
reset

check "a Skill call never blocks" '[ -z "$(skill cube-css)" ] && [ -z "$(skill pr-review)" ]'
reset
skill cube-css >/dev/null
check "a Skill call naming another skill does not arm" '[ -z "$(prompt next)" ]'
skill .claude/worktrees/wt:pr-review >/dev/null
check "a scoped Skill call naming the review skill arms" '[ -n "$(prompt next)" ]'
reset

prompt "/pr-review 610" s1 >/dev/null
check "scoped to its session" '[ -z "$(prompt next s2)" ]'
reset

no_session='{"hook_event_name": "UserPromptSubmit", "prompt": "/pr-review 1"}'
check "silent without a session id" '[ -z "$(run "$no_session")" ]'
check "reminder is one line" '[ "$(prompt "/pr-review 1" | wc -l | tr -d " ")" = 1 ]'
reset

check "renamed skills via env" '[[ "$(REVIEW_SKILL=team-review DESIGN_SKILL=team-craft prompt "/team-review 3")" == *"team-craft § Design pass"* ]]'

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
