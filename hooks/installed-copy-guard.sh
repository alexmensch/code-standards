#!/usr/bin/env bash
# PreToolUse guard: denies file-edit tools on an installed copy of this bundle
# and points at the source repo. Fails open.

set -uo pipefail

BEGIN='<!-- code-standards:begin'
END='<!-- code-standards:end -->'

command -v jq >/dev/null || exit 0
input="$(cat)"
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input" 2>/dev/null)"
[ -n "$file" ] || exit 0

hook_dir="$(cd "$(dirname "$0")" && pwd -P)"
scope="$(dirname "$(dirname "$hook_dir")")"

[ -n "$(find "$hook_dir/.sync-in-progress" -mmin -15 2>/dev/null)" ] && exit 0

canon() {
  local p="$1" rest="" link hops=0
  while [ ! -d "$p" ] && [ "$hops" -lt 40 ]; do
    hops=$((hops + 1))
    if [ -L "$p" ]; then
      link="$(readlink "$p")"
      case "$link" in /*) p="$link" ;; *) p="$(dirname "$p")/$link" ;; esac
    else
      rest="/$(basename "$p")$rest"
      p="$(dirname "$p")"
    fi
  done
  echo "$(cd "$p" 2>/dev/null && pwd -P)$rest"
}

rules=""
for f in "$scope/CLAUDE.md" "$scope/../CLAUDE.md" "$scope/../AGENTS.md"; do
  if [ -f "$f" ] && grep -q "^$BEGIN " "$f"; then rules="$(canon "$f")"; break; fi
done
[ -n "$rules" ] || exit 0

marker="$(grep "^$BEGIN " "$rules" | head -1)"
skills="$(sed -n 's/.*skills=\([^ ]*\).*/\1/p' <<< "$marker")"
source="$(sed -n 's/.*source=\(.*\) -->.*/\1/p' <<< "$marker")"

deny() {
  jq -n --arg r "$file is an installed copy of code-standards $1. Make the change in ${source:-the code-standards repo}/$1 on a branch and open a PR there, or propose it to the user; then sync installs with that repo's UPDATE.md." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

target="$(canon "$file")"

case "$target" in "$hook_dir"/*) deny "hooks/${target#"$hook_dir"/}" ;; esac

entries=()
IFS=, read -ra entries <<< "$skills"
for e in ${entries[@]+"${entries[@]}"}; do
  bundle="${e%%:*}"
  installed="$bundle"
  [[ "$e" == *:* ]] && installed="${e#*:}"
  [ "$installed" = "-" ] && continue
  dir="$(canon "$scope/skills/$installed")"
  case "$target" in "$dir"/*) deny "skills/$bundle/${target#"$dir"/}" ;; esac
done

[ "$target" = "$rules" ] || exit 0

jq -e --rawfile f "$rules" --arg b "$BEGIN" --arg e "$END" '
  def block: "\n" + . | split("\n" + $b + " ")[1] // "" | split("\n" + $e)[0];
  (if .tool_name == "Write" then .tool_input.content
   else reduce (.tool_input.edits // [.tool_input])[] as $x ($f;
     if ($x.old_string // "") == "" then . else split($x.old_string) | join($x.new_string // "") end)
   end) as $after
  | ($after | block) != ($f | block)' <<< "$input" >/dev/null 2>&1 && deny "AGENTS.md.fragment"
exit 0
