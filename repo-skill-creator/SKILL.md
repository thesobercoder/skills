---
name: repo-skill-creator
description: Create or update a repo-backed skill that should live in this repository and be installed into `~/.agents/skills` and `~/.claude/skills` via `install.sh`. Use this instead of the generic `skill-creator` workflow whenever the user wants to add or edit a skill in this repo, wants to turn a workflow into a repo-backed skill here, mentions this skills repo or its installer, or names one of the repo-backed skills as the thing to change. If the target skill is ambiguous, confirm it before editing.
install_mode: materialize
---

# Repo Skill Creator

A skill for creating or updating repo-backed skills in this repository. It layers repository-specific conventions (install targets, installer, placeholders, README) on top of the generic `skill-creator` workflow — it does not replace it.

## Required reading before drafting (hard gate)

Before writing or modifying the body of any SKILL.md under this skill, **you must read `__INSTALL_TARGET_DIR__/skill-creator/SKILL.md` in full using the Read tool in the current session.** This is not optional and not skippable, even if you have written skills before or feel confident about the conventions.

Why this gate exists: `skill-creator` contains the specific writing conventions that repo-backed skills here are expected to follow — description pushiness and trigger coverage, imperative form in instructions, the "explain the why rather than shouty MUSTs" rule, progressive disclosure, bundled-resource patterns, and the draft-test-iterate loop. General intuition about "how to write a SKILL.md" is not a substitute. A previous attempt skipped this step and shipped a skill that had to be re-audited and patched after the fact. Do not repeat that mistake.

If the file at that path is missing (e.g. `skill-creator` is not installed in the current target), stop and tell the user before drafting anything. Do not fall back to writing from memory.

You may skip the reading only if the user is asking for a pure rename, a frontmatter-only tweak, or a trivial typo fix in an existing skill body — in other words, edits that do not require drafting prose. In those cases, say so explicitly in your reply so the user can correct you if they disagree.

## Process overview

At a high level, the process goes like this:

- Figure out whether the user wants a new repo-backed skill, an update to an existing one, or just discussion
- Confirm the actual target skill and deliverable before editing anything
- If editing, read the existing skill before changing it
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
- Do not create a new helper or meta skill unless the user explicitly asked for one.

Resolve references like `this`, `that`, or `use this` against the full conversation, not just the most recent pasted artifact.

These guardrails do not override an explicit request. If the user clearly says to edit `repo-skill-creator`, `composio`, or another named repo-backed skill, treat that skill as the target.

Proceed without a clarifying question when the target is explicit, for example:

- the user explicitly names the skill to edit
- the user gives the repo path of the skill to edit
- the user explicitly asks for a new skill with a clear name or purpose
- the user explicitly says the pasted workflow should become a new skill

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

1. **Read `__INSTALL_TARGET_DIR__/skill-creator/SKILL.md` in full** (see the "Required reading before drafting" gate above). Do this before any other step in the drafting workflow. The only time you may skip is a rename / frontmatter-only / trivial typo edit, and you must say so in your reply.
2. Confirm the actual target skill and whether you are creating or editing.
3. If editing an existing repo-backed skill, read its current `SKILL.md` before changing it.
4. If editing an existing repo-backed skill, preserve its directory name and `name` frontmatter unless the user explicitly wants a rename.
5. Create or edit the skill directory at `__SKILLS_REPO_ROOT__/<skill-name>`, applying `skill-creator`'s writing conventions (imperative form in instructions, explain the why, trigger-rich pushy description, progressive disclosure, under ~500 lines).
6. Write `SKILL.md` and any bundled resources there.
7. Update `README.md` so `## Skills In This Repo` stays accurate when a repo-backed skill is added, renamed, or removed.
8. Run `__SKILLS_REPO_ROOT__/install.sh` from the repo root so the install targets are refreshed.
9. Verify the installed paths with `ls -l ~/.agents/skills/<skill-name> ~/.claude/skills/<skill-name>`.

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

## House rules (beyond `skill-creator`)

These are repo-specific rules that supplement the generic `skill-creator` conventions. Each rule was added in response to a concrete mistake — the "why" after each one is not decoration, it is the evidence.

### Agent-agnostic language

Write skill bodies and descriptions in tool-neutral language. Use `the agent`, `the tool`, `any CLI with X access`, `the runtime`. Do not name specific CLIs, harnesses, or model families (e.g. "Claude Code", "Codex CLI", "Cursor", "Opus", "Sonnet") in the skill unless the skill is specifically about that runtime or model.

Legitimate exceptions in this repo: `claude-coworker` (specifically about delegating to the Claude CLI), `repo-skill-creator` (specifically about this repo), and any skill that wraps a named external tool whose name is the whole point.

Why: skills are reusable across agents. A skill that says "when running in Claude Code, do X" reads awkwardly from Codex or any other runtime, and creates pressure to fork the skill per tool. The whole point of a skill is that it travels. Use an `<agent identifier>` placeholder if you need human traceability of which runtime wrote something — the runtime fills it in, the skill does not.

### Lock the skill name before drafting prose

Decide the skill's final name before writing the SKILL.md body. If you are not sure, ask the user for one good name up front rather than starting with a placeholder and renaming later.

Why: a rename touches the directory, the `name` frontmatter, the `# Heading`, in-body self-references, the README entry, and requires a reinstall. Doing it twice is cheap individually but compounds into pointless churn. Picking the name once is free.

### Trust the installer for pruning

Do not manually `rm` symlinks or directories under `~/.agents/skills/` or `~/.claude/skills/`. The installer detects stale managed entries (symlinks pointing into this repo, or directories marked with `.skills-install.json`) and removes them automatically on every run. Rename a skill in this repo, run `./install.sh`, and the old target will be pruned as part of the same pass.

The only time you touch install targets by hand is if something outside this repo's management put a file there that the installer refuses to own — inspect it, do not just delete it.

Why: manual `rm -f` before reinstall is a smell that suggests you do not trust your own installer. If it is broken, fix the installer. If it is not, do not duplicate its work.

### Durable rules live in skills, not memory

When a session teaches you something that should apply in *future* sessions across *other* agents, capture it as a skill edit, not as a memory entry. Memory is local to the runtime that wrote it — the memory written by Claude Code does not reach Codex CLI, and vice versa — so a lesson stashed there is invisible to every agent that did not write it. If the user switches tools for any reason (rate limits, cost, preference), the lesson is gone.

This does not mean the memory system is wrong or should be avoided; it means the two systems have different jobs. Memory is correct for user facts, project context, and personal preferences. Skills are correct for durable rules and conventions that should apply regardless of which runtime is running. If a correction the user gave you would help a different agent on a different day, the correction belongs in a skill — even a tiny one, even a one-line house rule in an existing skill. Skipping the skill edit because "memory is easier" traps the lesson in a single runtime and defeats the whole point of maintaining this repo.

Why: users pay for AI access in non-trivial ways and often rely on multiple tools precisely so they can keep working when one is unavailable. A skills repo that treats cross-tool portability as the default is directly more valuable than one that treats it as an afterthought.

### Self-audit against `skill-creator` after drafting, not only before

The hard-gate reading step (see "Required reading before drafting") makes sure you have the conventions loaded before you write. That is necessary but not sufficient. After drafting, before running the installer, run through the `skill-creator` checklist again against the actual text you produced:

- Is the description trigger-rich and slightly pushy, per `skill-creator`'s line 67 guidance?
- Are instructions in the imperative form?
- Have you explained *why* rather than leaning on ALL CAPS MUSTs?
- Is the file under ~500 lines, with progressive disclosure for anything longer?
- Does the language survive being read by an agent that is not the one writing it (see "Agent-agnostic language" above)?
- Are there any stale references left over from renames, placeholder substitutions, or half-finished edits?

Name the gaps you find in your reply, even if they are minor. Shipping silently means the next audit happens in production.

Why: "I read the guide before writing" is not the same as "what I wrote matches the guide." A previous session read the guide, wrote the skill, and still missed the agent-agnostic language rule and left stale rename references in place. The audit after drafting catches both.

