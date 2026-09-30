# Update prompt

Instructions for an AI coding agent updating an existing install of this
bundle. A person starts it with: *"Read `<path-to-this-repo>/UPDATE.md` and
follow it."* No install yet → follow `INSTALL.md` instead.

Local edits to an installed copy are the user's. Never overwrite one without
their answer.

## 1. Find the install

Search both scopes' rules files (`INSTALL.md` § 2) for
`<!-- code-standards:begin`. For each block found, read `version=` (the
bundle commit it was installed from) and `skills=` (`INSTALL.md` § 4 gives
the entry format; an entry with no `:` suffix is installed under its bundle
name). None found → stop and run `INSTALL.md`.

Record the new version: `git -C <this-repo> rev-parse --short HEAD`. Same as
`version=` → report that the install is current and stop.

## 2. Read what changed

`git -C <this-repo> diff <version>..HEAD --stat`, then read every changed
file in full at `HEAD`. Nothing gets installed unread.

## 3. Merge each installed piece three ways

The pieces: the rules block, each installed skill folder, and the hook
folder. For each, compare three versions, applying the marker's renames to
the first two:

- **old** — the bundle at `version=` (`git show <version>:<path>`)
- **local** — the installed copy
- **new** — the bundle at `HEAD`

| old → local | old → new | Action |
| --- | --- | --- |
| unchanged | changed | Take new |
| changed | unchanged | Keep local |
| changed | changed | Show the user both diffs, and ask: keep local, take new, or merge (then show the merged result before writing it) |
| unchanged | unchanged | Nothing to do |

For the rules block, compare section by section: a section missing from the
local block is one the user dropped at install, and stays dropped unless they
say otherwise.

## 4. Skills added or removed since the install

- **In `skills/` but not in `skills=`** → new since the install. Run
  `INSTALL.md` § 3's collision check and § 5's copy for it alone.
- **In `skills=` with `:-`** → skipped at install; leave it skipped.
- **In `skills=` but no longer in `skills/`** → removed from the bundle. Ask
  before deleting the installed copy.

## 5. Hook (Claude Code only)

After § 3 settles the hook files, re-run `INSTALL.md` § 6 steps 2–4: renamed
skill defaults, the `settings.json` merge (append-only, no duplicate
entries), and `test.sh`, whose last line must read `all passed`.

## 6. Rewrite the marker

Set `version=` to the new commit and `skills=` to the current entries,
renames and skips preserved.

## 7. Report

A table of every piece: taken new, kept local, merged, installed, removed, or
unchanged. Then the next step: start a new session for rules and skill
changes to load; hook changes apply from the next prompt.
