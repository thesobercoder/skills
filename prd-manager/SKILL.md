---
name: prd-manager
description: "Manage the lifecycle of a PRD-shaped work session from first brainstorm to child issues, using a single GitHub issue as durable state. Trigger whenever the user says `/prd-manager`, `manage the PRD`, `checkpoint this PRD`, `save PRD progress`, `resume the PRD`, `what PRD are we on`, or asks to hand off a grill-me / write-a-prd / prd-to-issues session between agents or across rate limits. The skill is a thin glue layer over the upstream grill-me, write-a-prd, and prd-to-issues skills (from mattpocock/skills) — it does not replace them, it routes between them based on the phase of the currently active PRD and writes checkpoints back to the same issue. Solo-dev assumption: exactly one active PRD at a time. Agent-agnostic: works in any CLI or agent with `gh` access."
---

# PRD Manager

A glue skill that makes the `grill-me → write-a-prd → prd-to-issues` pipeline resumable across sessions and across agents. It makes no assumptions about which CLI or agent is running it — anything with shell access and an authenticated `gh` can participate.

The skill does not own any of the three upstream skills — it orchestrates them. The durable state lives in **one GitHub issue**, identified by the label `prd:active`, whose phase is tracked with a second label. When the user invokes this skill, it either writes to that issue (checkpoint) or reads from it and routes to the right upstream skill (resume).

## Why this exists

The user brainstorms across long sessions — often dictating nuance via text-to-speech — and may switch between different agents or CLIs when one gets rate-limited or hits a context limit. Without a durable store, everything in the agent's context window dies with the session. This skill fixes that by pushing state to GitHub, which any agent with `gh` access can read, regardless of which tool or model is running.

**The single most important rule:** when writing state to the issue, **transcribe verbatim, do not summarize.** The user's phrasings, asides, dictated context dumps, and half-formed thoughts are the exact thing that would otherwise be lost. Paraphrasing defeats the purpose of the skill. If a section is long, it is long — do not shorten it.

## Preconditions

- `gh` is installed and authenticated (`gh auth status` should succeed).
- The current working directory is inside a GitHub-backed repository (`gh repo view` should succeed). If not, stop and tell the user.
- The upstream skills `grill-me`, `write-a-prd`, and `prd-to-issues` are expected to be available in the agent's skill index. They are sourced from `mattpocock/skills` and installed alongside this one. If any are missing, continue with prd-manager's own read/write behavior but warn the user that the routing step will be a no-op.

## State model

State lives entirely in GitHub labels on a single issue.

- **`prd:active`** — exactly one open issue should carry this label at a time. It is the current PRD.
- **Phase label** (exactly one of):
  - `prd:grilling` — still gathering context and resolving open questions (grill-me phase)
  - `prd:drafted` — grilling is done, formal PRD body has been written (write-a-prd phase is complete)
  - `prd:sliced` — child issues have been created from the PRD (prd-to-issues phase is complete)
  - `prd:complete` — all child issues are closed or the user has declared the PRD done

Create these labels in the repo on first run if they do not exist. Use `gh label create` with a sensible color (e.g. `#0366d6` for `prd:active`, progressive blues/greens for the phase labels). Do not fail if a label already exists — check first with `gh label list`.

## Invocation modes

The skill has two modes, determined by whether the agent already has a live working session in its context.

1. **Checkpoint mode** (mid-session save): the agent has been working with the user — grilling, drafting, discussing — and is now asked to persist what it has.
2. **Resume mode** (fresh-session load): the agent has no prior context for this PRD and is being asked to pick up where a previous session left off.

Decide between them by asking yourself: *do I have substantive in-context state about the user's current plan?* If yes, checkpoint. If no, resume. When genuinely ambiguous, ask the user one short question: `Are we checkpointing current progress, or resuming an earlier session?`

## Checkpoint mode

1. **Find or create the active issue.**
   - Run `gh issue list --label prd:active --state open --json number,title,body,labels`.
   - If exactly one result: that is the target issue.
   - If zero results: create a stub issue (see [Stub issue template](#stub-issue-template)) with labels `prd:active` and `prd:grilling`. Title should be a short description of what the user is currently working on — ask them for one if it is not obvious from context.
   - If more than one result: stop and tell the user. The invariant is one active PRD. Ask which issue to use and offer to remove `prd:active` from the others.

2. **Dump current understanding into the issue body, verbatim.**

   Fill the `<agent identifier>` placeholder below with whatever short name best identifies the runtime you are in (e.g. the CLI or harness name). If you genuinely do not know, use `unknown-agent`. This is for human traceability only — no code depends on the value.

   The issue has two possible shapes depending on phase:

   - **`prd:grilling`** — the body is a free-form session log. Append the current session's content to the existing body (do not replace). Structure the append as:
     ```
     ---

     ## Session checkpoint — <ISO-8601 timestamp> (<agent identifier>)

     ### Context dump (verbatim)
     <everything the user has told you in this session that informs the plan — dictated prose, design reasoning, constraints, reversals, examples. Do not summarize. Paste their own words where possible. This section can and should be long.>

     ### Resolved decisions
     <bullet list of decisions the user has committed to, with enough context that a future agent understands *why*, not just *what*>

     ### Open questions
     <the questions the model was about to ask the user, or that the model itself is unresolved on. One per line. These drive the next grilling session.>
     ```

   - **`prd:drafted`** — the body is the formal PRD (from write-a-prd). Do not overwrite the PRD sections. Append a `## Session checkpoint` block *above* the formal PRD, containing just resolved decisions and open questions from this session, so the formal PRD remains canonical.

   - **`prd:sliced`** or **`prd:complete`** — there should not normally be anything to checkpoint. If the user is invoking checkpoint in these phases, ask what they intended. They may want to reopen the PRD or work a specific child issue instead.

3. **Update labels if the phase should advance.**
   - If all open questions have been resolved and the user asks to graduate to drafting, move from `prd:grilling` → `prd:drafted` (this is write-a-prd's job; checkpoint just makes sure the label matches reality after write-a-prd runs).
   - Do not advance labels automatically without user confirmation.

4. **Report back concisely.** Give the user the issue number, the phase, and a one-line summary of what was written. Example: `Checkpointed to #42 (prd:grilling) — added 3 resolved decisions, 2 new open questions.`

## Resume mode

1. **Find the active issue.**
   - Run `gh issue list --label prd:active --state open --json number,title,body,labels`.
   - If zero results: tell the user there is no active PRD and suggest starting fresh with `grill-me` or `write-a-prd`. Do not create a stub in resume mode — stubs are only for mid-session saves.
   - If more than one: stop and ask which to resume (same invariant-violation handling as checkpoint mode).

2. **Read the full issue body** (and comments, via `gh issue view <n> --comments`) into context. Do not skim. The nuance in those context dumps is the entire point.

3. **Infer the phase** from the phase label on the issue. If for some reason no phase label is present, default to `prd:grilling` and warn the user.

4. **Confirm with the user before routing.** Output exactly one line like:
   `Resuming #42 "<title>" — phase is prd:grilling with N open questions. Continue? (y to proceed, or tell me to do something else)`
   Wait for confirmation. Do not auto-route silently.

5. **Route to the right upstream skill.** On confirmation:
   - **`prd:grilling`** → follow the upstream `grill-me` skill's instructions, using the loaded issue body as the starting context. The open questions in the issue are the queue of things to grill the user about. Work through them one at a time, in grill-me's style. After each answered question, append a checkpoint to the issue (call back into this skill's checkpoint mode, or inline the same write logic).
   - **`prd:drafted`** → follow the upstream `write-a-prd` skill's instructions. The grilling is done and the user wants the formal PRD. write-a-prd should **update this same issue** with its formal template sections, not create a new issue. After write-a-prd completes, apply the `prd:drafted` label.
   - **`prd:sliced`** → follow the upstream `prd-to-issues` skill's instructions, passing it this issue number. After prd-to-issues completes, apply the `prd:sliced` label.
   - **`prd:complete`** → tell the user the PRD is done and suggest running the next-issue workflow (or picking a child issue manually via `gh issue list --label 'blocked by #<n>'` or similar).

## Stub issue template

When creating a fresh stub in checkpoint mode:

```
## Status

Active PRD for: <short description the user gave, or inferred from current session>

Started: <ISO-8601 timestamp> via <agent identifier>

## Session checkpoint — <ISO-8601 timestamp> (<agent identifier>)

### Context dump (verbatim)
<first session's verbatim dump>

### Resolved decisions
<bullet list, possibly empty>

### Open questions
<bullet list>

---

*Managed by the `prd-manager` skill. Do not close until the PRD is complete.*
```

Apply labels `prd:active` and `prd:grilling` at creation time.

## Error and invariant handling

- **Multiple issues with `prd:active`**: stop, list them, ask the user which to keep. Offer to remove the label from the others. Never silently pick one.
- **Missing labels in the repo**: create them on first run with `gh label create`. Do not fail if they already exist.
- **Not in a git repo or `gh` not authed**: stop immediately and tell the user. The whole skill assumes a GitHub issue as the durable store — if `gh` cannot reach one, there is nowhere legitimate to write, and trying to improvise (e.g. writing to a local file, using a different remote) would silently diverge from the next session's expectations and defeat the cross-agent handoff.
- **User invokes checkpoint in a phase where it does not make sense** (e.g. `prd:complete`): ask what they intended before writing anything.
- **Upstream skill missing**: if `grill-me`, `write-a-prd`, or `prd-to-issues` is not in the skill index, do the checkpoint/read work anyway and warn the user that routing will be manual.

## Verbatim transcription — a reminder

This rule is easy to forget mid-task, so it is worth repeating: when writing to the issue, the agent's instinct will be to tidy, compress, and summarize the user's words. **Resist that instinct.** The user dictates via TTS and the texture of their phrasing carries information the structure does not. Preserve it. If a context dump is 400 words of rambling, write 400 words of rambling. The issue body is allowed to be long. GitHub has no meaningful length limit on issue bodies at this scale and the user will never be hurt by too much detail being preserved.

The tidied-up version belongs in the formal PRD sections that `write-a-prd` later produces. Until that phase, the issue body is a working log, not a publication.
