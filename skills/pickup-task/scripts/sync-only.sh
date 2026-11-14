#!/usr/bin/env bash
# Answers whether <head> moved from <held> only by clean merges of <main-ref>; prints the first commit that is not one.
# Usage: sync-only.sh <held> <head> <main-ref>. Exit 0 when sync-only, 1 when not, 2 on an unreadable ref.

set -uo pipefail

[ $# -eq 3 ] || { echo "usage: sync-only.sh <held> <head> <main-ref>" >&2; exit 2; }
. "$(dirname "${BASH_SOURCE[0]}")/git-lib.sh"
verify_commits "$@"
held=$1 head=$2 main=$3

is_ancestor "$held" "$head" || { echo "$head does not hold $held"; exit 1; }
commits=$(git rev-list --first-parent --parents "$held..$head") || exit 2

while read -r c p1 p2 rest; do
  [ -n "$c" ] || continue
  [ -n "${p2:-}" ] && [ -z "${rest:-}" ] || { echo "$c is not a two-parent merge"; exit 1; }
  is_ancestor "$p2" "$main" || { echo "$c merges $p2, which $main does not hold"; exit 1; }
  merge_tree "$p1" "$p2" && [ "$t" = "$(git rev-parse "$c^{tree}")" ] \
    || { echo "$c is not the clean merge of its parents"; exit 1; }
done <<< "$commits"
