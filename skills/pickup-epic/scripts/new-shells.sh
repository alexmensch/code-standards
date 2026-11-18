#!/usr/bin/env bash
# Prints a session's live Bash-tool shells, comma-separated, when any is missing from the asked list; prints nothing otherwise.
# Usage: new-shells.sh <session pid> [<asked pids, comma-separated>]

set -uo pipefail

pid=${1:?usage: new-shells.sh <session pid> [<asked pids>]}
asked=",${2:-},"

# A Bash-tool command runs in a shell that sources a shell-snapshots/ file; the session's other
# processes (caffeinate, MCP servers) and the commands under that shell do not match.
shells=''; new=''
for d in $(bash "$(dirname "$0")/descendants.sh" "$pid"); do
  case "$(ps -o command= -p "$d" 2>/dev/null)" in
    */shell-snapshots/*)
      shells="$shells${shells:+,}$d"
      case "$asked" in *",$d,"*) ;; *) new=1 ;; esac ;;
  esac
done
[ -z "$new" ] || echo "$shells"
