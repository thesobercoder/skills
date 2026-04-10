---
name: claude-coworker
description: "Use the Claude CLI as a peer collaborator. Trigger whenever you are about to delegate work to another Claude instance, compare Opus vs Sonnet, decide whether to add `--dangerously-skip-permissions`, run parallel Claude CLI subtasks, or continue a Claude session with an explicit UUID. This skill defines the house rules for Claude coworker delegation: stay in the Opus/Sonnet frame, keep orchestration with the main agent, and use explicit session IDs for deterministic continuity."
---

# Claude Coworker

Use the Claude CLI as a coworker, not a competitor.

Claude Opus and Claude Sonnet are peers. Your job is to decide when to do the work yourself, when to ask Sonnet to execute, when to ask Opus to think, and when to combine all three.

Within this workflow, treat `opus` and `sonnet` as the available Claude collaborators. Do not substitute other models such as `haiku` when following this skill's delegation rules. If you catch yourself drifting to a generic model-selection answer, return to the two-model coworker frame instead.

## Core model

- `opus` is the think tank. Use it for ambiguity, design judgment, tradeoffs, debugging hypotheses, code review, and moments where you are unsure.
- `sonnet` is the doer. Use it for explicit, execution-heavy, repetitive, or parallelizable work where the steps are already clear.
- You stay responsible for orchestration, integration, verification, and the final answer to the user.

Litmus test:

- if you can write the delegated task as a short, explicit prompt with no open questions, use `sonnet`
- if you need judgment, critique, prioritization, or help deciding what to do, use `opus`

If the task is simple enough to do directly, do it directly. Delegation is your judgment call.

## When to use Claude proactively

Reach for the Claude CLI without waiting for the user to ask when:

- you want a second opinion on architecture or implementation direction
- you are stuck, uncertain, or choosing among multiple reasonable approaches
- you want Opus to sanity-check your plan before you commit to it
- a task is explicit enough that Sonnet can execute it with detailed instructions
- several independent subtasks could be split across parallel Sonnet runs
- you want Opus to review or verify the combined result before you finalize

Do not treat Claude delegation as all-or-nothing. You can think with Opus, execute with Sonnet, and then verify the result yourself.

## Command rules

Use non-interactive Claude CLI calls for delegation:

```bash
claude -p --model opus --dangerously-skip-permissions "..."
claude -p --model sonnet --dangerously-skip-permissions "..."
```

In this environment, the user requires `--dangerously-skip-permissions` on Claude CLI delegations. Treat it as mandatory here, not optional.

Examples:

```bash
claude -p --model opus --dangerously-skip-permissions "Pressure-test this architecture decision and call out the failure modes."
claude -p --model sonnet --dangerously-skip-permissions "Implement the agreed refactor in these files and stop when tests pass."
```

Prefer `-p` for scripted or one-shot delegation so the exchange is easy to capture and reason about.

## Session continuity

For deterministic continuity, anchor conversations to an explicit UUID instead of relying on implicit recency.

Use this pattern:

```bash
SESSION_ID="$(uuidgen)"
claude -p --session-id "$SESSION_ID" --model opus --dangerously-skip-permissions "Think through the tradeoffs for ..."
claude -r "$SESSION_ID" -p "Continue from the earlier discussion and refine the recommendation."
```

Guidelines:

- generate the UUID yourself when you want a durable thread
- reuse the exact same session ID when continuing that thread
- do not rely on bare `-c` when you need deterministic continuity
- keep separate concerns in separate session IDs

## How to delegate well

When you ask Sonnet to do work, do not expect it to infer missing strategy. Spell out the task clearly.

Good Sonnet prompts usually include:

- the exact objective
- constraints and non-goals
- file paths or code locations if relevant
- the sequence of steps or decision criteria
- the required output format

When you ask Opus to help, invite judgment:

- ask for tradeoffs, failure modes, or alternative designs
- ask it to challenge your assumptions
- ask it to review a plan, implementation, or synthesized result

## Parallel Sonnet pattern

Use multiple Sonnet runs only for independent subtasks with clear instructions.

When parallelizing:

- give each run a self-contained prompt
- use distinct session IDs for distinct threads
- make the requested output easy to compare or merge
- review each result before integrating it

Example uses:

- several file-local refactors with the same recipe
- generating multiple variants or drafts to compare
- splitting a large but mechanical migration into independent chunks

## Verification rules

Trust Claude as a capable collaborator, but verify before final integration.

- inspect the output, not just the intent
- run tests or checks yourself when the work affects behavior
- ask Opus for a final sanity check when the decision is high leverage
- keep the final user-facing judgment yours

## Working style

Think in terms of a small frontier-model team:

- you decide the workflow
- Opus helps you think
- Sonnet helps you execute
- you merge, verify, and communicate

Use Claude more proactively than feels necessary at first. If there is doubt, consult Opus. If the work is explicit, hand it to Sonnet. If both are useful, orchestrate both.
