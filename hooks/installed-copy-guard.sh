#!/usr/bin/env bash
# PreToolUse guard: denies file-edit tools on an installed copy of this bundle
# and points at the source repo. Fails open.

set -uo pipefail

. "$(dirname "$0")/hook-lib.sh"

BEGIN='<!-- code-standards:begin'
END='<!-- code-standards:end -->'

# writer_operands <writer> <word>... — the paths one write command writes, given the words after it.
writer_operands() {
  local writer="$1" w in_place="" next_is_target="" ops=() takes_target=""
  shift
  case "$writer" in cp | mv | install | ln) takes_target=1 ;; esac
  for w; do
    if [ -n "$next_is_target" ]; then echo "$w"; next_is_target=""; continue; fi
    if [[ "$w" != -* ]]; then
      ops+=("$w")
    elif [[ "$writer" =~ ^(sed|perl)$ && "$w" =~ ^(-[A-Za-z]*i|--in-place) ]]; then
      in_place=1
    elif [ -n "$takes_target" ] && [[ "$w" == --target-directory=* ]]; then
      echo "${w#*=}"
    elif [ -n "$takes_target" ] && [[ "$w" =~ ^(-[A-Za-z]*t|--target-directory)$ ]]; then
      next_is_target=1
    fi
  done
  [ ${#ops[@]} -gt 0 ] || return 0
  case "$writer" in
    sed | perl) [ -z "$in_place" ] || printf '%s\n' "${ops[@]}" ;;
    tee | rm | truncate | mv) printf '%s\n' "${ops[@]}" ;;
    cp | install | ln | rsync) echo "${ops[${#ops[@]} - 1]}" ;;
  esac
}

# unquote — stdin with quotes and backslashes removed, and the shell operators they protect dropped.
unquote() {
  awk 'BEGIN { q = "" }
    { out = ""
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (q == "" && c == "\\") { i++; c = substr($0, i, 1); out = out (index("<>|;&()", c) ? "" : c); continue }
        if (q == "" && (c == "\047" || c == "\"")) { q = c; continue }
        if (q != "" && c == q) { q = ""; continue }
        out = out ((q != "" && index("<>|;&()", c)) ? "" : c)
      }
      print out }'
}

write_targets() {
  local seg i w words rest prev
  while IFS= read -r seg; do
    read -ra words <<< "$seg"
    rest=()
    for ((i = 0; i < ${#words[@]}; i++)); do
      if [ "${words[i]}" = ">" ]; then
        i=$((i + 1))
        [ "$i" -lt "${#words[@]}" ] && echo "${words[i]}"
      else
        rest+=("${words[i]}")
      fi
    done
    prev=""
    for ((i = 0; i < ${#rest[@]}; i++)); do
      w="${rest[i]##*/}"
      case "$w" in
        tee | cp | mv | rm | install | ln | rsync | truncate | sed | perl)
          writer_operands "$w" "${rest[@]:i+1}"
          break ;;
        sudo | doas | env | xargs | command | exec | nice | nohup | time | timeout | stdbuf) prev="" ;;
        -* | [0-9]* | [A-Za-z_]*=*) prev="$w" ;;
        *) [[ "$prev" =~ ^-[A-Za-z]$ ]] || break; prev="" ;;
      esac
    done
  done < <(unquote <<< "$1" \
    | sed -E -e 's#[0-9&]?>+[[:space:]]*/dev/null##g' -e 's#[0-9]*>&[0-9-]+##g' -e 's#[0-9]*&?>>?[|&]?# > #g' \
    | tr ';|&()<' '\n\n\n\n\n ')
}

command -v jq >/dev/null || exit 0
input="$(cat)"
cmd="$(jq -r 'select(.tool_name == "Bash") | .tool_input.command // empty' <<< "$input" 2>/dev/null)"
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$input" 2>/dev/null)"
if [ -n "$cmd" ]; then
  targets="$(write_targets "$cmd")"
  [ -n "$targets" ] || exit 0
elif [ -z "$file" ]; then
  exit 0
fi

hook_dir="$(cd "$(dirname "$0")" && pwd -P)"
scope="$(install_scope "$hook_dir")"

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
  done <<< "$targets"
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
