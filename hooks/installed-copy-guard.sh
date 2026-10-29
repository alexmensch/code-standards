#!/usr/bin/env bash
# PreToolUse guard: denies file-edit tools on an installed copy of this bundle
# and points at the source repo. Fails open.

set -uo pipefail

. "$(dirname "$0")/hook-lib.sh"

BEGIN='<!-- code-standards:begin'
END='<!-- code-standards:end -->'

WRITES='(^|[^0-9&])>|sed[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*-[[:alnum:]]*i|perl[[:space:]]+-[[:alnum:]]*i|(^|[^[:alnum:]_-])(tee|cp|mv|rm|install|ln|rsync|truncate)([[:space:]]|$)'

command -v jq >/dev/null || exit 0
input="$(cat)"
cmd="$(jq -r 'select(.tool_name == "Bash") | .tool_input.command // empty' <<< "$input" 2>/dev/null)"
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input" 2>/dev/null)"
if [ -n "$cmd" ]; then
  sed -E 's#[0-9&]?>+[[:space:]]*/dev/null##g' <<< "$cmd" | grep -qE "$WRITES" || exit 0
elif [ -z "$file" ]; then
  exit 0
fi

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
  local what="$file is" tail=""
  if [ -n "$cmd" ]; then
    what="This shell command writes to"
    [ "$1" = AGENTS.md.fragment ] && tail=" For the rest of the rules file, use the file-edit tools, which judge only the block."
  fi
  deny_pretooluse "$what an installed copy of code-standards $1. Make the change in ${source:-the code-standards repo}/$1 on a branch and open a PR there, or propose it to the user; then sync installs with that repo's UPDATE.md.$tail"
  exit 0
}

guards=("$hook_dir|hooks")
entries=()
IFS=, read -ra entries <<< "$skills"
for e in ${entries[@]+"${entries[@]}"}; do
  bundle="${e%%:*}"
  installed="$bundle"
  [[ "$e" == *:* ]] && installed="${e#*:}"
  [ "$installed" = "-" ] && continue
  guards+=("$(canon "$scope/skills/$installed")|skills/$bundle")
done

deny_guarded() {
  local t="$1" g dir
  for g in "${guards[@]}"; do
    dir="${g%%|*}"
    case "$t" in
      "$dir") deny "${g#*|}" ;;
      "$dir"/*) deny "${g#*|}/${t#"$dir"/}" ;;
    esac
  done
}

if [ -n "$cmd" ]; then
  cwd="$(jq -r '.cwd // empty' <<< "$input")"
  [ -d "$cwd" ] && cd "$cwd"
  while read -r tok; do
    [[ "$tok" == */* ]] || continue
    case "$tok" in "~"/*) tok="$HOME/${tok#"~"/}" ;; "\$HOME"/*) tok="$HOME/${tok#"\$HOME"/}" ;; esac
    t="$(canon "$tok")"
    deny_guarded "$t"
    [ "$t" = "$rules" ] && deny "AGENTS.md.fragment"
  done < <(tr -s " \t;|&<>()\"'" '\n' <<< "$cmd")
  exit 0
fi

target="$(canon "$file")"
deny_guarded "$target"

[ "$target" = "$rules" ] || exit 0

jq -e --rawfile f "$rules" --arg b "$BEGIN" --arg e "$END" '
  def block: "\n" + . | split("\n" + $b + " ")[1] // "" | split("\n" + $e)[0];
  (if .tool_name == "Write" then .tool_input.content
   else reduce (.tool_input.edits // [.tool_input])[] as $x ($f;
     if ($x.old_string // "") == "" then . else split($x.old_string) | join($x.new_string // "") end)
   end) as $after
  | ($after | block) != ($f | block)' <<< "$input" >/dev/null 2>&1 && deny "AGENTS.md.fragment"
exit 0
