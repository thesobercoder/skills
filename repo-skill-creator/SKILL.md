---
name: repo-skill-creator
description: Create or update a repo-backed skill that should live in this repository and be installed into `~/.agents/skills` and `~/.claude/skills` via `install.sh`. Use this instead of the generic `skill-creator` workflow whenever the user wants a skill that belongs in this repo, wants to turn a workflow into a repo-backed skill here, or mentions this skills repo or its installer.
install_mode: materialize
---

# Repo Skill Creator

A skill for creating or updating repo-backed skills in this repository.

Use `skill-creator` as the base workflow for writing and improving the skill itself. This skill adds the repository-specific conventions and guardrails.

At a high level, the process goes like this:

- Figure out whether the user wants a new repo-backed skill, an update to an existing one, or just discussion
- Confirm the actual target skill and deliverable before editing anything
- Use `skill-creator` to draft or improve the skill
- Apply this repository's install conventions
- Run `__SKILLS_REPO_ROOT__/install.sh`
- Verify the installed result in both target directories
- Update `README.md` if a repo-backed skill was added, renamed, or removed

Your job when using this skill is to figure out where the user is in that process and help them move forward. If they already have a draft, go straight to editing it. If they are still figuring out what the skill should be, start by clarifying the goal. The order is flexible, but do not skip the target-confirmation step when there is ambiguity.

## Capture intent

Start by identifying the user's actual deliverable before you edit anything. Extract as much as you can from the conversation history first, then ask only for the missing information.

Confirm these points:

1. Is the user asking to create a new skill, update an existing skill, or just discuss the idea?
2. What should the target skill enable Claude to do?
3. Is any pasted text the deliverable itself, workflow guidance, or source material to transform into the real deliverable?
4. If an existing skill is involved, which skill exactly?
5. Does the target belong as a repo-backed local skill in this repository?

Treat these as hard guardrails:

- Treat this skill as workflow guidance, not as the default deliverable.
- Do not assume a pasted skill-shaped document is the thing the user wants created or edited.
- Do not assume the most recent pasted block overrides the broader conversation goal.
- Distinguish between a meta skill, a workflow description, and the real domain skill the user wants.
- Do not assume that mentioning an existing skill name means that existing skill is the target.
- Do not update an existing skill just because its name partially matches the conversation.

Resolve references like `this`, `that`, or `use this` against the full conversation, not just the most recent pasted artifact.

If there is clear ambiguity about the target, ask one short clarifying question before making changes.

Examples of ambiguity that require a question:

- the user pasted instructions that could be either a meta skill or the desired deliverable
- the user referenced an existing skill name, but did not explicitly say to edit that skill
- the conversation could refer either to creating a new helper/meta skill or creating the actual end-user skill

Good clarifying questions are short and concrete, for example:

- `Do you want me to create a new skill from this workflow, or update the existing skill?`
- `Is the target the meta skill you pasted, or the actual domain skill it is describing?`
- `Should I edit <existing-skill-name>, or create a new skill for this?`

Prefer a short question over a wrong edit when the target is not explicit.

## Repo conventions

Canonical repo-backed skills live at:

`__SKILLS_REPO_ROOT__/<skill-name>`

The install targets are:

- `~/.agents/skills/<skill-name>`
- `~/.claude/skills/<skill-name>`

This repository has a single source of truth:

- local repo-backed skills live in this repo
- third-party skills are cloned under `__SKILLS_REPO_ROOT__/.external/`
- `__SKILLS_REPO_ROOT__/install.sh` refreshes both `~/.agents/skills` and `~/.claude/skills`

Treat the install targets as generated outputs. Use the installer to refresh them. Do not manage them by hand when `__SKILLS_REPO_ROOT__/install.sh` can apply the change.

For repo-backed local skills, do not add entries to `skills.json`. The installer discovers local skills from the repository itself. `skills.json` is for third-party repos.

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

Write supported placeholders in the canonical repo files and let the installer replace them during materialization. Do not replace them by hand in the source repo.

Do not add `install_mode: materialize` unless the skill actually needs that behavior.

## Create or update workflow

1. Load and follow `skill-creator` for the actual skill-writing process.
2. Confirm the actual target skill and whether you are creating or editing.
3. If editing an existing repo-backed skill, preserve its directory name and `name` frontmatter unless the user explicitly wants a rename.
4. Create or edit the skill directory at `__SKILLS_REPO_ROOT__/<skill-name>`.
5. Write `SKILL.md` and any bundled resources there.
6. Update `README.md` so `## Skills In This Repo` stays accurate when a repo-backed skill is added, renamed, or removed.
7. Run `__SKILLS_REPO_ROOT__/install.sh` from the repo root so the install targets are refreshed.
8. Verify the installed paths with `ls -l ~/.agents/skills/<skill-name> ~/.claude/skills/<skill-name>`.

If the skill uses `install_mode: materialize`, verify that the installed target is a directory copy instead of a symlink.

Carry the work through end to end unless the user only wants discussion.

## Safety rules

- Do not edit an existing skill unless the conversation clearly identifies it, or the user confirms it after a short clarification.
- If either `~/.agents/skills/<skill-name>` or `~/.claude/skills/<skill-name>` already exists as a non-symlink directory, inspect it before proceeding.
- If refreshing the installer-managed targets would be destructive or ambiguous, ask the user before proceeding.
- Do not move existing skill contents out of either install target unless the user asked for that migration.

## Repo hygiene

- Keep the new skill directory minimal.
- Prefer a single `SKILL.md` unless bundled resources materially help.
- Keep `README.md` current when adding, renaming, or removing a repo-backed skill.
- If you use placeholders, make sure the skill frontmatter includes `install_mode: materialize`.

## Communication

- Be direct about the setup: canonical repo directory plus installer-managed `.agents` and `.claude` targets.
- Tell the user the final repo path and both installed paths.
- Prefer saying `run the installer` over describing low-level symlink mechanics.
- If you used `skill-creator` conventions but skipped full eval work because the user wanted a lightweight pass, say that explicitly.
- If the skill is materialized, say that the installed copy is generated by the installer and the canonical source remains in this repo.
