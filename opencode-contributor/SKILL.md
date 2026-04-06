---
name: opencode-contributor
description: Run the full contribution workflow for anomalyco/opencode, from repo-state checks through issue selection, implementation, verification, and PR drafting. Use this whenever the user wants to contribute to OpenCode, look for issues in OpenCode, sync their fork, prepare an OpenCode PR, or ask for the highest-impact small fix in this repo. Only use it for the OpenCode repo or the user's fork of it, and abort if the current repo is not opencode.
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

## Step 4: Apply OpenCode contribution rules strictly

Read and follow the repo guidance, especially `CONTRIBUTING.md`, `AGENTS.md`, and the PR template.

Non-negotiable rules:

- PRs must reference an existing issue.
- Prefer bug fixes, environment quirks, missing standard behavior, perf work, and docs.
- Avoid net-new feature work unless the maintainers have already approved the design direction.
- Keep PRs small and focused.
- Explain how the change was verified.
- Do not write long AI-looking issue or PR descriptions.

When choosing work, bias toward:

- Existing open issues
- Unassigned issues
- Small scope with clear repro
- High user impact
- Low design ambiguity

Before approving a candidate, run a contribution viability check.

The issue is viable only if all of these are true:

- There is an existing open issue
- No open PR already covers the same issue or fix area
- Issue comments do not show that maintainers already redirected or blocked the approach
- The likely diff is still small and reviewable
- The issue still looks worth maintainer time relative to other options

If any of those fail, do not start coding. Tell the user why and either pick another issue or suggest commenting first.

## Step 5: Triage issues with `gh`

Use `gh` to inspect open issues, labels, assignees, comments, and recency.

Read the issue comments before deciding to work on the issue. Do not rely on the title and body alone.

Before choosing an issue or starting implementation, check whether there is already an open PR for that issue or for the same fix area.

At minimum:

- Search open PRs that reference the issue number in the title or body
- Search open PRs by the relevant subsystem, tool, or error terms
- Inspect issue comments for "I'm working on this" signals when present

If an open PR already covers the same issue or substantially overlaps the same fix, stop and tell the user before doing implementation work or opening another PR.

If there is overlap but the existing PR looks incomplete or questionable, do not open a competing PR by default. Prefer one of these paths:

1. Comment on the existing PR with a useful implementation note.
2. Test the existing PR locally and report findings.
3. Pick a different issue.

Do not assume that the absence of an assignee means the issue is free.

Also inspect related merged PRs and recently closed PRs in the same area.

- Merged PRs show accepted scope and tone.
- Closed PRs often show what maintainers rejected or considered duplicate.

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
5. Why this is worth maintainer review time compared with nearby issues.

## Step 6: Inspect prior PRs before drafting

Before drafting a PR title or body, inspect recently merged opencode PRs with `gh`.

Learn the real local style instead of using generic PR language.

Observed style to preserve:

- Titles are short and conventional: `fix:`, `fix(scope):`, `refactor:`, `test:`, `tweak:`.
- Bodies are often very short.
- Many PRs use either:
  - `Fixes #123`, or
  - a short `## Summary` and `## Verification` section.
- The tone is plain, factual, and compact.

Also inspect recently closed PRs when they are related to the same subsystem or issue pattern. They often show duplicate work, rejected scope, or approaches maintainers did not want.

Do not write theatrical explanations, long narratives, or AI-sounding filler.

## Step 7: Implement like a good repo citizen

After an issue is chosen:

1. Run an environment preflight before writing code.
2. Create a branch prefixed with the issue number.
3. Re-run the duplicate PR check before writing code if issue triage happened earlier in the session.
4. Make the smallest correct change.
5. Follow the repo coding style.
6. Add or extend regression coverage where it helps lock in the fix.
7. Run targeted verification from the correct package directory.

Keep changes narrow. Do not refactor unrelated code just because it is nearby.

The environment preflight should check the practical blockers that can waste time late in the flow:

- Required Bun version from `package.json`
- `gh` auth works
- Expected remotes are present
- Repo hooks can run with current tool versions

## Step 8: Verification expectations

For OpenCode, verify from package directories, not the repo root.

Prefer the smallest meaningful verification set that proves the fix:

- targeted `bun test ...`
- `bun typecheck`
- any package-specific build or reproduction step if relevant

If the environment blocks verification, say exactly what failed and whether it is a local toolchain issue or a code issue.

Before pushing or opening a PR, confirm that the required local hooks and verification steps pass.

## Step 9: Draft PR text in OpenCode style

The PR title must follow conventional commit style.

Before drafting the PR body, read the current repo template from `.github/pull_request_template.md` in the active opencode checkout.

Before creating the PR, run one final duplicate check against open PRs for the issue number and the same fix area.

If a duplicate exists, stop and tell the user instead of opening a competing PR.

If maintainer comments or issue discussion make the direction uncertain, prefer commenting first instead of opening a speculative PR.

Do not hardcode a private PR template into this skill. The repo template can change, and the live file in the checkout is the source of truth.

The PR body must use that template while still staying concise and human.

When filling the template:

- Keep every answer short.
- Remove AI-sounding filler.
- Keep the issue reference explicit.
- State the root problem and fix plainly.
- List exact verification commands.
- Leave screenshots minimal or blank when the change is not UI-related.

Fill every required section from the live template and keep the answers brief.

If the template changes, follow the live file rather than any prior memory of the repo.

Do not ignore required template sections just because some older merged PRs were shorter.

Use the live repo template, not a remembered copy, and keep each section brief and human.

Do not mechanically fill every template section with fluff. If a section does not add value, keep it minimal.

Good PR writing rules:

- Lead with the issue link.
- State the root problem plainly.
- State the fix plainly.
- List concrete verification commands.
- Match the tone of recently merged opencode PRs, not generic OSS boilerplate.
- Keep it short enough that a maintainer can skim it in seconds.
- Prefer plain sentences over bullet spam in the explanation section when one short paragraph is enough.

Bad PR writing patterns:

- Long prose blocks
- Generic AI summaries
- Inflated claims
- Repeating obvious diffs in paragraph form

## Step 10: Default behavior

Unless the user asks to stop earlier, carry the workflow through end to end:

1. Repo check
2. Worktree check
3. Sync
4. Issue triage
5. Viability check
6. Implementation
7. Verification
8. Branch/commit guidance
9. PR draft

Only stop early when the user wants discussion only, or when blocked by missing information, an unsafe operation, unfinished local work that requires a user decision, or a viability check that fails.

## Communication style

- Be direct.
- Be brief.
- Sound like a contributor, not a bot writing marketing copy.
- When recommending an issue, explain the tradeoff clearly.
- When drafting PR text, keep it terse and natural.

## Final checklist

Before finishing, confirm all of these are true:

- Current repo is opencode or the user's opencode fork.
- Existing issue is linked.
- Issue comments were read.
- No open duplicate PR already covers the same issue or fix area.
- No maintainer comments suggest the approach is unwanted or outdated.
- Change is small and aligned with contribution rules.
- The issue is worth maintainer review time.
- Local toolchain and hooks were checked before push.
- Verification ran from the correct package directory.
- PR title matches repo style.
- PR body is short and does not read like AI-generated filler.
