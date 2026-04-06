---
name: opencode-contributor
description: Run the full contribution workflow for anomalyco/opencode, from repo-state checks through issue selection, implementation, verification, and PR drafting. Use this whenever the user wants to contribute to opencode, look for issues in opencode, sync their fork, prepare an opencode PR, or ask for the highest-impact small fix in this repo. Only use it for the opencode repo or the user's fork of it, and abort if the current repo is not opencode.
---

# OpenCode Contributor

Follow this workflow when helping the user contribute to `anomalyco/opencode`.

## Goals

- Keep work aligned with the repo's AI contribution rules.
- Prefer small, high-impact, reviewable changes.
- Keep PR descriptions short, human, and specific.
- Avoid switching context blindly when there is unfinished work.

## Step 1: Confirm repo identity

Before doing anything else, verify that the current git repo is `anomalyco/opencode` or a fork of it.

- Check git remotes.
- Accept either the upstream repo or a fork whose upstream is `anomalyco/opencode`.
- If the repo is not opencode, stop immediately and tell the user this skill only applies to opencode.

Do not continue past this step in the wrong repo.

## Step 2: Check worktree state

Inspect the current branch and worktree before switching branches or syncing anything.

If there are uncommitted changes, do not automatically checkout `dev`.

Ask the user to choose one of these paths:

1. Continue fixing the current work.
2. Raise a PR for the current work first, then return to `dev`.

Do not invent a third path unless the user explicitly asks for it.

If the worktree is clean, continue.

## Step 3: Return to `dev` and sync the fork

When the worktree is clean and the user is ready to start fresh:

1. Checkout `dev`.
2. Fetch from `upstream`.
3. Fast-forward or rebase local `dev` onto `upstream/dev`.
4. Update the fork's `dev` branch if needed.

Prefer a clean, explicit git flow. Do not use destructive commands.

## Step 4: Apply opencode contribution rules strictly

Read and follow the repo guidance, especially `CONTRIBUTING.md`, `AGENTS.md`, and the PR template.

Non-negotiable rules:

- PRs must reference an existing issue.
- Prefer bug fixes, environment quirks, missing standard behavior, perf work, and docs.
- Avoid net-new feature work unless the maintainers have already approved the design direction.
- Keep PRs small and focused.
- Explain how the change was verified.
- Do not write long AI-looking issue or PR descriptions.

When choosing work, bias toward:

- existing open issues
- unassigned issues
- small scope with clear repro
- high user impact
- low design ambiguity

## Step 5: Triage issues with `gh`

Use `gh` to inspect open issues, labels, assignees, comments, and recency.

Look for work that fits the contribution rules:

- bug
- perf
- docs
- missing standard behavior
- environment-specific fix

Avoid picking issues that are already clearly owned unless the user explicitly wants to coordinate around them.

When recommending candidates, explain:

1. Why it matters.
2. Why the scope seems small.
3. What files or subsystems are likely involved.
4. Any sign that the issue is risky, duplicated, or already in flight.

## Step 6: Inspect merged PR style before drafting

Before drafting a PR title or body, inspect recently merged opencode PRs with `gh`.

Learn the real local style instead of using generic PR language.

Observed style to preserve:

- Titles are short and conventional: `fix:`, `fix(scope):`, `refactor:`, `test:`, `tweak:`.
- Bodies are often very short.
- Many PRs use either:
  - `Fixes #123`, or
  - a short `## Summary` and `## Verification` section.
- The tone is plain, factual, and compact.

Do not write theatrical explanations, long narratives, or AI-sounding filler.

## Step 7: Implement like a good repo citizen

After an issue is chosen:

1. Create a branch prefixed with the issue number.
2. Make the smallest correct change.
3. Follow the repo coding style.
4. Add or extend regression coverage where it helps lock in the fix.
5. Run targeted verification from the correct package directory.

Keep changes narrow. Do not refactor unrelated code just because it is nearby.

## Step 8: Verification expectations

For opencode, verify from package directories, not the repo root.

Prefer the smallest meaningful verification set that proves the fix:

- targeted `bun test ...`
- `bun typecheck`
- any package-specific build or reproduction step if relevant

If the environment blocks verification, say exactly what failed and whether it is a local toolchain issue or a code issue.

## Step 9: Draft PR text in opencode style

The PR title must follow conventional commit style.

The PR body must be concise and issue-linked.

Default to this structure unless there is a strong reason to go shorter:

```md
Fixes #12345

## Summary

- short bullet on the root problem
- short bullet on the fix
- short bullet on any regression coverage or notable edge case

## Verification

- `bun test ...`
- `bun typecheck`
```

Treat this as the normal opencode PR shape for small bug fixes.

Only use a shorter body like `Fixes #12345` by itself when the change is extremely obvious and the diff already tells the full story.

Only use more of the repo template when the change genuinely needs more context.

Prefer one of these patterns.

### Minimal pattern

```md
Fixes #12345
```

### Slightly fuller pattern

```md
Fixes #12345

## Summary

- short bullet on the root problem
- short bullet on the fix

## Verification

- `bun test ...`
- `bun typecheck`
```

### Template-backed pattern

Use the repo template when it adds useful context, but keep each section brief and human.

Do not mechanically fill every template section with fluff. If a section does not add value, keep it minimal.

Good PR writing rules:

- Lead with the issue link.
- State the root problem plainly.
- State the fix plainly.
- List concrete verification commands.
- Match the tone of recently merged opencode PRs, not generic OSS boilerplate.
- Keep it short enough that a maintainer can skim it in seconds.

Bad PR writing patterns:

- long prose blocks
- generic AI summaries
- inflated claims
- repeating obvious diffs in paragraph form

## Step 10: Default behavior

Unless the user asks to stop earlier, carry the workflow through end to end:

1. repo check
2. worktree check
3. sync
4. issue triage
5. implementation
6. verification
7. branch/commit guidance
8. PR draft

Only stop early when the user wants discussion only, or when blocked by missing information, an unsafe operation, or unfinished local work that requires a user decision.

## Communication style

- Be direct.
- Be brief.
- Sound like a contributor, not a bot writing marketing copy.
- When recommending an issue, explain the tradeoff clearly.
- When drafting PR text, keep it terse and natural.

## Final checklist

Before finishing, confirm all of these are true:

- current repo is opencode or the user's opencode fork
- existing issue is linked
- change is small and aligned with contribution rules
- verification ran from the correct package directory
- PR title matches repo style
- PR body is short and does not read like AI-generated filler
