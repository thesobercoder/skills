---
name: repo-skill-creator
description: Create or update a Claude Code skill that should live in this repository, then symlink it into both `~/.agents/skills` and `~/.claude/skills`. Use this instead of the generic `skill-creator` workflow whenever the user wants a new repo-backed skill here, wants to turn a workflow into a skill in this repo, or mentions those skill directories, symlinks, or this skills repo.
install_mode: materialize
---

# Repo Skill Creator

Use `skill-creator` as the base workflow, but apply this repository's conventions on top.

## Purpose

This skill exists for skills that should be stored in this repository at:

`__SKILLS_REPO_ROOT__/<skill-name>`

and exposed via the root installer into:

`~/.agents/skills/<skill-name>`

and

`~/.claude/skills/<skill-name>`

Do not create the canonical skill contents directly under either install target when the intent is a repo-backed skill.

## Installer model

This repository has a single source of truth:

- local repo-backed skills live in this repo
- third-party skills are cloned under `__SKILLS_REPO_ROOT__/.external/`
- `__SKILLS_REPO_ROOT__/install.sh` refreshes both `~/.agents/skills` and `~/.claude/skills`

Use the installer to refresh the target directories. Do not manage them by hand when `__SKILLS_REPO_ROOT__/install.sh` can apply the change.

## Install modes

By default, repo-backed skills are installed as symlinks from the targets back to this repository.

If a skill needs install-time path substitution, declare it explicitly in frontmatter:

```md
---
name: my-skill
install_mode: materialize
---
```

Use `install_mode: materialize` when the installed copy must differ from the canonical source in this repo.

The installer provides a built-in placeholder map for materialized skills:

- `__SKILLS_REPO_ROOT__`
- `__AGENTS_SKILLS_DIR__`
- `__CLAUDE_SKILLS_DIR__`
- `__EXTERNAL_REPO_ROOT__`
- `__SOURCE_SKILL_DIR__`
- `__INSTALLED_SKILL_DIR__`
- `__INSTALL_TARGET_DIR__`

All placeholder expansions are absolute paths.

Use them with these meanings:

- `__SKILLS_REPO_ROOT__`: root of this skills repository
- `__AGENTS_SKILLS_DIR__`: the absolute path to the `~/.agents/skills` install target directory
- `__CLAUDE_SKILLS_DIR__`: the absolute path to the `~/.claude/skills` install target directory
- `__EXTERNAL_REPO_ROOT__`: root of the cloned third-party repository under `__SKILLS_REPO_ROOT__/.external/` for this skill, or an empty string for local repo-backed skills
- `__SOURCE_SKILL_DIR__`: absolute canonical source directory of the skill being installed
- `__INSTALLED_SKILL_DIR__`: absolute final installed directory for this skill in the current target
- `__INSTALL_TARGET_DIR__`: absolute target base directory for the current install pass, either `~/.agents/skills` or `~/.claude/skills`

`__INSTALLED_SKILL_DIR__` and `__INSTALL_TARGET_DIR__` are target-specific. The installer materializes the skill separately for each target, so those values can differ between `.agents` and `.claude`.

The current supported use case here is the repo-root placeholder:

- write one or more supported placeholders in the canonical skill files inside this repo
- the installer will copy that skill into the targets and replace those placeholders during install

Do not add `install_mode: materialize` unless the skill actually needs that behavior.

## Default workflow

1. Load and follow `skill-creator` for the actual skill-writing process.
2. Confirm the skill name and intended trigger behavior.
3. Create the skill directory in this repo at `__SKILLS_REPO_ROOT__/<skill-name>`.
4. Write `SKILL.md` and any bundled resources there.
5. Update `README.md` so `## Skills In This Repo` includes the new skill and a short accurate description.
6. Run `__SKILLS_REPO_ROOT__/install.sh` from the repo root so the install targets are refreshed.
7. Verify the installed paths with `ls -l ~/.agents/skills/<skill-name> ~/.claude/skills/<skill-name>`.

If the new skill uses `install_mode: materialize`, verify the installed target is a directory copy instead of a symlink.

Carry the work through end to end unless the user only wants discussion.

## Install convention

Repo-backed skills in this setup are installed by `__SKILLS_REPO_ROOT__/install.sh`, which refreshes both `~/.agents/skills` and `~/.claude/skills` from this repository. Refer to both sides from the home directory in user-facing instructions, for example:

- `~/.agents/skills/composio -> __SKILLS_REPO_ROOT__/composio`
- `~/.agents/skills/lan-proxy -> __SKILLS_REPO_ROOT__/lan-proxy`
- `~/.claude/skills/composio -> __SKILLS_REPO_ROOT__/composio`
- `~/.claude/skills/lan-proxy -> __SKILLS_REPO_ROOT__/lan-proxy`

Create or update the repo-backed skill, then run the installer. Do not create the target symlinks by hand when the installer is available.

When describing the workflow to the user, prefer saying "run the installer" over describing low-level symlink mechanics.

## Safety rules

- If either `~/.agents/skills/<skill-name>` or `~/.claude/skills/<skill-name>` already exists as a non-symlink directory, inspect it before proceeding.
- If refreshing the installer-managed targets would be destructive or ambiguous, ask the user before proceeding.
- Do not move existing skill contents out of either install target unless the user asked for that migration.

## Repo hygiene

- Keep the new skill directory minimal.
- Prefer a single `SKILL.md` unless bundled resources materially help.
- Keep `README.md` current when adding, renaming, or removing a repo-backed skill.
- If you use `__SKILLS_REPO_ROOT__`, make sure the skill frontmatter includes `install_mode: materialize`.
- Do not replace `__SKILLS_REPO_ROOT__` in the canonical repo files by hand; let the installer materialize it into the installed copy.

## Communication

- Be direct about the setup: repo directory plus installer-managed `.agents` and `.claude` targets.
- Tell the user the final repo path and both installed paths.
- If you used `skill-creator` conventions but skipped full eval work because the user wanted a lightweight pass, say that explicitly.
- If the skill is materialized, say that the installed copy is generated by the installer and the canonical source remains in this repo.
