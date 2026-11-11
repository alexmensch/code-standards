#!/usr/bin/env bash
# Answers whether a stack's open members are exactly the pinned ones, in order, at their pinned heads; prints each difference.
# Usage: stack-pins.sh <N>=<pinned head>...   bottom first. Exit 0 when they match, 1 on a difference, 2 when the stack cannot be read.

set -uo pipefail

[ $# -ge 1 ] || { echo "usage: stack-pins.sh <N>=<sha>..." >&2; exit 2; }
for a in "$@"; do [[ "$a" == [0-9]*=?* ]] || { echo "not <N>=<sha>: $a" >&2; exit 2; }; done
top=${!#}
top=${top%%=*}

open=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$top" -f query='
  query($owner: String!, $name: String!, $n: Int!) { repository(owner: $owner, name: $name) {
    pullRequest(number: $n) { stack { entries(first: 100) { nodes { pullRequest { number state headRefOid } } } } } } }' \
  -q '.data.repository.pullRequest.stack.entries.nodes[]? | .pullRequest | select(.state == "OPEN")
      | "\(.number)=\(.headRefOid)"') || exit 2

pinned=$(printf '%s\n' "$@")
[ "$open" != "$pinned" ] || exit 0
[ -n "$open" ] || { echo "#$top is in no stack, or none of it is open"; exit 1; }
diff <(echo "$pinned") <(echo "$open") | sed -n 's/^< /pinned only: /p; s/^> /stack only: /p'
exit 1
