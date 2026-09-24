# Install prompt

Instructions for an AI coding agent installing this bundle. A person starts
it with: *"Read `<path-to-this-repo>/INSTALL.md` and follow it."* Re-running
it later updates an existing install in place.

Work through the steps in order. Ask the user only where a step says to;
everything else has a default.

## 1. Read the bundle

Read every file in this repository before installing anything: `README.md`,
`AGENTS.md.fragment`, both `skills/*/SKILL.md` and their `references/` and
`scripts/`, and `hooks/`. Nothing gets installed unread.

Record the bundle version: `git -C <this-repo> rev-parse --short HEAD`.

## 2. Choose the harness and the scope

Identify the harness running this session. Then ask the user one question:
**install for this user (every repo), or for one project?** Default to the
project the session is in, if any.

| Piece | Claude Code, user scope | Claude Code, project scope | Other harnesses |
| --- | --- | --- | --- |
| Always-on rules | `~/.claude/CLAUDE.md` | `<repo>/CLAUDE.md`, or `<repo>/AGENTS.md` when `CLAUDE.md` links to or imports it | The harness's always-loaded rules file (`AGENTS.md` for most) |
| Skills | `~/.claude/skills/<name>/` | `<repo>/.claude/skills/<name>/` | The harness's skill folder if it has one; otherwise `<repo>/docs/agent-skills/<name>/`, plus a trigger line per skill in the rules file (§ 4) |
| Hook | `~/.claude/hooks/code-standards/` + `~/.claude/settings.json` | `<repo>/.claude/hooks/code-standards/` + `<repo>/.claude/settings.json` | Not installed — it uses Claude Code's hook events |

A project install is written into the working tree; it is not committed unless
the user asks.

## 3. Check for collisions, and settle names

**Skills.** For each of `code-craft` and `pr-review`, look for an existing skill
of the same name at **both** scopes (user and project): Claude Code resolves a
name clash as user over project, so a user install silently shadows a
project skill of the same name in every repo. If one exists, check whether it is a previous install of this bundle —
the rules block's marker (§ 4) lists the installed skill names. If it is,
replace it. If not, show the user the difference and ask them to pick:

- **Replace** the existing skill with this one.
- **Rename** this bundle's skill (ask for the name; suggest a team or project
  prefix, such as `acme-code-craft`).
- **Skip** this skill.
- **Extend** (`pr-review` only, when the existing one is a project skill):
  rename the project skill to `<project>-pr-review` and cut it to the
  project-specific gates. This bundle's `pr-review` loads any project skill
  named that way, so "review PR 123" and `/pr-review` still reach both.

**Renaming touches every reference.** Rewrite all of them in the installed
copies, never in this repository:

- the skill's folder name and its frontmatter `name:`
- references in the other skill (`pr-review` loads `code-craft` and points at
  `code-craft/references/…`)
- the rules block's § Code structure trigger and its mentions of both skills
- the hook's `REVIEW_SKILL` / `DESIGN_SKILL` defaults

Verify with a search over the installed files for the old names; zero hits
outside prose that genuinely means the old name.

**Rules.** Search the target rules file for existing sections covering the
same subjects (tool attribution, code comments, DRY, code structure, commit
granularity, PR descriptions, stale context, applying written rules), by
heading or by content. For each overlap, show the user both versions and ask
whether this bundle's version replaces the existing one, or the existing one
stays and this bundle's section is dropped. Never delete existing rules
without that answer, and never leave two conflicting versions both installed.

## 4. Install the always-on rules

Insert `AGENTS.md.fragment` into the target rules file inside a marker block,
applying any renames from § 3:

```
<!-- code-standards:begin version=<sha> skills=<code-craft name>,<pr-review name> -->
…fragment…
<!-- code-standards:end -->
```

- File has no block yet → append the block at the end.
- File has a block → replace everything between the markers, and keep the
  skill names the old marker recorded unless the user asks to change them.
- Sections dropped in § 3 are removed from the inserted copy.

Harness with no skill folder: add one line per skill to the block, after the
§ Code structure section — *"Load `docs/agent-skills/<name>/SKILL.md` when:
\<the skill's frontmatter description\>."*

## 5. Install the skills

Copy `skills/<name>/` to the target skill folder for each skill not skipped,
under its final name, replacing any previous install of it. Then make
`scripts/diff-shape.sh` executable and run it once from the target repo (or,
for a user install, from the repo the session is in):

```
bash <installed pr-review>/scripts/diff-shape.sh
```

It must print a `range:` line and per-bucket counts. If the repo's tests,
docs or data files land in the wrong bucket, tell the user which override
(`TEST_RE`, `DOC_RE`, `DATA_RE`, `COMMENT_RE`) would fix it, and record the
value in the rules block for a project install.

## 6. Install the hook (Claude Code only)

Requires `bash` and `jq`; if `jq` is missing, say so and skip this step.

1. Copy `hooks/review-design-reminder.sh`, `hooks/skill-name.sh` and
   `hooks/test.sh` to the hook folder from § 2; make them executable.
2. If either skill was renamed, change the `REVIEW_SKILL` / `DESIGN_SKILL`
   defaults in the installed `review-design-reminder.sh`.
3. Merge `hooks/settings.snippet.json` into the target `settings.json`,
   replacing `<HOOK_DIR>` with the folder — an absolute path for a user
   install, `$CLAUDE_PROJECT_DIR/.claude/hooks/code-standards` for a project
   install. **Append** to existing `PreToolUse` and `UserPromptSubmit`
   arrays; never replace them, and don't add a second copy of an entry that
   is already there.
4. Run the installed `test.sh`. The last line must read `all passed`. For a
   renamed install, run it with the original names
   (`REVIEW_SKILL=pr-review DESIGN_SKILL=code-craft bash test.sh`), since the
   cases use them.

Hooks load when a session starts: the hook takes effect in the next session,
not this one.

## 7. Report

Finish with a table of every piece: what was installed, where, under what
name, and what was replaced, renamed, skipped or dropped. Then name the one
thing the user does next — start a new session for the hook and skills to
load. To uninstall: delete the marker block, the skill folders, the hook
folder, and the two hook entries in `settings.json`.
