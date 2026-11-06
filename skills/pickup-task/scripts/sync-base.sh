#!/usr/bin/env bash
# Merges <main> into HEAD after each landed pre-merged head, so conflicts a pre-merge resolved stay resolved.
# Usage: sync-base.sh <main> <head>...   heads in landing order. Exit 1 prints the conflicts.

set -euo pipefail

[ $# -ge 2 ] || { echo "usage: sync-base.sh <main> <head>..." >&2; exit 2; }
main="$1"
shift

conflicts() { printf 'conflicts:\n%s\n' "$1"; exit 1; }

at=HEAD
for head in "$@"; do
  t=$(git merge-tree --write-tree "$at" "$head") || conflicts "$t"
  at=$(git commit-tree "$t" -p "$at" -p "$head" -m "Merge $head")
done

# <head> is a safe base only for a tree that holds it: on one that does not, main's squash of it reads as reverted.
t=$(git merge-tree --write-tree --merge-base="$head" "$at" "$main") || conflicts "$t"

sign=$(git config --bool commit.gpgsign | sed -n 's/^true$/-S/p' || true)
c=$(git commit-tree $sign "$t" -p HEAD -p "$main" -m "Merge $main")
git merge --ff-only -q "$c"
echo "$c"
