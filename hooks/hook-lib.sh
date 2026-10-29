#!/usr/bin/env bash
# Sourced by the hooks in this folder: skill-name matching, the skill a payload invokes, the PreToolUse deny reply.

# is_skill <invoked> <name> — true when <invoked> is <name> under any scope.
# A directory-scoped or plugin listing prefixes the invoked name.
is_skill() {
  case "$1" in
    "$2"|*:"$2") return 0 ;;
    *) return 1 ;;
  esac
}

# invoked_skill <payload> — the skill a Skill call names, or a prompt's leading
# slash command (which expands inline, with no Skill call); empty otherwise.
invoked_skill() {
  local prompt command
  if [ "$(jq -r '.tool_name // ""' <<< "$1")" = Skill ]; then
    jq -r '.tool_input.skill // ""' <<< "$1"
    return
  fi
  prompt="$(jq -r '.prompt // ""' <<< "$1")"
  command="${prompt#"${prompt%%[![:space:]]*}"}"
  command="${command%%[[:space:]]*}"
  if [ "${command:0:1}" = / ]; then echo "${command#/}"; fi
}

# deny_pretooluse <reason> — prints the reply that refuses the tool call.
deny_pretooluse() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
}
