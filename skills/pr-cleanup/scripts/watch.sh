#!/usr/bin/env bash
# Watches an armed PR until it merges, or a caller-pinned stack until every member is green; prints what ended it, every member's.
# Usage: watch.sh <main> <N>   |   watch.sh <main> <N>=<pinned head>...   (a stack: every member, bottom first)

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
usage() { echo "usage: watch.sh <main> <N> | watch.sh <main> <N>=<sha>..." >&2; exit 2; }
[ $# -ge 2 ] || usage
main=$1
shift
prs=() pins=()
for a in "$@"; do
  prs+=("${a%%=*}")
  [[ "$a" != *=* ]] || pins+=("${a#*=}")
done
if [ ${#pins[@]} = 0 ]; then [ ${#prs[@]} = 1 ] || usage; else [ ${#pins[@]} = ${#prs[@]} ] || usage; fi
interval=${PR_WATCH_INTERVAL:-30}
passes=${PR_WATCH_PASSES:-0}

pass() {
  local pr=$1 pin=$2 info st merged auto head fails threads pending req got missing
  info=$(gh pr view "$pr" --json state,mergedAt,autoMergeRequest,headRefOid \
    -q '"\(.state)|\(.mergedAt // "")|\(.autoMergeRequest != null)|\(.headRefOid)"' 2>/dev/null || true)
  [ -n "$info" ] || return 0
  IFS='|' read -r st merged auto head <<< "$info"
  case "$st" in
    MERGED) echo "PR $pr MERGED at $merged"; return ;;
    CLOSED) echo "PR $pr CLOSED WITHOUT MERGING — cleanup not run"; return ;;
  esac
  [ -z "$pin" ] || [ "$head" = "$pin" ] || { echo "PR $pr HEAD MOVED: $head, pinned $pin"; return; }
  fails=$(gh pr checks "$pr" --json name,bucket \
    -q '.[] | select(.bucket=="fail" or .bucket=="cancel") | .name' \
    2>/dev/null | tr '\n' ' ' || true)
  [ -z "$fails" ] || { echo "PR $pr CHECKS FAILED/CANCELLED: $fails"; return; }
  threads=$(bash "$HERE/threads.sh" "$pr" 2>/dev/null || true)
  [ -z "$threads" ] || { echo "PR $pr UNRESOLVED REVIEW THREADS:"; echo "$threads"; return; }
  [ -n "$pin" ] || [ "$auto" = "true" ] || { echo "PR $pr auto-merge NOT ARMED"; return; }
  pending=$(gh pr checks "$pr" --json bucket -q '[.[] | select(.bucket=="pending")] | length' 2>/dev/null || true)
  [ "$pending" = 0 ] || return 0
  req=$(gh api "repos/{owner}/{repo}/rules/branches/$main" \
    -q '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context') || return 0
  got=$(gh pr view "$pr" --json statusCheckRollup -q '.statusCheckRollup[]? | (.name // .context)') || return 0
  missing=$(comm -23 <(sed '/^$/d' <<< "$req" | sort -u) <(sed '/^$/d' <<< "$got" | sort -u) | tr '\n' ' ')
  if [ -n "$missing" ]; then echo "PR $pr BLOCKED: required check never reported: $missing"; else echo GREEN; fi
}

n=0
while true; do
  green=0 ended=''
  for i in "${!prs[@]}"; do
    out=$(pass "${prs[$i]}" "${pins[$i]:-}")
    case "$out" in '') ;; GREEN) green=$((green + 1)) ;; *) ended="$ended$out"$'\n' ;; esac
  done
  [ -z "$ended" ] || { printf %s "$ended"; exit 0; }
  [ ${#pins[@]} = 0 ] || [ "$green" != ${#prs[@]} ] || { echo "STACK GREEN"; exit 0; }
  n=$((n + 1))
  [ "$passes" = 0 ] || [ "$n" -lt "$passes" ] || exit 3
  sleep "$interval"
done
