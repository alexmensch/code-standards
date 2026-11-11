#!/usr/bin/env bash
# Prints one line per unresolved review thread on a PR — id, author, file, link — and nothing when none is open.
# Usage: threads.sh <N>   from inside the repository. A non-zero exit means the answer is unknown.

set -euo pipefail

[ $# = 1 ] || { echo "usage: threads.sh <N>" >&2; exit 2; }

gh api graphql --paginate -F owner='{owner}' -F name='{repo}' -F n="$1" -f query='
  query($owner: String!, $name: String!, $n: Int!, $endCursor: String) { repository(owner: $owner, name: $name) {
    pullRequest(number: $n) { reviewThreads(first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor } nodes { id isResolved
        comments(first: 1) { nodes { author { login } path url } } } } } } }' \
  -q '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)
      | .comments.nodes[0] as $c | "\(.id) \($c.author.login) \($c.path) \($c.url)"'
