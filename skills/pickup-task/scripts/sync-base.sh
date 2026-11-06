#!/usr/bin/env bash
# Merges <main> into HEAD after each landed pre-merged head, so conflicts a pre-merge resolved stay resolved.
# Usage: sync-base.sh <main> <head>...   heads in landing order. Exit 1 prints the conflicts; any other failure exits 2.

set -euo pipefail

[ $# -ge 2 ] || { echo "usage: sync-base.sh <main> <head>..." >&2; exit 2; }
for ref in "$@"; do
  git rev-parse -q --verify "$ref^{commit}" >/dev/null || { echo "not a commit: $ref" >&2; exit 2; }
done
main="$1"
shift

# merge-tree also exits 1 on a name it cannot resolve: every ref is verified above, so 1 here is a conflict.
merge_tree() {
  local s=0
  t=$(git merge-tree --write-tree "$@") || s=$?
  case $s in
    0) ;;
    1) printf 'conflicts:\n%s\n' "$t"; exit 1 ;;
    *) exit 2 ;;
  esac
}

at=HEAD
for head in "$@"; do
  merge_tree "$at" "$head"
  at=$(git commit-tree "$t" -p "$at" -p "$head" -m "Merge $head") || exit 2
done

# <head> is a safe base only for a tree that holds it: on one that does not, main's squash of it reads as reverted.
merge_tree --merge-base="$head" "$at" "$main"

sign=$(git config --bool commit.gpgsign | sed -n 's/^true$/-S/p' || true)
c=$(git commit-tree $sign "$t" -p HEAD -p "$main" -m "Merge $main") || exit 2
git merge --ff-only -q "$c" || exit 2
echo "$c"
