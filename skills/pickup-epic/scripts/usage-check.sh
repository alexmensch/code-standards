#!/usr/bin/env bash
# Classifies the status line's usage snapshot against pickup-epic's usage bands; prints nothing while the band holds.
# Usage: usage-check.sh normal|high [snapshot]   prints HIGH, NORMAL, HIBERNATE <5h|7d> <resets_at>, or UNWATCHED <why>.

set -uo pipefail

band=${1:-}
case "$band" in normal | high) ;; *) echo "usage: usage-check.sh normal|high [snapshot]" >&2; exit 2 ;; esac
f=${2:-$HOME/.claude/usage.json}
[ -r "$f" ] || { echo "UNWATCHED no snapshot at $f"; exit 0; }

jq -r --arg band "$band" --argjson now "$(date +%s)" '
  def window: if type == "object" and (.used_percentage | type) == "number" and (.resets_at | type) == "number"
    then (if .resets_at <= $now then .used_percentage = 0 else . end) else null end;
  (.rate_limits // {}) as $r | ($r.five_hour | window) as $h | ($r.seven_day | window) as $d
  | if $h == null or $d == null then "UNWATCHED no usage figures in the snapshot"
    elif $d.used_percentage >= 98 then "HIBERNATE 7d \($d.resets_at)"
    elif $h.used_percentage >= 95 then "HIBERNATE 5h \($h.resets_at)"
    elif $h.used_percentage > 90 or $d.used_percentage > 95 then (if $band == "normal" then "HIGH" else empty end)
    elif $band == "high" then "NORMAL" else empty end' "$f" 2>/dev/null \
  || echo "UNWATCHED unreadable snapshot at $f"
