---
name: ralph
description: Work one GitHub implementation task from a PRD-derived backlog, test-first, then stop for review. Use whenever the user says "ralph", "run ralph", "do a ralph pass", "grab the next issue", "work the next issue", "pick up a task", "grind an issue", "knock out a ticket", or asks for a token-budget-conscious one-issue pass instead of a continuous autonomous loop. This version expects a structured native GitHub hierarchy with `kind:prd`, `kind:epic`, and `kind:task`, plus native sub-issues and blocker links, and it uses that graph to pick the next task deterministically. Do not trigger for PRD writing (`write-a-prd`), PRD decomposition (`prd-to-issues`), bulk issue triage, or requests that explicitly want multiple issues handled in one session.
---

# Ralph

Use this skill for a single disciplined "work one task" pass against a GitHub repo: inspect the backlog graph, pick the next execution unit, implement the smallest useful slice test-first, verify it, commit it, push it, update GitHub, and stop.

Ralph is the manual, token-budget-conscious counterpart to continuous autonomous loops. The original shape came from Matt Pocock's `ralph/once.sh` experiment — feed the agent the issue set plus the recent `RALPH:` commits, let it do one unit of real work, then stop so a human can review. This version keeps that cadence but adds stricter PRD hierarchy rules, TDD discipline, and deterministic task selection.

## Hard rules

- **Work one `kind:task` issue per invocation.** The review checkpoint is the whole point, so stop after one real unit of work.
- **Treat `kind:task` as the execution unit.** `kind:epic` and `kind:prd` are rollups; when they still have open children, they should guide selection rather than become the thing you implement directly.
- **Trust the native GitHub graph first.** Use native sub-issues for hierarchy and order, and use native blockers for dependencies. If GitHub already knows the structure, do not replace it with improvised heuristics.
- **Treat malformed hierarchy as a blocker, not as an invitation to improvise.** If a `kind:task` lacks a parent epic, an epic lacks a parent PRD, a `kind:epic` has no child tasks, or a `kind:prd` has no child epics, stop and tell the user exactly what is broken.
- **Treat `kind:hitl` as opt-in.** Those tasks exist for moments when the user wants a human in the loop, not for silent autonomous pickup.
- **Keep `## Parent PRD` as a sanity check.** Native hierarchy is the source of truth, but the header keeps a task understandable when it is read on its own.
- **Delegate implementation to the `tdd` skill.** That keeps the red-green-refactor rules in one place instead of recreating them ad hoc inside Ralph.
- **Commit only when every discovered feedback loop is green.** Green feedback loops are the boundary between a useful pass and a misleading one.
- **Push after a successful commit.** A Ralph pass is not really complete until the resulting commit is on the remote branch the user will review.
- **Halt and report after the commit, push, and issue update.** Do not keep going just because there is more nearby work.

If the `tdd` skill is not installed, stop before writing implementation code and tell the user. If the `agent-browser` skill is not installed and the task is UI-facing, tell the user and let them decide whether to proceed without visual verification. If `gh` is not authenticated for the target repo, stop. Ralph is only useful when the whole loop can complete.

## Workflow

### 1. Enumerate the issue hierarchy

Run:

```bash
gh issue list --state open --json number,title,body,labels,comments
gh repo view --json nameWithOwner
git log --grep='^RALPH:' -n 10 --format='%H %s'
```

Then use `gh api graphql` with one stable query shape to fetch the native sub-issue tree for the open `kind:prd` issue(s): each PRD's ordered epic children and each epic's ordered task children, including labels, state, and native `blockedBy` relationships.

```bash
gh api graphql -f query='query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      number
      title
      state
      labels(first: 20) { nodes { name } }
      blockedBy(first: 100) { nodes { number title state } }
      subIssues(first: 100) {
        nodes {
          number
          title
          state
          labels(first: 20) { nodes { name } }
          blockedBy(first: 100) { nodes { number title state } }
        }
      }
    }
  }
}' -F owner=<owner> -F name=<repo> -F number=<prd-number>
```

Reusing one known-good query is better than inventing a new traversal every run, because the whole point of this version of Ralph is deterministic graph-following.

Read the open issues into context. Read the recent `RALPH:` commits too — they tell you what previous passes already finished and reduce the risk of picking a task whose issue state has drifted.

### 2. Validate and filter to eligible task issues

Use the hierarchy, labels, and headers together:

- Keep only open issues labelled `kind:task`.
- Require each task body to contain a `## Parent PRD` header near the top.
- Require each task to appear as a native child of a `kind:epic` issue.
- Require each epic to appear as a native child of a `kind:prd` issue.
- Require every open epic to have at least one child task.
- Require every open PRD to have at least one child epic.

If the tree is malformed, halt and tell the user exactly what is wrong. Tell them to run `prd-hygiene` to normalize the PRD/epic/task graph before trying Ralph again. Do not fall back to "just pick the smallest-looking issue anyway".

If zero eligible tasks remain, halt and tell the user:

> No eligible task issues — either there are no open `kind:task` issues, or the task/epic/PRD hierarchy is malformed. Run `prd-hygiene` to normalize the graph first.

### 3. Pick the next task

Traverse the backlog in native GitHub order, not by vibes:

1. Walk open `kind:prd` issues in their native sub-issue order.
2. Inside each PRD, walk open `kind:epic` children in their native order.
3. Before considering an epic eligible, inspect its native `blockedBy` issues. If any blocker issue is still open, skip that epic for this pass.
4. Inside the first eligible epic, walk open `kind:task` children in native order and pick the first one whose own native `blockedBy` issues are all closed.
5. If that task has the `kind:hitl` label, stop and ask the user whether they want to do that human-in-the-loop task now. If not, skip it and continue searching. If every remaining eligible task is `kind:hitl`, stop and report that.

If ordering data is missing or contradictory, stop and report the malformed backlog rather than improvising a priority rule. Determinism is more valuable here than cleverness.

### 4. Reduce to the smallest useful unit

Read the chosen issue's body, comments, and acceptance criteria. Pick the smallest slice that:

- produces a visible outcome (a passing test, a working endpoint, a rendered component)
- can be validated by the repo's feedback loops
- is independently committable

When the whole issue fits one slice, take the whole issue. Otherwise, work only one slice this invocation and leave the rest as a comment on the issue for the next pass. The point is to keep each pass independently committable and reviewable.

When exploration reveals the slice is actually much larger than it looked (hidden refactor, missing infra, cross-cutting change), stop, say so explicitly to the user, propose a smaller slice that still unblocks the original, and wait for confirmation. This is the "HANG ON A SECOND" moment from the original ralph prompt — be loud about it.

### 5. Explore the repo

Load the context you need for the change: related files, existing tests, relevant interfaces, the public API the change will touch. Stop exploring the moment you can describe the change in one sentence. Over-reading the repo burns time and tends to make slices look larger than they are.

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

### 8. Commit with a `RALPH:` prefix and push

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

After the commit succeeds, push the current branch.

- If the branch already has an upstream, use a normal `git push`.
- If it does not have an upstream but `origin` exists, use `git push -u origin HEAD`.
- If there is no usable remote, stop and tell the user before closing or commenting on the issue. The local commit can stay, but the Ralph pass should be reported as not fully published.

### 9. Update the issue and roll up the hierarchy

When the slice closed the whole task issue — every acceptance criterion ticked, nothing meaningful left — close it:

```bash
gh issue close <task> --comment "Closed by <commit-sha>. PRD #<parent-prd>."
```

When the slice only made progress, leave a comment summarizing what was done, what is left, and anything the next pass needs to know:

```bash
gh issue comment <task> --body "..."
```

Do not close a task that still has open acceptance criteria, even if the part you worked on is done. A clean partial-progress comment is better than a misleading closure.

When a task closes, immediately inspect its parent epic:

- If the epic still has any open child tasks, leave the epic open.
- If all child tasks are closed, close the parent epic with a rollup comment referencing the commit SHA and PRD.

Then inspect the parent PRD:

- If the PRD still has any open child epics, leave the PRD open.
- If all child epics are closed, close the PRD with a rollup comment referencing the commit SHA.

### 10. Report and halt

Reply to the user with:

- the task picked and where it sat in the PRD/epic/task hierarchy
- the slice actually implemented, and what was deferred
- the commit SHA, push result, and one-line summary
- the feedback loops that ran and their status
- whether the task was closed or commented, and whether the parent epic / PRD rolled up to closed
- anything surprising: hidden scope, rejected paths, follow-ups worth filing

Then stop. Do not start another pass.

## Why these rules exist

**One task per invocation.** The review checkpoint is the whole point. A continuous loop optimizes throughput but erodes the user's ability to catch a wrong turn early. Running Ralph twice is cheap; running it wrong for an hour is not. Token budget is real but secondary — the main benefit of the hard stop is review cadence.

**Native sub-issue hierarchy plus `kind:*` labels.** Earlier passes could still land on a whole PRD or epic and start slicing it ad hoc. The stricter model is: tasks are execution units, epics are rollups, PRDs are top-level rollups. Native GitHub sub-issues provide stable ordering, and `kind:task` / `kind:epic` / `kind:prd` make those roles explicit. The `## Parent PRD` header remains a sanity check, not the primary selector.

**Delegate TDD to the `tdd` skill.** Red-green-refactor has specific failure modes — horizontal slicing, over-mocking, testing implementation details — and the `tdd` skill already encodes the corrections. Reimplementing them here would duplicate work and drift. The delegation keeps the TDD rules in one place.

**Delegate UI verification to `agent-browser`.** Browser automation has its own rules (dev server lifecycle, selector flakiness, evidence capture). The `agent-browser` skill owns them. Ralph decides _when_ to verify visually; _how_ is not ralph's job.

**No hardcoded feedback-loop commands.** Every repo is different. A hardcoded list of `npm run test` / `pytest` / `cargo test` goes stale the moment you cross runtimes. Telling the agent "figure out how this repo verifies itself" is both more general and more honest about what the agent is capable of.

**`RALPH:` commit prefix.** The next ralph pass greps for `^RALPH:` to reconstruct prior work. Break the prefix convention and future passes silently lose context.

**Push after commit.** A local-only Ralph commit leaves the repo in an awkward half-published state: the issue may say the work is done, but the branch the user expects to review does not actually contain it yet. Pushing before the issue update keeps the GitHub issue, the branch, and the user's review flow aligned.

## Common scenarios

**The backlog tree is malformed.** If a task is missing its epic parent, an epic is missing its PRD parent, an epic has no child tasks, or a PRD has no child epics, stop and tell the user exactly what is broken. Tell them to run `prd-hygiene`, because this is backlog surgery rather than execution work. Do not guess or flatten the hierarchy yourself.

**The chosen slice turns out to be a refactor.** Stop, tell the user, propose a smaller refactor-free slice that still makes progress. Wait for confirmation before continuing.

**Feedback loops pass but the UI is visually broken.** That is why the `agent-browser` step exists. Run it. When the visual check fails, the commit does not land, regardless of what the unit tests say.

**The user asks for two issues in one pass.** Push back once: one issue per pass is the whole point, and running ralph twice is cheaper and safer than bending the rule. When the user confirms they really want two, agree, work the first issue fully (commit and close/comment), then start the second from scratch as if it were a new invocation. Do not interleave.

**The last `RALPH:` commit left a blocker note on a half-finished task.** Read the note. When the task is still the right next thing and its native blockers are resolved, pick it up. When the blocker is still present, pick a different eligible task and leave the blocked one alone.

**The commit succeeded but push failed.** Report the local commit SHA, the push error, and the exact point where the flow stopped. Do not pretend the pass completed normally, and do not close the task issue as if the work were fully published.

**The next task in order is `kind:hitl`.** Stop and ask the user whether they want to do that human-in-the-loop task now. Do not silently skip into a later task unless the user explicitly agrees.

## Limitations

- **Single repo per invocation.** Ralph does not coordinate across repos. When the task spans repos, do the in-repo part and leave a comment describing the cross-repo follow-up.
- **Relies on native sub-issues plus `kind:*` labels.** Repos that do not maintain that hierarchy will need manual triage before Ralph can pick deterministically.
- **No autonomous looping.** Wrapping ralph in an external scheduler to make it continuous defeats the point of the hard stop. Do not patch that out.
- **`gh` CLI required.** Ralph's issue read/write path uses `gh`. Without authenticated `gh`, stop.
