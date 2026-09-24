#!/usr/bin/env bash
# Sourced by hooks that arm on a skill invocation. A directory-scoped or plugin listing prefixes the invoked name.

# is_skill <invoked> <name> — true when <invoked> is <name> under any scope.
is_skill() {
  case "$1" in
    "$2"|*:"$2") return 0 ;;
    *) return 1 ;;
  esac
}
