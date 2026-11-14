# Sourced by this folder's scripts: verify_commits exits 2, naming the first argument that is not a commit.

verify_commits() {
  local ref
  for ref in "$@"; do
    git rev-parse -q --verify "$ref^{commit}" >/dev/null || { echo "not a commit: $ref" >&2; exit 2; }
  done
}
