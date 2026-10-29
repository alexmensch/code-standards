#!/usr/bin/env bash
# Behavioural tests for the hooks in this folder. Run: bash hooks/test.sh

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/review-design-reminder.sh"
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

SCOPE="$STATE/home/.claude"
mkdir -p "$SCOPE/hooks/code-standards" "$SCOPE/skills/pr-review" "$SCOPE/skills/acme-craft" \
  "$SCOPE/skills/pickup" "$SCOPE/skills/other"
cp "$HERE/installed-copy-guard.sh" "$HERE/hook-lib.sh" "$SCOPE/hooks/code-standards/"
GUARD="$SCOPE/hooks/code-standards/installed-copy-guard.sh"
ln -s "$SCOPE/skills" "$STATE/home/linked-skills"
for s in pr-review acme-craft pickup other; do echo "body" > "$SCOPE/skills/$s/SKILL.md"; done
RULES="$SCOPE/CLAUDE.md"
cat > "$RULES" <<'EOF'
# Mine — before
<!-- code-standards:begin version=abc skills=code-craft:acme-craft,pr-review,pickup:- source=/src/code standards -->
## DRY — inside
<!-- code-standards:end -->
# Mine — after
EOF

guard() { bash "$GUARD" <<< "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
edit() { guard "$(jq -n --arg f "$1" --arg o "$2" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: "x"}}')"; }
write() { guard "$(jq -n --arg f "$1" --arg c "$2" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}}')"; }

check "guard denies an installed skill, naming the source" \
  '[[ "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" == *"/src/code standards/skills/pr-review/SKILL.md"* ]]'
check "guard maps a renamed skill to its bundle name" \
  '[[ "$(edit "$SCOPE/skills/acme-craft/SKILL.md" body)" == *"skills/code-craft/SKILL.md"* ]]'
check "guard follows a symlinked path" '[ -n "$(edit "$STATE/home/linked-skills/pr-review/SKILL.md" body)" ]'
check "guard denies a new folder's file through a symlink" \
  '[ -n "$(write "$STATE/home/linked-skills/pr-review/refs/new.md" x)" ]'
check "guard denies a new folder's file through .." '[ -n "$(write "$SCOPE/skills/other/../pr-review/refs/new.md" x)" ]'
ln -s "$SCOPE/skills/pr-review/SKILL.md" "$STATE/home/linked-file.md"
check "guard follows a symlinked file" '[ -n "$(edit "$STATE/home/linked-file.md" body)" ]'
check "guard allows a skipped skill" '[ -z "$(edit "$SCOPE/skills/pickup/SKILL.md" body)" ]'
check "guard allows an unrelated skill" '[ -z "$(edit "$SCOPE/skills/other/SKILL.md" body)" ]'
check "guard denies a new file in the hook folder" \
  '[[ "$(write "$SCOPE/hooks/code-standards/new.sh" x)" == *"hooks/new.sh"* ]]'
check "guard denies an edit inside the rules block" '[[ "$(edit "$RULES" "DRY — inside")" == *"AGENTS.md.fragment"* ]]'
check "guard denies an edit spanning the begin marker" '[ -n "$(edit "$RULES" "before
<!-- code")" ]'
check "guard allows an edit outside the rules block" '[ -z "$(edit "$RULES" "Mine — after")" ]'
check "guard allows an edit anchored on the end marker that keeps it" '[ -z "$(guard "$(jq -n --arg f "$RULES" \
  '"'"'{tool_name: "Edit", tool_input: {file_path: $f, old_string: "<!-- code-standards:end -->",
    new_string: "<!-- code-standards:end -->\n## New rule"}}'"'"')")" ]'
check "guard denies a MultiEdit touching the block" '[ -n "$(guard "$(jq -n --arg f "$RULES" \
  '"'"'{tool_name: "MultiEdit", tool_input: {file_path: $f, edits: [{old_string: "Mine — after"}, {old_string: "inside"}]}}'"'"')")" ]'
check "guard allows a Write leaving the block unchanged" \
  '[ -z "$(write "$RULES" "$(sed "s/Mine — after/Changed/" "$RULES")")" ]'
check "guard denies a Write changing the block" '[ -n "$(write "$RULES" "$(sed "s/inside/changed/" "$RULES")")" ]'
check "guard denies a Write dropping the block" '[ -n "$(write "$RULES" "# Mine")" ]'
touch "$SCOPE/hooks/code-standards/.sync-in-progress"
check "guard stands aside during a sync" '[ -z "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" ]'
touch -t 200001010000 "$SCOPE/hooks/code-standards/.sync-in-progress"
check "guard ignores a stale sync marker" '[ -n "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" ]'

RULES_BODY="$(cat "$RULES")"
set_rules() { printf '%s\n' "$1" > "$RULES"; }
raw_edit() {
  "${2:-bash}" "$GUARD" 2>&1 <<< "$(jq -n --arg f "$1" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: "body"}}')"
}

set_rules '<!-- code-standards:begin version=abc source=/src -->
x
<!-- code-standards:end -->'
check "guard survives a marker with no skills=, on the system bash" \
  '[ -z "$(raw_edit "$SCOPE/skills/other/SKILL.md" /bin/bash)" ]'

set_rules "Prose quoting <!-- code-standards:end --> and <!-- code-standards:begin skills=other -->.
$RULES_BODY"
check "guard ignores marker text in prose for the block" '[ -n "$(edit "$RULES" "DRY — inside")" ]'
check "guard ignores marker text in prose for skills=" '[ -n "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" ]'

set_rules "${RULES_BODY/ source=\/src\/code standards/}"
check "guard names the repo generically without source=" \
  '[[ "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" == *"the code-standards repo/skills/pr-review"* ]]'

set_rules "# No marker here"
check "guard stands aside with no marker" '[ -z "$(edit "$SCOPE/skills/pr-review/SKILL.md" body)" ]'
set_rules "$RULES_BODY"

sh() { guard "$(jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}')"; }
check "guard denies sed -i on an installed skill" \
  '[[ "$(sh "sed -i \"\" s/a/b/ $SCOPE/skills/pr-review/SKILL.md")" == *"skills/pr-review"* ]]'
check "guard denies a redirect into an installed skill" '[ -n "$(sh "echo x > $SCOPE/skills/acme-craft/SKILL.md")" ]'
check "guard denies cp into the hook folder" '[ -n "$(sh "cp a $SCOPE/hooks/code-standards/x.sh")" ]'
check "guard denies a shell write to the rules file" \
  '[[ "$(sh "printf x >> $RULES")" == *"file-edit tools"* ]]'
check "guard matches a \$HOME spelling" \
  '[ -n "$(HOME="$STATE/home" sh "rm \$HOME/.claude/skills/pr-review/SKILL.md")" ]'
check "guard denies removing a whole installed skill folder" \
  '[[ "$(sh "rm -rf $SCOPE/skills/pr-review")" == *"code-standards skills/pr-review."* ]]'
check "guard resolves a relative path against the payload's cwd" '[ -n "$(guard "$(jq -n --arg d "$SCOPE/skills" \
  '"'"'{tool_name: "Bash", cwd: $d, tool_input: {command: "rm pr-review/SKILL.md"}}'"'"')")" ]'
check "guard allows reading an installed skill" '[ -z "$(sh "grep -n x $SCOPE/skills/pr-review/SKILL.md 2>/dev/null")" ]'
check "guard allows discarding output to /dev/null" '[ -z "$(sh "cat $SCOPE/skills/pr-review/SKILL.md >/dev/null")" ]'
check "guard allows writes elsewhere" '[ -z "$(sh "sed -i \"\" s/a/b/ $SCOPE/skills/other/SKILL.md")" ]'

check "guard reads NotebookEdit's path" '[ -n "$(guard "$(jq -n --arg f "$SCOPE/skills/pr-review/n.ipynb" \
  '"'"'{tool_name: "NotebookEdit", tool_input: {notebook_path: $f}}'"'"')")" ]'

SG="$HERE/skill-guard.sh"
SG_RULES='cube-css *.scss *.css
code-craft *.ts *.sh'
sg() { TMPDIR="$STATE" SKILL_GUARD_RULES="$SG_RULES" bash "$SG" <<< "$1"; }
sg_reason() { sg "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
sg_skill() { sg "$(jq -n --arg k "$1" --arg s "${2:-s1}" '{session_id: $s, tool_name: "Skill", tool_input: {skill: $k}}')"; }
sg_edit() {
  sg_reason "$(jq -n --arg f "$1" --arg s "${2:-s1}" --arg t "${3:-Edit}" \
    '{session_id: $s, tool_name: $t, tool_input: {file_path: $f}}')"
}

check "skill guard denies a stylesheet edit before its skill" '[[ "$(sg_edit /r/site.scss)" == *"invoke the cube-css skill"* ]]'
check "skill guard denies a code edit before its skill" '[[ "$(sg_edit /r/a.sh)" == *"code-craft"* ]]'
check "skill guard passes a file no rule names" '[ -z "$(sg_edit /r/README.md)" ]'
check "skill guard denies Write and MultiEdit" '[ -n "$(sg_edit /r/a.css s1 Write)" ] && [ -n "$(sg_edit /r/a.css s1 MultiEdit)" ]'
check "skill guard reads NotebookEdit's path" '[ -n "$(sg_reason "$(jq -n '"'"'{session_id: "s1", tool_name: "NotebookEdit",
  tool_input: {notebook_path: "/r/n.ts"}}'"'"')")" ]'
check "skill guard never blocks a Skill call" '[ -z "$(sg_skill pr-review)" ]'
check "skill guard: another skill does not arm" '[ -n "$(sg_edit /r/a.css)" ]'
sg_skill cube-css >/dev/null
check "skill guard allows the edit once its skill is invoked" '[ -z "$(sg_edit /r/a.css)" ]'
check "skill guard arming is per skill" '[ -n "$(sg_edit /r/a.ts)" ]'
check "skill guard arming is per session" '[ -n "$(sg_edit /r/a.css s2)" ]'
sg_skill .claude/worktrees/wt:code-craft s2 >/dev/null
check "skill guard arms on a scoped name" '[ -z "$(sg_edit /r/a.ts s2)" ]'
sg_skill plugin:code-crafty s3 >/dev/null
check "skill guard does not arm on a longer name" '[ -n "$(sg_edit /r/a.ts s3)" ]'
fallback="$(sg_edit /r/a.css s4 | sed -n 's/.*`touch \([^`]*\)`.*/\1/p')"
touch "$fallback"
check "skill guard honours the fallback marker it names" '[ -n "$fallback" ] && [ -z "$(sg_edit /r/a.css s4)" ]'
no_session='{"tool_name": "Edit", "tool_input": {"file_path": "/r/a.css"}}'
check "skill guard refuses a guarded edit without a session id" 'sg "$no_session" >/dev/null 2>&1; [ $? -eq 2 ]'
no_session_md='{"tool_name": "Edit", "tool_input": {"file_path": "/r/x.md"}}'
check "skill guard passes an unguarded edit without a session id" 'sg "$no_session_md" >/dev/null 2>&1'
sg_prompt() {
  TMPDIR="$STATE" SKILL_GUARD_RULES="$SG_RULES" bash "$SG" prompt <<< \
    "$(jq -n --arg p "$1" --arg s "$2" '{hook_event_name: "UserPromptSubmit", session_id: $s, prompt: $p}')"
}
check "skill guard is silent on a prompt" '[ -z "$(sg_prompt "/cube-css tidy the header" p1)" ]'
check "skill guard arms on a slash command" '[ -z "$(sg_edit /r/a.css p1)" ]'
sg_prompt "/.claude/worktrees/wt:code-craft" p2 >/dev/null
check "skill guard arms on a scoped slash command" '[ -z "$(sg_edit /r/a.ts p2)" ]'
sg_prompt "load /cube-css first" p3 >/dev/null
check "skill guard does not arm on a mid-prompt mention" '[ -n "$(sg_edit /r/a.css p3)" ]'

mkdir -p "$STATE/nojq"
ln -s "$(command -v dirname)" "$STATE/nojq/dirname"
check "skill guard fails closed without jq" \
  'PATH="$STATE/nojq" TMPDIR="$STATE" "$BASH" "$SG" <<< "{}" 2>/dev/null; [ $? -eq 2 ]'
check "skill guard never refuses a prompt without jq" 'PATH="$STATE/nojq" TMPDIR="$STATE" "$BASH" "$SG" prompt <<< "{}"'
default_edit() { TMPDIR="$STATE" bash "$SG" <<< "{\"session_id\": \"d\", \"tool_name\": \"Edit\", \"tool_input\": {\"file_path\": \"$1\"}}"; }
check "skill guard default rules parse" '[ -n "$(default_edit /r/a.scss)$(default_edit /r/a.py)" ]'

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
