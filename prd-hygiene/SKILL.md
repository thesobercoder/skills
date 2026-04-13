---
name: prd-hygiene
description: Normalize a PRD-derived GitHub backlog into a strict native GitHub graph so Ralph can follow it deterministically. Audits every epic's acceptance criteria against its child tasks to find coverage gaps — AC items with no task are silent black holes that no agent will ever work on. Creates missing tasks, sharpens vague task AC, and wires everything with native sub-issues and `blockedBy` links. Use immediately after `grill-me`, `write-a-prd`, and `prd-to-issues`, or whenever a repo has PRD/epic/task issues still held together by prose instead of native links. Reach for this skill when the user wants Ralph to "just follow the graph", asks to clean up backlog hygiene, wants ordering or blockers wired correctly, mentions AC coverage gaps, or says the next task should be mechanically obvious even if they do not mention "hygiene" by name.
---

# PRD Hygiene

Use this as the fourth step in a PRD workflow. The earlier PRD skills create the plan and the issue set; this skill turns that issue set into an execution graph that Ralph can trust.

This skill assumes the earlier work already happened:

- `grill-me` captured the design decisions
- `write-a-prd` produced the PRD
- `prd-to-issues` produced the implementation issues

This skill does not replace those skills. It makes their output operational.

## What this skill owns

Use this skill to make the backlog operational:

- identify the target `kind:prd` issue
- classify issues as `kind:prd`, `kind:epic`, or `kind:task`
- audit AC-task coverage: verify every epic acceptance-criteria item is covered by at least one task
- create missing tasks for uncovered AC items and update existing tasks whose AC is too vague
- create or fix native GitHub sub-issue links
- create or fix native GitHub `blockedBy` links
- make sibling order deterministic
- leave Ralph with one obvious next task unless the user explicitly wants parallelism

Do this work here instead of inside Ralph because backlog hygiene is repo surgery. Ralph is much more reliable when it can trust the graph instead of inventing one while it is supposed to be implementing code.

The AC coverage audit is especially important because `prd-to-issues` can produce decompositions where the number of tasks under an epic is fewer than the number of AC items on that epic. When that happens, there are AC items that no agent will ever work on — silent black holes in the implementation plan. Ralph closes tasks and ticks their AC, but if an epic AC item has no corresponding task, nobody ticks it and nobody notices until the epic cannot be closed.

## Preconditions

Verify these before changing anything:

- `gh auth status` succeeds
- `gh repo view` succeeds for the current working directory
- the repo already has a PRD issue and decomposition issues, or the user explicitly wants you to classify existing issues into that hierarchy

If there is no usable PRD issue yet, stop and tell the user to finish the earlier workflow first. This skill is for normalization, not for inventing a plan from scratch.

## Default backlog model

Unless the user asks for a different structure, normalize the repo to this model:

- one `kind:prd` issue as the root for the current plan
- `kind:epic` issues as native sub-issues of the PRD
- `kind:task` issues as native sub-issues of exactly one epic
- native `blockedBy` links used for real dependency edges
- native sub-issue order used for sibling ordering

Aim for one practical outcome: when Ralph looks at the backlog, there should be one clear next task to pick.

## Labels

Ensure these labels exist:

- `kind:prd`
- `kind:epic`
- `kind:task`

If the repo already uses `kind:hitl`, preserve and honor it. Avoid adding extra labels unless the user explicitly asks for them; extra taxonomy usually makes the graph noisier, not clearer.

## Fast gh patterns

Prefer these `gh` patterns before inventing a search strategy from scratch. Reusing the same small set of commands makes the hygiene pass faster and reduces the chance of reading the graph inconsistently.

### Find the target PRD

Use this first when the repo already has a labeled root:

```bash
gh issue list --state open --label "kind:prd" --json number,title,url
```

If that returns nothing, infer the PRD from task bodies by reading the `## Parent PRD` header on open `kind:task` issues and collecting the referenced issue numbers. If they all point to one issue, that issue is the PRD root.

### Read one issue cleanly

Use this when you need the body, labels, and node ID in one place:

```bash
gh issue view <number> --json id,number,title,body,labels,url
```

### Fetch the native graph for one issue

Use this query shape when you want one issue plus its immediate native children and blockers:

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
}' -F owner=<owner> -F name=<repo> -F number=<issue-number>
```

This pattern is useful because it gives you enough structure to classify, validate, and order issues without scraping prose.

### List all open tasks quickly

Use this when you need a quick sanity check on the execution layer:

```bash
gh issue list --state open --label "kind:task" --json number,title,url
```

### Add a native sub-issue link

Get the parent node ID first:

```bash
gh issue view <parent-number> --json id --jq .id
```

Then attach the child by URL:

```bash
gh api graphql -f query='mutation($issueId: ID!, $subIssueUrl: String!) {
  addSubIssue(input: {issueId: $issueId, subIssueUrl: $subIssueUrl}) {
    issue { number }
    subIssue { number }
  }
}' -F issueId=<parent-node-id> -F subIssueUrl=<child-issue-url>
```

Using the child URL is often simpler than threading multiple node IDs around.

### Add a native blocker edge

Get both node IDs:

```bash
gh issue view <issue-number> --json id --jq .id
gh issue view <blocking-number> --json id --jq .id
```

Then add the edge:

```bash
gh api graphql -f query='mutation($issueId: ID!, $blockingIssueId: ID!) {
  addBlockedBy(input: {issueId: $issueId, blockingIssueId: $blockingIssueId}) {
    issue { number }
  }
}' -F issueId=<issue-node-id> -F blockingIssueId=<blocking-node-id>
```

Use native blocker edges for real dependencies so later agents can query the graph directly instead of reverse-engineering it from body text.

## Workflow

### 1. Identify the target PRD

Start by finding the PRD root.

Prefer, in order:

1. an explicit issue number the user gave you
2. one open issue already labeled `kind:prd`
3. one unique PRD number inferred from the `## Parent PRD` headers on open `kind:task` issues

If there are multiple plausible PRDs, ask one short question. Restructuring the wrong tree is much more expensive than asking once.

If no `kind:prd` label exists yet but the root is otherwise clear, that is fine. This skill should classify the root issue and add `kind:prd` as part of the normalization pass. The purpose of the discovery step is to find the PRD reliably, not to require that earlier skills already labeled it.

### 2. Read the current graph

Read the issue set before editing it.

At minimum, inspect:

- the target PRD issue
- candidate epic issues
- candidate task issues
- existing labels
- existing native sub-issue links
- existing native `blockedBy` links

Treat native GitHub data as the source of truth when it exists. Body text is still useful context, but it should not be asked to carry structural meaning that GitHub can already encode natively.

### 3. Classify issues

Normalize the issue kinds:

- the PRD root gets `kind:prd`
- parent feature slices get `kind:epic`
- pickup-sized work items get `kind:task`

If an issue's role is ambiguous, ask instead of guessing. A wrong classification poisons the whole tree and pushes the ambiguity downstream into every later run.

### 4. Audit AC-task coverage

This step catches the most damaging class of decomposition error: epic AC items that have no corresponding task. Without this audit, an agent can complete every task under an epic and still leave the epic's AC unfulfilled.

For every epic, read its body and extract each AC checkbox item. Then read the body of every task under that epic and map each task's AC back to the epic's AC. Classify each epic AC item as one of:

- **Covered** — a task exists whose AC clearly addresses this item
- **Partial gap** — a task exists but its AC is vaguer or narrower than the epic demands (e.g. the epic says "60fps" but the task says "smooth")
- **Full gap** — no task addresses this item at all

This audit is the most time-consuming step in the hygiene pass but also the most valuable. Use parallel subagents when the epic count is large — batch epics into groups and audit them concurrently.

#### Fixing full gaps

For each full gap, create a new `kind:task` issue. Follow the same body template as existing tasks in the repo (`## Parent PRD`, `## Parent epic`, `## Acceptance criteria`, etc.). Write AC items that are specific enough for an agent to implement and verify without reading the parent epic — the whole point is that the task should be self-contained.

Group related gaps into a single task when they are small and tightly coupled (e.g. two security checks that belong in the same test). Split them when they represent distinct units of work. Use judgment, but err toward one-task-per-gap when unsure — a task that does one thing is easier for Ralph to pick up than a task that does three unrelated things.

#### Fixing partial gaps

For each partial gap, update the existing task body to include the missing specificity. Add the concrete values, thresholds, or behavioral details from the epic AC that the task currently omits. Append a `## Hygiene notes` section at the bottom explaining what was added and why, so future readers can distinguish original AC from hygiene-added AC.

Preserve all existing content when updating a task body. The update is additive — add new AC checkboxes, do not rewrite or remove existing ones.

#### Wiring new tasks into the graph

After creating new tasks, wire them into the native hierarchy immediately — do not defer this to a later step. For each new task:

1. Add it as a native sub-issue of its parent epic
2. Add a `blockedBy` link to the last existing task in the epic's chain (so the new task comes after the original work)
3. If multiple new tasks were created for the same epic, chain them with `blockedBy` links in logical order

This keeps the graph deterministic at every point during the hygiene pass. A new task that is not wired is invisible to Ralph.

### 5. Build the native hierarchy

Make the hierarchy explicit with native GitHub sub-issues:

- attach each epic under the PRD
- attach each task under exactly one epic

Preserve existing native order when it already exists.

If no native order exists yet, use the most stable explicit ordering signal available:

1. current native order if present
2. user-specified order
3. issue order already implied by the decomposition output
4. issue number as a fallback

Do not leave sibling ordering implicit if Ralph is expected to walk the graph deterministically. If GitHub has an order, use it. If it does not, create one intentionally.

### 6. Normalize dependencies

Use native `blockedBy` links for real dependency edges.

Apply these rules by default:

- if an epic body already says `Blocked by #...`, mirror that relationship natively
- if tasks inside an epic should execute strictly one-by-one, add native `blockedBy` links between sibling tasks in order
- if a task or epic already has native blockers, preserve them unless they are clearly stale or wrong

The goal is not to maximize parallelism. The goal is to remove ambiguity. A slower but obvious graph is usually more valuable here than a theoretically optimal graph that forces the next agent to improvise.

If the user explicitly wants parallel branches, respect that. Otherwise, prefer a strict graph that yields one obvious next task.

### 7. Keep task bodies structurally compatible with Ralph

For each `kind:task` issue, make sure the body still contains these headers near the top:

- `## Parent PRD`
- `## Parent epic`

Why: Ralph now uses native hierarchy as the source of truth, but these headers are still valuable sanity checks and make a task readable when it is opened in isolation. They also prevent a clean native graph from drifting out of sync with the task template that Ralph expects.

If one or both headers are missing and you can repair them unambiguously from the native graph, repair them. If not, ask. The point is to keep each task readable in isolation as well as inside the graph.

### 8. Validate the result

Before you stop, verify the graph mechanically.

Check for these failure modes:

- a task without an epic parent
- an epic without a PRD parent
- an epic with no child tasks
- a PRD with no child epics
- duplicate placement of one task under multiple epics
- native blockers that point the wrong direction
- task bodies whose `## Parent PRD` / `## Parent epic` headers disagree with the native graph
- multiple equally eligible next tasks when the user wanted a strict queue
- an epic AC item with no corresponding task (full gap — should have been caught in step 4)
- a task whose AC is vaguer than its parent epic's AC on the same topic (partial gap)
- a new task created during the hygiene pass that was not wired into the native graph
- a closed epic whose tasks are all closed but whose AC is not fully covered (indicates the epic was closed prematurely or tasks were completed without fulfilling all AC)

If the graph is still ambiguous, do not pretend the hygiene pass succeeded. Report the ambiguity clearly so the next agent is not forced to rediscover it under execution pressure.

### 9. Report the next task

End with a short execution-facing summary:

- target PRD issue
- epics linked or relinked
- tasks linked or relinked
- blocker edges added, removed, or corrected
- malformed issues fixed or still unresolved
- the exact next task Ralph should pick now

That final line is the whole reason this skill exists.

## Communication

Keep the user-facing summary concrete.

Good:

- `Linked PRD #1 to 23 epics and wired 69 tasks under them.`
- `Converted textual blockers into native blockedBy edges for epics and task chains.`
- `Ralph's next task is #25.`

Bad:

- `Cleaned up the backlog.`

The user wants to know whether the graph is now trustworthy, not whether you felt productive.

## Safety rules

- Do not relabel or reparent issues casually when multiple interpretations are plausible. A single wrong move can invalidate the whole tree.
- Do not silently flatten the hierarchy because it feels simpler. Simpler for this moment can mean much more ambiguous for every later pass.
- Do not invent extra labels when the repo already committed to a smaller taxonomy. Hygiene should reduce ambiguity, not add a second classification system.
- Do not rely on prose `Blocked by` notes when you can encode the relationship natively. Native edges are easier to query, easier to trust, and much harder to misread.
- Do not leave both the native graph and the prose graph disagreeing without calling it out. When two sources disagree, the next agent has no reason to trust either one.

## Common scenarios

### The repo already has PRD, epic, and task labels, but no native links

Add the native sub-issue links first, then normalize blockers. The hierarchy should come before the dependency polish because the blockers only make sense once parentage is clear.

### The repo has native sub-issue links, but no clear next task

Inspect sibling order and native blockers. If multiple tasks are simultaneously eligible and the user wants Ralph to follow one path, add the missing blockers or ask the user to choose the intended order.

### The repo still only has a PRD and no tasks

Stop and tell the user this skill is too early. They need `prd-to-issues` first because there is nothing execution-shaped to normalize yet.

### The repo has an epic with no child tasks

Treat that as malformed backlog. Do not let Ralph pick the epic directly. An epic without tasks is a planning problem, not an execution target.

### The native graph is correct, but task headers are stale or incomplete

Repair the headers from the native graph when the mapping is unambiguous. This is exactly the kind of drift this skill is supposed to fix.

### The user wants parallel work, not a single strict lane

Respect that, but say so explicitly in the final report. The point of this skill is clarity, not always serial execution.

### An epic has more AC items than tasks

This is the most common decomposition failure. Read the epic body and count AC checkbox items, then count child tasks. If AC items outnumber tasks, some AC items are orphaned. Read every task body to confirm which AC items are actually covered — sometimes one task covers multiple AC items, sometimes it covers none precisely.

Create new tasks for full gaps. Update existing task bodies for partial gaps where the task exists but its AC language is vaguer than the epic demands (e.g. the epic says "16ms latency" but the task just says "fast"). Do not assume an implementer will read the epic — each task should be self-contained.

### A closed epic has AC gaps

If the epic is closed and all its child tasks are closed, but the AC audit reveals gaps, flag this as potential technical debt. The gaps may already be implemented (done as part of other tasks without tracking) or may be genuinely missing. Do not create tasks for closed epics without checking with the user first — reopening a closed epic changes the graph shape and may confuse downstream agents.

### Multiple epics share the same gap pattern

When the same type of gap appears across many epics (e.g. "security verification not covered," "cross-platform consistency not covered"), this indicates a systemic decomposition weakness rather than a one-off miss. Call out the pattern explicitly in the report so the user can decide whether to fix it structurally (e.g. by adding a cross-cutting epic) or per-epic.

## Output checklist

Before you finish, make sure your reply states:

- what PRD you normalized
- AC coverage audit results: how many epics audited, how many full gaps found, how many partial gaps found, how many new tasks created, how many existing tasks updated
- what you changed in the graph (links added, blockers wired, tasks created)
- whether the graph is now deterministic enough for Ralph
- any remaining gaps that could not be fixed without user input
- what the next task is

If you cannot answer the last two confidently, the hygiene pass is not done.
