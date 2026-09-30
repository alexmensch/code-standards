# code-standards

Portable rules and skills for AI coding agents: code design, refactoring, code
review and write-time quality. Language- and repo-neutral.

## Install

Point an agent session at the install prompt:

> Read `<path-to-this-repo>/INSTALL.md` and follow it.

It asks whether to install for the user or for one project, checks for
existing skills and rules with the same names or subjects, offers to rename
or replace, and reports what went where.

To update an existing install, point a session at `UPDATE.md` instead. It
merges bundle changes into the installed copies and keeps local edits,
asking where both sides changed.

## What's here

| Path | Loads | What it is |
| --- | --- | --- |
| `AGENTS.md.fragment` | Always, from the rules file | Tool attribution · code comments · never document absence · DRY · code-structure checks · commit granularity · PR descriptions · large-PR honesty · stale context · applying written rules |
| `skills/code-craft/` | On design, refactor, review, recurring bug | Design pass, refactoring, review lens, bug classes; `references/` holds the smells table, patterns admissible by force, and write-time patterns |
| `skills/pr-review/` | On a review request | Review priority order, resource and performance cost, diff efficiency with numbers (`scripts/diff-shape.sh`), plan drift, disposition of findings |
| `skills/pickup/` | On "work on ticket X", "/pickup" | Takes shovel-ready work only: readiness gate, implement, PR, `pr-review` in a subagent, fix the findings `code-craft` settles, hand every decision back |
| `hooks/` | Claude Code only | Keeps the design pass in front of the model on every turn of a review — `hooks/README.md` |

The fragment is the always-on half: short enough to load in every session,
and it names the skill to load for the full pass.

## Developing

- `bash hooks/test.sh` — the hook's behavioural tests.
- `bash skills/pr-review/scripts/diff-shape.sh <base>` — run from inside any
  repo to check the bucketing.
- Skills cross-reference each other and the fragment by section name. A
  heading rename is a search across the whole repo, and `INSTALL.md` § 3
  lists every place a skill name appears.
