#!/usr/bin/env bash
# Merges <base> into HEAD after each landed pre-merged head, so conflicts a pre-merge resolved stay resolved.
# Usage: sync-base.sh <base> <head>...   heads in landing order. Exit 1 prints the conflicts; any other failure exits 2.

set -euo pipefail

[ $# -ge 2 ] || { echo "usage: sync-base.sh <base> <head>..." >&2; exit 2; }
. "$(dirname "${BASH_SOURCE[0]}")/git-lib.sh"
verify_commits "$@"
base="$1"
shift

merge_or_stop() { merge_tree "$@" || { printf 'conflicts:\n%s\n' "$t"; exit 1; }; }

at=HEAD
for head in "$@"; do
  merge_or_stop "$at" "$head"
  at=$(git commit-tree "$t" -p "$at" -p "$head" -m "Merge $head") || exit 2
done

# <head> is a safe base only for a tree that holds it: on one that does not, the base's squash of it reads as reverted.
merge_or_stop --merge-base="$head" "$at" "$base"

sign=$(git config --bool commit.gpgsign | sed -n 's/^true$/-S/p' || true)
c=$(git commit-tree $sign "$t" -p HEAD -p "$base" -m "Merge $base") || exit 2
git merge --ff-only -q "$c" || exit 2
echo "$c"
