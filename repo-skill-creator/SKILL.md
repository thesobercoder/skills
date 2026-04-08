---
name: repo-skill-creator
description: Create or update a Claude Code skill that should live in this repository, then symlink it into both `~/.agents/skills` and `~/.claude/skills`. Use this instead of the generic `skill-creator` workflow whenever the user wants a new repo-backed skill here, wants to turn a workflow into a skill in this repo, or mentions those skill directories, symlinks, or this skills repo.
---

# Repo Skill Creator

Use `skill-creator` as the base workflow, but apply this repository's conventions on top.

## Purpose

This skill exists for skills that should be stored in:

`~/projects/skills/<skill-name>`

and exposed via symlinks at:

`~/.agents/skills/<skill-name>`

and

`~/.claude/skills/<skill-name>`

Do not create the canonical skill contents directly under either symlink directory when the intent is a repo-backed skill.

## Default workflow

1. Load and follow `skill-creator` for the actual skill-writing process.
2. Confirm the skill name and intended trigger behavior.
3. Create the skill directory in this repo at `~/projects/skills/<skill-name>`.
4. Write `SKILL.md` and any bundled resources there.
5. Create or update the symlink at `~/.agents/skills/<skill-name>` so it points to the repo directory.
6. Create or update the symlink at `~/.claude/skills/<skill-name>` so it points to the repo directory.
7. Update `README.md` so `## Skills In This Repo` includes the new skill and a short accurate description.
8. Verify both symlinks with `ls -l ~/.agents/skills/<skill-name> ~/.claude/skills/<skill-name>`.

Carry the work through end to end unless the user only wants discussion.

## Symlink convention

Repo-backed skills in this setup are symlinked from both `~/.agents/skills` and `~/.claude/skills` to this repository. Refer to both sides from the home directory in user-facing instructions, for example:

- `~/.agents/skills/composio -> ~/projects/skills/composio`
- `~/.agents/skills/lan-proxy -> ~/projects/skills/lan-proxy`
- `~/.claude/skills/composio -> ~/projects/skills/composio`
- `~/.claude/skills/lan-proxy -> ~/projects/skills/lan-proxy`

Match that convention for new local skills.

## Safety rules

- If either `~/.agents/skills/<skill-name>` or `~/.claude/skills/<skill-name>` already exists and points somewhere else, inspect it before changing anything.
- If replacing an existing non-symlink directory or a symlink to a different source would be destructive or ambiguous, ask the user before proceeding.
- Do not move existing skill contents out of either symlink directory unless the user asked for that migration.

## Repo hygiene

- Keep the new skill directory minimal.
- Prefer a single `SKILL.md` unless bundled resources materially help.
- Keep `README.md` current when adding, renaming, or removing a repo-backed skill.

## Communication

- Be direct about the three-part setup: repo directory plus `.agents` and `.claude` symlinks.
- Tell the user the final repo path and both symlink paths.
- If you used `skill-creator` conventions but skipped full eval work because the user wanted a lightweight pass, say that explicitly.
