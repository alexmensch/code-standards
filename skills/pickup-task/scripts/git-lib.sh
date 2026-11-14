# Sourced by this folder's scripts: commit checks and merge-tree, each exiting 2 on a git error.

verify_commits() {
  local ref
  for ref in "$@"; do
    git rev-parse -q --verify "$ref^{commit}" >/dev/null || { echo "not a commit: $ref" >&2; exit 2; }
  done
}

is_ancestor() {
  local s=0
  git merge-base --is-ancestor "$1" "$2" || s=$?
  [ "$s" -le 1 ] || exit 2
  return "$s"
}

# Sets t to the merged tree, or to the conflict listing with status 1.
# merge-tree also exits 1 on a name it cannot resolve: callers verify every ref first, so 1 here is a conflict.
merge_tree() {
  local s=0
  t=$(git merge-tree --write-tree "$@") || s=$?
  [ "$s" -le 1 ] || exit 2
  return "$s"
}
