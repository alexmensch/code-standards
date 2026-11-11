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

# gh pr checks' buckets, computed from the rollup gh pr view returns.
view='def state: if .__typename == "StatusContext" then .state
    elif .status == "COMPLETED" then .conclusion else .status end;
  def bucket: state as $s
    | if $s == "SUCCESS" then "pass" elif $s == "SKIPPED" or $s == "NEUTRAL" then "skipping"
      elif $s == "CANCELLED" then "cancel"
      elif $s == "ERROR" or $s == "FAILURE" or $s == "TIMED_OUT" or $s == "ACTION_REQUIRED" then "fail"
      else "pending" end;
  (.statusCheckRollup // []) as $r
  | "\(.state)|\(.mergedAt // "")|\(.autoMergeRequest != null)|\(.headRefOid)|\([$r[] | select(bucket == "pending")] | length)",
    ([$r[] | select(bucket == "fail" or bucket == "cancel") | .name // .context] | join(" ")),
    ($r[] | .name // .context)'

pass() {
  local pr=$1 pin=$2 v st merged auto head pending fails threads missing
  v=$(gh pr view "$pr" --json state,mergedAt,autoMergeRequest,headRefOid,statusCheckRollup 2>/dev/null \
    | jq -r "$view" 2>/dev/null) || return 0
  [ -n "$v" ] || return 0
  IFS='|' read -r st merged auto head pending <<< "${v%%$'\n'*}"
  case "$st" in
    MERGED) echo "PR $pr MERGED at $merged"; return ;;
    CLOSED) echo "PR $pr CLOSED WITHOUT MERGING — cleanup not run"; return ;;
  esac
  [ -z "$pin" ] || [ "$head" = "$pin" ] || { echo "PR $pr HEAD MOVED: $head, pinned $pin"; return; }
  fails=$(sed -n 2p <<< "$v")
  [ -z "$fails" ] || { echo "PR $pr CHECKS FAILED/CANCELLED: $fails"; return; }
  threads=$(bash "$HERE/threads.sh" "$pr" 2>/dev/null) || return 0
  [ -z "$threads" ] || { echo "PR $pr UNRESOLVED REVIEW THREADS:"; echo "$threads"; return; }
  [ -n "$pin" ] || [ "$auto" = "true" ] || { echo "PR $pr auto-merge NOT ARMED"; return; }
  [ "$pending" = 0 ] || return 0
  missing=$(comm -23 <(sed '/^$/d' <<< "$req" | sort -u) <(sed '1,2d;/^$/d' <<< "$v" | sort -u) | tr '\n' ' ')
  if [ -n "$missing" ]; then echo "PR $pr BLOCKED: required check never reported: $missing"; else echo GREEN; fi
}

n=0 have_req=''
while true; do
  [ -n "$have_req" ] || { req=$(gh api "repos/{owner}/{repo}/rules/branches/$main" \
    -q '.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context') \
    && have_req=1; }
  green=0 ended=''
  if [ -n "$have_req" ]; then
    for i in "${!prs[@]}"; do
      out=$(pass "${prs[$i]}" "${pins[$i]:-}")
      case "$out" in '') ;; GREEN) green=$((green + 1)) ;; *) ended="$ended$out"$'\n' ;; esac
    done
  fi
  [ -z "$ended" ] || { printf %s "$ended"; exit 0; }
  [ ${#pins[@]} = 0 ] || [ "$green" != ${#prs[@]} ] || { echo "STACK GREEN"; exit 0; }
  n=$((n + 1))
  [ "$passes" = 0 ] || [ "$n" -lt "$passes" ] || exit 3
  sleep "$interval"
done
