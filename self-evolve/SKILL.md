---
name: self-evolve
description: "Reflect on the current session and propose durable improvements to any skills that would benefit from what was learned. Trigger whenever the user says `self evolve`, `self-evolve`, `/self-evolve`, `reflect on this chat`, `what did you learn`, `any skills to improve`, `anything to bake back into the skills`, `upgrade your skills`, or otherwise asks the agent to turn session experience into concrete skill edits. This is an experiential audit — it looks at what actually happened in this conversation (skills that were invoked, skills that should have been but were not, user corrections that revealed unwritten rules, mid-session patches that suggest repeatable failure modes, almost-skipped steps) and proposes edits to the skills that would prevent those failures next time. Do not invoke at the start of a conversation — there is nothing to reflect on yet. Best used after substantial work, or when the user has pushed back on behavior multiple times. Always proposes and waits for user sign-off; never silently edits. Works from any directory: all paths in this skill are absolute. Agent-agnostic: runs in any runtime that can read and edit local files."
install_mode: materialize
---

## Canonical paths

This skill works from any directory, because the installer expands every path below to an absolute location at install time:

- Skills repo root: `__SKILLS_REPO_ROOT__`
- Third-party upstream clones: `__SKILLS_REPO_ROOT__/.external/`
- Third-party config: `__SKILLS_REPO_ROOT__/skills.json`
- Installer: `__SKILLS_REPO_ROOT__/install.sh`
- README index of repo-backed skills: `__SKILLS_REPO_ROOT__/README.md`
- Installed skill targets: `__AGENTS_SKILLS_DIR__` and `__CLAUDE_SKILLS_DIR__`

When you need to read, edit, or reason about any skill in this repo, use the absolute path — do not rely on the current working directory being the repo root.

# Self-Evolve

An experiential skill. Its job is to take the raw material of the current conversation — what you tried, what the user corrected, what you almost skipped, what almost worked — and turn it into concrete, durable improvements to the skills that you and future agents will invoke next time.

This is the skill that saves you from re-learning the same lesson twice.

## Skills, not memory — the one rule that matters most

The entire point of self-evolution is producing guidance that *travels*. A skill edit lives in a file that every agent in every runtime can read the next time they need it — Claude Code, Codex CLI, or any other tool that indexes skills from `__AGENTS_SKILLS_DIR__` or `__CLAUDE_SKILLS_DIR__`. A memory entry, by contrast, is trapped inside the memory system of the single runtime that wrote it. A lesson saved to memory by one agent is invisible to every other agent on the same machine, so the next time the user switches tools (whether by choice or because of a rate limit), the lesson is gone.

This has three practical consequences for how you run this skill:

1. **Do not save reflection findings to memory.** If you notice a pattern worth capturing, the output must be a skill edit — either to an existing skill or as a new one — not a `user` / `feedback` / `project` memory entry. The memory system has its own legitimate uses (personal facts about the user, ephemeral project context, preferences the user asked you to remember); those uses are orthogonal to self-evolution and should not be confused with it.

2. **If a lesson feels like it belongs in memory, that is usually a signal it is a one-off**, not a durable pattern. Genuinely durable, cross-session, cross-agent rules earn a place in a skill. Session-local observations belong in memory or in the conversation itself, and do not need a skill edit at all.

3. **Do not treat memory as a fallback when a skill edit feels too heavy.** The cost of a skill edit — articulating the rule, exposing it to the user for approval, committing it to a file other agents will read — is the whole point. Skipping that rigor by stashing the lesson in memory undermines the entire feedback loop that makes self-evolution worth running.

The practical framing, the one sentence to keep in your head: *if the same correction would help a different agent on a different day, it belongs in a skill.*

## When not to use this

At the start of a conversation, this skill has nothing to work with. If invoked before any meaningful work has happened, say so plainly and stop:

> There is nothing to reflect on yet — no skills have been invoked, no corrections given, no patterns observed. Come back after we have done some real work together.

Also skip if the session was short and uneventful. One or two straightforward turns with no surprises is not material for rule changes. Forcing a reflection in that case produces cargo-cult edits — rules that do not earn their keep and quietly degrade the skills they are added to.

Good signals that there IS something to work with:

- The user corrected your behavior at least once and the correction would apply to future sessions, not just this one
- You patched your own mistake mid-session (a stale reference, a wrong path, a missed convention, a manual step the tooling already handles)
- A skill was invoked and felt off — too heavy, too light, missing the point of the task
- A skill that would have helped was not invoked (undertriggering is the known default failure mode of skill dispatch)
- You almost skipped a step that you now realize should have been a hard gate
- The user said "from now on" or "whenever X" about anything

## Required reading before proposing any edits

If any of your proposals would touch the prose body of a SKILL.md in this repository, you must follow the hard-gate reading step from `repo-skill-creator`'s "Required reading before drafting" section — that is, read `skill-creator`'s SKILL.md in the current session before drafting new prose. Self-evolve does not exempt you from that gate; it is the thing that *triggers* skill edits, not a bypass around their conventions.

If your only proposals are trivial prose-free edits (fixing a stale reference, flipping a frontmatter flag, updating a path that moved), you may skip the reading — but say so explicitly in your proposal so the user can push back if they disagree.

## Reflection process

### 1. Inventory the session

Before proposing anything, write out a concrete inventory. Do not try to hold this in your head — the user needs to see what you are basing your proposals on, and you need the forcing function of actually enumerating the evidence.

Walk through each of these buckets and list what you find in this session:

- **Skills that were invoked.** For each: did it help? Did you follow its instructions faithfully or deviate? Did you skip any of its steps? Did the user push back on its output? Did you hit a part of the skill that felt unclear, brittle, or out of date?
- **Skills that would have helped but were not invoked.** These are the hardest to see because they did not happen. Scan for moments where you fumbled something that a known skill handles — writing a SKILL.md without consulting `skill-creator`, interacting with a service when a wrapper skill could have handled auth, formatting a document when a dedicated skill existed, etc.
- **User corrections.** Every `no, do X instead`, every `you're overcomplicating`, every `don't do Y`, every `from now on`. For each, ask: what unwritten rule did the correction imply?
- **Mid-session patches.** Did you rename something and have to fix references afterward? Undo a manual action that the tooling would have done automatically? Fix a stale reference? Each patch is evidence of a convention that is not yet written down — or is written but not enforced.
- **Almost-skipped steps.** Did you feel the pull to skip a hard gate, a confirmation, a read? If the instinct was strong enough that you noticed it, the gate is not strong enough.

Be honest in this inventory. Padding it with trivialities wastes the user's time; leaving out mistakes you are embarrassed by defeats the purpose.

### 2. Classify each finding

Not every lesson becomes a skill edit. For each item in the inventory, ask four questions:

1. **Is this a one-off, or a repeatable pattern?** One-offs belong in memory or feedback files, not in skill bodies. Only genuinely repeatable failure modes deserve rule changes. If you cannot picture the same mistake happening again in a different session, it is probably a one-off.

2. **Does a rule for this already exist somewhere?** If yes and you violated it, the fix is usually to strengthen the existing rule — make it a hard gate, add an explanation of *why*, move it earlier in the workflow — not to add a new rule alongside it. Duplicated rules rot out of sync.

3. **Which skill does it belong in?** A lesson about how to write any SKILL.md belongs in `repo-skill-creator`'s house rules. A lesson about a specific domain skill belongs in that skill. A lesson that spans multiple skills or is about reflection itself might belong here in self-evolve, or in a new meta-skill.

4. **Is it worth the cost?** Every rule you add is context that every future agent has to read and follow. Spurious rules degrade the skill by diluting the sharp ones. Err on the side of fewer, sharper rules.

### 3. Propose, do not edit

Present findings as a short, numbered list the user can accept or reject item by item. For each proposal, include:

- **The observation** — what concretely happened in this session
- **The proposed change** — which skill, which section, what rough text
- **The reasoning** — why this is a pattern worth codifying, not a one-off
- **An opt-out** — the user can reject any single item without killing the others

Then wait for the user's decision. Do not start editing until they have reviewed.

If the user rejects a proposal, drop it cleanly and move on. Do not argue. The user's judgment about whether something is a pattern is usually better than yours because they see across sessions you do not.

### 4. Execute approved changes via `repo-skill-creator`

For each proposal the user accepts, use the standard `repo-skill-creator` workflow to actually make the edit. That means following its required-reading gate, its house rules, its reinstall step, and its self-audit checklist. Self-evolve is the sensor; `repo-skill-creator` is the hands.

If any proposal would touch a third-party skill (cloned under `__SKILLS_REPO_ROOT__/.external/` from an upstream repo listed in `__SKILLS_REPO_ROOT__/skills.json`), do not edit it directly — those files are managed by the installer and overwritten on refresh. Propose the change as a PR to the upstream repo instead, or encode the workaround as a local override in this repo's conventions (for example, a `skill_overrides` entry in `__SKILLS_REPO_ROOT__/skills.json`).

### 5. Report what changed

When the edits are done, summarize concisely:

- Which skills changed and what sections
- Which proposals were dropped (by user rejection or by your own second-pass judgment)
- If the session had a broader theme — e.g. "most of the lessons were about premature optimization" or "almost every correction was about verbosity" — name it in one line

A good closing report gives the user confidence that the next conversation starts on firmer ground than this one did.

## When the honest answer is "nothing"

If your inventory is sparse, or every finding turns out on second look to be a one-off, say so and stop. A reflection that concludes with *no durable lessons this session* is a legitimate and valuable outcome. Inventing changes to look productive is the failure mode this skill is designed to prevent in itself, not just in others.

The shape of a good "nothing" report is short: what you checked, why none of it rose to the level of a rule change, and one sentence about what you would need to see in a future session to reconsider.

## Interaction with other skills

- **`repo-skill-creator`** is the mechanism you use to actually apply approved edits. The calling direction is self-evolve → repo-skill-creator: self-evolve decides *what* should change, repo-skill-creator knows *how* to write it into this repo (paths, conventions, installer, README). Do not expect repo-skill-creator to trigger reflection on its own; invoke self-evolve explicitly when you want reflection to happen.
- **`skill-creator`** defines the writing conventions any proposed edit must respect. Read it in the current session before drafting any new prose, per the hard gate above.
- **Third-party skills** (anything under `__SKILLS_REPO_ROOT__/.external/` cloned from an upstream repo) are read-only from this repo's perspective. Do not propose in-place edits to them; propose upstream PRs or local overrides instead.

## A note on self-application

This skill is itself a skill, and is itself subject to self-evolution. If in the course of running self-evolve you notice that self-evolve's own instructions led you astray — too rigid, too loose, missing a bucket in the inventory, producing too many false positives — propose the fix to self-evolve the same way you would propose any other. The meta-skill evolving through its own application is the whole point.
