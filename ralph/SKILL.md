---
name: ralph
description: Pick one open GitHub issue, break it into the smallest actionable slice, implement that slice test-first via the `tdd` skill, verify it (including UI verification via `agent-browser` when relevant), commit with a `RALPH:` prefix, and close or update the issue — all in a single invocation with no looping. Trigger whenever the user says "ralph", "run ralph", "do a ralph pass", "grab the next issue", "work the next issue", "pick up a task", "grind an issue", "knock out a ticket", "take the next one off the backlog", or anything that implies "start from the issue list, do one unit of real work, commit it, and stop so I can review". Also trigger when the user asks to "work through issues manually" or wants a token-budget-conscious alternative to a continuous autonomous loop. Do not trigger for PRD writing (use `write-a-prd`), PRD decomposition (use `prd-to-issues`), bulk issue triage, or requests that explicitly want multiple issues handled in one session — ralph is deliberately one-issue-at-a-time.
---

# Ralph

A skill for running a single disciplined "work one issue" pass against a GitHub repo: list open issues, pick one, implement the smallest useful slice test-first, verify, commit, and update the issue. One invocation = one issue. Then stop and report.

Ralph is the manual, token-budget-conscious counterpart to continuous autonomous loops. The name and the core shape come from Matt Pocock's `ralph/once.sh` experiment — a shell script that feeds open issues plus recent `RALPH:` commits back into an agent and lets it pick up where it left off. This skill is the same idea without the shell wrapper, with hard rails added for TDD, PRD discipline, and one-at-a-time execution.

## Hard rules

- **Work one issue per invocation.** Do not loop. Do not start a second issue after finishing the first. When the user wants another pass, they will ask.
- **Skip issues that lack a `## Parent PRD` header at the top of the body.** Task issues produced by `prd-to-issues` always reference their parent PRD explicitly. Issues without that header are PRDs themselves or untyped scratch, and ralph does not guess.
- **Delegate implementation to the `tdd` skill.** Do not freestyle the test writing, do not write all tests up front, and do not write implementation first. Follow `tdd`'s red-green-refactor loop one tracer bullet at a time.
- **Commit only when every discovered feedback loop is green.** Fix failures, rerun, commit. Never commit red.
- **Halt and report after the commit and issue update.** Do not refactor "while in the area", do not pick another issue, do not restart TDD. Report and wait.

If the `tdd` skill is not installed, stop before writing implementation code and tell the user. If the `agent-browser` skill is not installed and the task is UI-facing, tell the user and let them decide whether to proceed without visual verification. If `gh` is not authenticated for the target repo, stop. Ralph runs do not half-happen.

## Workflow

### 1. Enumerate open issues

Run:

```bash
gh issue list --state open --json number,title,body,labels,comments
git log --grep='^RALPH:' -n 10 --format='%H %s'
```

Read the issues into context. Read the recent `RALPH:` commits — they show what previous passes already finished and reduce the risk of picking a task whose issue is stale.

### 2. Filter to eligible task issues

Drop every issue whose body does not contain a `## Parent PRD` header near the top. Keep the rest.

If zero issues remain, halt and tell the user:

> No eligible task issues — remaining open issues have no `## Parent PRD` header. Run `prd-to-issues` on the PRD to generate tasks, or link existing issues manually.

Do not fall back to "just pick the smallest-looking issue anyway".

### 3. Pick the next task

From the eligible set, pick the highest-priority item. Break ties by age, oldest first. Priority buckets, highest first:

1. **Critical bugfixes** — labelled `bug`/`critical`/`regression`, or bodies that describe a broken behavior blocking other work.
2. **Development infrastructure** — tests, types, CI, dev scripts, build tooling.
3. **Tracer bullets for new features** — the thinnest end-to-end slice of a new feature that exercises every layer.
4. **Polish and quick wins** — small visible improvements, low risk.
5. **Refactors** — last. Only worth it when unblocking a later task.

When the bucket is ambiguous, ask the user before picking. Do not invent a bucket to justify a favorite.

### 4. Reduce to the smallest useful unit

Read the chosen issue's body, comments, and acceptance criteria. Pick the smallest slice that:

- produces a visible outcome (a passing test, a working endpoint, a rendered component)
- can be validated by the repo's feedback loops
- is independently committable

When the whole issue fits one slice, take the whole issue. Otherwise, work only one slice this invocation and leave the rest as a comment on the issue for the next pass.

When exploration reveals the slice is actually much larger than it looked (hidden refactor, missing infra, cross-cutting change), stop, say so explicitly to the user, propose a smaller slice that still unblocks the original, and wait for confirmation. This is the "HANG ON A SECOND" moment from the original ralph prompt — be loud about it.

### 5. Explore the repo

Load the context you need for the change: related files, existing tests, relevant interfaces, the public API the change will touch. Stop exploring the moment you can describe the change in one sentence. Do not try to read every file in the repo.

### 6. Implement via the `tdd` skill

Invoke the `tdd` skill for the implementation phase. Follow its red-green-refactor loop one tracer bullet at a time: one failing test, one minimal implementation, one passing test, repeat.

When the task is pure infrastructure where tests are not the right primitive (wiring CI config, adding a dev script), skip the `tdd` handoff for that slice, say so explicitly in your reply, and describe the verification you will run in its place. Then run it.

### 7. Discover and run the feedback loops

Figure out how this specific repo verifies itself. Look wherever makes sense for this project: `CLAUDE.md`, `AGENTS.md`, `package.json` scripts, `Cargo.toml`, `pyproject.toml`, `Makefile`, `deno.json`, `go.mod`, existing CI configs. Collect every gate this repo treats as mandatory — tests, typecheck, lint, build, format — and run them.

When you find nothing that looks like a feedback loop, ask the user once:

> I did not find tests / typecheck / lint commands for this repo. What should I run before commit, or is there nothing?

Use the user's answer for this invocation only. Do not persist it.

When the task touches UI (pages, components, visual output), invoke the `agent-browser` skill for visual verification in addition to text-level tests. Start the dev server or confirm it is already running, navigate to the affected page, capture a screenshot, exercise the affected elements. Do not skip this because unit tests pass — a broken component with green unit tests is exactly what visual verification catches.

Fix every failure before committing. Do not commit until every discovered gate is green.

### 8. Commit with a `RALPH:` prefix

Use this commit message shape:

```
RALPH: <one-line summary of the slice>

Issue: #<number>
PRD: #<parent-prd-number>

Decisions:
- <key call you made while working>

Files:
- <path>
- <path>

Blockers / notes for next pass:
- <anything the next invocation should know, or "none">
```

Commit through the normal git hooks. Do not pass `--no-verify`.

### 9. Update the issue

When the slice closed the whole issue — every acceptance criterion ticked, nothing meaningful left — close it:

```bash
gh issue close <n> --comment "Closed by <commit-sha>. PRD #<parent>."
```

When the slice only made progress, leave a comment summarizing what was done, what is left, and anything the next pass needs to know:

```bash
gh issue comment <n> --body "..."
```

Do not close an issue that still has open acceptance criteria, even if the part you worked on is done.

### 10. Report and halt

Reply to the user with:

- the issue picked and the priority bucket it came from
- the slice actually implemented, and what was deferred
- the commit SHA and one-line summary
- the feedback loops that ran and their status
- whether the issue was closed or commented
- anything surprising: hidden scope, rejected paths, follow-ups worth filing

Then stop. Do not start another pass.

## Why these rules exist

**One issue per invocation.** The review checkpoint is the whole point. A continuous loop optimizes throughput but erodes the user's ability to catch a wrong turn early. Running ralph twice is cheap; running it wrong for an hour is not. Token budget is real but secondary — the primary benefit of the hard stop is review cadence.

**`## Parent PRD` as the task filter.** An earlier pass accidentally started work on a whole-product PRD issue and nearly implemented an entire app in one commit. The PRD header is a structural signal (not a content guess) and comes directly from `prd-to-issues`' output convention, so it is reliable across every repo that uses that workflow. Content-based heuristics ("the issue body looks like a PRD") are too fragile — they were tried first and failed.

**Delegate TDD to the `tdd` skill.** Red-green-refactor has specific failure modes — horizontal slicing, over-mocking, testing implementation details — and the `tdd` skill already encodes the corrections. Reimplementing them here would duplicate work and drift. The delegation keeps the TDD rules in one place.

**Delegate UI verification to `agent-browser`.** Browser automation has its own rules (dev server lifecycle, selector flakiness, evidence capture). The `agent-browser` skill owns them. Ralph decides *when* to verify visually; *how* is not ralph's job.

**No hardcoded feedback-loop commands.** Every repo is different. A hardcoded list of `npm run test` / `pytest` / `cargo test` goes stale the moment you cross runtimes. Telling the agent "figure out how this repo verifies itself" is both more general and more honest about what the agent is capable of.

**`RALPH:` commit prefix.** The next ralph pass greps for `^RALPH:` to reconstruct prior work. Break the prefix convention and future passes silently lose context.

## Common scenarios

**No issues have `## Parent PRD` headers, but there is real work to do.** Tell the user. Suggest running `prd-to-issues` on the parent PRD first, or linking manual task issues to their parent. Do not start on an untyped issue.

**The chosen slice turns out to be a refactor.** Stop, tell the user, propose a smaller refactor-free slice that still makes progress. Wait for confirmation before continuing.

**Feedback loops pass but the UI is visually broken.** That is why the `agent-browser` step exists. Run it. When the visual check fails, the commit does not land, regardless of what the unit tests say.

**The user asks for two issues in one pass.** Push back once: one issue per pass is the whole point, and running ralph twice is cheaper and safer than bending the rule. When the user confirms they really want two, agree, work the first issue fully (commit and close/comment), then start the second from scratch as if it were a new invocation. Do not interleave.

**The last `RALPH:` commit left a blocker note on a half-finished task.** Read the note. When the task is still the right next thing and the blocker is resolved, pick it up. When the blocker is still present, pick a different eligible task and leave the blocked one alone.

## Limitations

- **Single repo per invocation.** Ralph does not coordinate across repos. When the task spans repos, do the in-repo part and leave a comment describing the cross-repo follow-up.
- **Relies on the `## Parent PRD` convention.** Repos that do not use `prd-to-issues` (or an equivalent template) need the user to flag eligible issues manually, because the filter would otherwise exclude everything.
- **No autonomous looping.** Wrapping ralph in an external scheduler to make it continuous defeats the point of the hard stop. Do not patch that out.
- **`gh` CLI required.** Ralph's issue read/write path uses `gh`. Without authenticated `gh`, stop.
