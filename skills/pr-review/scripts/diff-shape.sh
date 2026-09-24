#!/usr/bin/env bash
# Measures where a diff's lines went (source / tests / docs) and how much of the added source is comments.
# Usage: diff-shape.sh [<base>]   Env overrides: TEST_RE DOC_RE DATA_RE COMMENT_RE PROSE_MAX MIN_SOURCE

set -euo pipefail

base="${1:-}"
if [ -z "$base" ]; then
  base="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
fi
range="$base...HEAD"

export TEST_RE="${TEST_RE:-(^|/)(tests?|__tests__|spec|specs|testFixtures)/|[._-](test|spec)\.[^/]+$|Tests?\.[^/.]+$}"
export DOC_RE="${DOC_RE:-\.(md|mdx|rst|adoc|txt)$}"
export DATA_RE="${DATA_RE:-\.(json|csv|tsv|svg|snap|lock|lockb)$|-lock\.ya?ml$|\.min\.[^/]+$|(^|/)(vendor|third_party|generated)/}"
export COMMENT_RE="${COMMENT_RE:-^(//|/\*|\*|#|--|;|<!--)}"
PROSE_MAX="${PROSE_MAX:-25}"
MIN_SOURCE="${MIN_SOURCE:-80}"

classify='
  BEGIN { t = ENVIRON["TEST_RE"]; d = ENVIRON["DOC_RE"]; g = ENVIRON["DATA_RE"] }
  function bucket(path) { return (path ~ t) ? "tests" : (path ~ d) ? "docs" : (path ~ g) ? "data" : "source" }
'

echo "range: $range"
git diff --no-renames --numstat "$range" | awk -F'\t' "$classify"'
  { b = bucket($3); A[b] += $1 + 0; D[b] += $2 + 0; N[b]++ }
  END { for (k in A) printf "%-7s %3d files  +%-6d -%-6d net %+d\n", k, N[k], A[k], D[k], A[k] - D[k] }'

source_files=()
while IFS= read -r path; do
  source_files+=("$path")
done < <(git diff --no-renames --numstat "$range" | awk -F'\t' "$classify"' bucket($3) == "source" { print $3 }')

[ "${#source_files[@]}" -gt 0 ] || { echo "no source files changed"; exit 0; }

git diff --no-renames --unified=0 "$range" -- "${source_files[@]}" \
  | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+[[:space:]]*//' \
  | awk -v max="$PROSE_MAX" -v min="$MIN_SOURCE" '
      BEGIN { c_re = ENVIRON["COMMENT_RE"] }
      NF { t++; if ($0 ~ c_re) c++ }
      END {
        if (!t) { print "no added source lines"; exit }
        pct = 100 * c / t
        printf "%d%% prose (%d comment / %d code, %d added source lines)\n", pct, c, t - c, t
        if (t >= min && pct > max) printf "FINDING: prose over %d%% on a diff adding %d+ source lines\n", max, min
      }'
