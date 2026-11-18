#!/usr/bin/env bash
# Prints the pid of every live descendant of a process, one per line, parents before their children.
# Usage: descendants.sh <pid>

set -uo pipefail

desc() { for c in $(pgrep -P "$1"); do echo "$c"; desc "$c"; done; }
desc "${1:?usage: descendants.sh <pid>}"
