---
name: prd-hygiene
description: Normalize a PRD-derived GitHub backlog into a strict native GitHub graph so Ralph can follow it deterministically. Use immediately after `grill-me`, `write-a-prd`, and `prd-to-issues`, or whenever a repo has PRD/epic/task issues still held together by prose instead of native sub-issues and `blockedBy` links. Reach for this skill when the user wants Ralph to "just follow the graph", asks to clean up backlog hygiene, wants ordering or blockers wired correctly, or says the next task should be mechanically obvious even if they do not mention "hygiene" by name.
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
- create or fix native GitHub sub-issue links
- create or fix native GitHub `blockedBy` links
- make sibling order deterministic
- leave Ralph with one obvious next task unless the user explicitly wants parallelism

Do this work here instead of inside Ralph because backlog hygiene is repo surgery. Ralph is much more reliable when it can trust the graph instead of inventing one while it is supposed to be implementing code.

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

## Workflow

### 1. Identify the target PRD

Start by finding the PRD root.

Prefer, in order:

1. an explicit issue number the user gave you
2. one open issue already labeled `kind:prd`
3. one obvious PRD issue produced by the earlier workflow

If there are multiple plausible PRDs, ask one short question. Restructuring the wrong tree is much more expensive than asking once.

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

### 4. Build the native hierarchy

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

### 5. Normalize dependencies

Use native `blockedBy` links for real dependency edges.

Apply these rules by default:

- if an epic body already says `Blocked by #...`, mirror that relationship natively
- if tasks inside an epic should execute strictly one-by-one, add native `blockedBy` links between sibling tasks in order
- if a task or epic already has native blockers, preserve them unless they are clearly stale or wrong

The goal is not to maximize parallelism. The goal is to remove ambiguity. A slower but obvious graph is usually more valuable here than a theoretically optimal graph that forces the next agent to improvise.

If the user explicitly wants parallel branches, respect that. Otherwise, prefer a strict graph that yields one obvious next task.

### 6. Keep task bodies structurally compatible with Ralph

For each `kind:task` issue, make sure the body still contains these headers near the top:

- `## Parent PRD`
- `## Parent epic`

Why: Ralph now uses native hierarchy as the source of truth, but these headers are still valuable sanity checks and make a task readable when it is opened in isolation. They also prevent a clean native graph from drifting out of sync with the task template that Ralph expects.

If one or both headers are missing and you can repair them unambiguously from the native graph, repair them. If not, ask. The point is to keep each task readable in isolation as well as inside the graph.

### 7. Validate the result

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

If the graph is still ambiguous, do not pretend the hygiene pass succeeded. Report the ambiguity clearly so the next agent is not forced to rediscover it under execution pressure.

### 8. Report the next task

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

## Output checklist

Before you finish, make sure your reply states:

- what PRD you normalized
- what you changed in the graph
- whether the graph is now deterministic enough for Ralph
- what the next task is

If you cannot answer the last two confidently, the hygiene pass is not done.
