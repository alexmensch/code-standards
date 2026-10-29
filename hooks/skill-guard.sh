#!/usr/bin/env bash
# PreToolUse guard: denies an edit to a file a rule names until that rule's skill
# has been invoked this session. Fails closed. See hooks/README.md.

set -uo pipefail
# Rule globs must match file paths, never expand against the cwd.
set -f

. "$(dirname "$0")/skill-name.sh"

SKILL_GUARD_RULES="${SKILL_GUARD_RULES:-cube-css *.scss *.css
code-craft *.ts *.tsx *.js *.mjs *.cjs *.py *.sh *.wgsl *.glsl}"

refuse() { echo "skill-guard: $1" >&2; exit 2; }

command -v jq >/dev/null || refuse "jq is not installed, so edits cannot be checked for required skills. Install jq and retry."

input="$(cat)"
tool="$(jq -r '.tool_name // ""' <<< "$input")"
session="$(jq -r '.session_id // ""' <<< "$input")"

STATE_DIR="${TMPDIR:-/tmp}/claude-skill-guard"
mkdir -p "$STATE_DIR"
marker() { echo "$STATE_DIR/$1-$session"; }

if [ "$tool" = Skill ]; then
  [ -n "$session" ] || exit 0
  invoked="$(jq -r '.tool_input.skill // ""' <<< "$input")"
  while read -r skill _; do
    if [ -n "$skill" ] && is_skill "$invoked" "$skill"; then : > "$(marker "$skill")"; fi
  done <<< "$SKILL_GUARD_RULES"
  exit 0
fi

file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<< "$input")"
[ -n "$file" ] || exit 0

required=""
while read -r skill globs; do
  for g in $globs; do
    case "$file" in $g) required="$skill"; break 2 ;; esac
  done
done <<< "$SKILL_GUARD_RULES"
[ -n "$required" ] || exit 0

[ -n "$session" ] || refuse "the payload has no session_id, so the $required skill cannot be confirmed loaded before $tool on $(basename "$file")."

state_file="$(marker "$required")"
[ -f "$state_file" ] && exit 0

jq -n --arg r "Refusing $tool on $(basename "$file") — invoke the $required skill first this session.

Fix: call the Skill tool with skill '$required', then retry the edit.

If you have just done that and this still denies, your harness does not run PreToolUse on Skill calls: arm the session with \`touch $state_file\` and carry on — do not invoke the skill again." \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
