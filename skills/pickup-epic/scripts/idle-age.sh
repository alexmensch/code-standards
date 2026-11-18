#!/usr/bin/env bash
# Seconds since a session's last model call, read from its transcript; prints nothing when it has no transcript or no model call yet.
# Usage: idle-age.sh <session id>

set -uo pipefail

sid=${1:?usage: idle-age.sh <session id>}
f=$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects" -name "$sid.jsonl" -print -quit 2>/dev/null)
[ -n "$f" ] || exit 0

t=$(grep '"type":"assistant"' "$f" | jq -r 'select(.type == "assistant")
  | .timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null | tail -1)
[ -z "$t" ] || echo $(( $(date +%s) - t ))
