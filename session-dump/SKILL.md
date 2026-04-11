---
name: session-dump
install_mode: materialize
description: "Extract planning/grilling session content from Claude Code and opencode into committed markdown transcripts inside a repository's `.sessions/` directory, one file per session, so that long design conversations survive context resets, tool switches, and rate limits. Trigger when the user says `dump the session`, `export this chat`, `save the transcript`, `checkpoint this planning session`, `commit the grilling`, `I don't want to lose this conversation`, `resume where we stopped yesterday`, `how do I get the opencode session into git`, or anything that implies they want a durable, reviewable, git-tracked copy of an agent chat that currently lives only inside Claude Code's `~/.claude/projects/` JSONL files or opencode's sqlite DB. Also trigger when the user is fixing an existing dump script that seems to only export one session (classic data-loss bug), or when they want to add a new runtime to an existing dump setup. Agent-agnostic: works from any CLI/agent with shell + Python, as long as the source agent (Claude Code and/or opencode) has produced session data on this machine."
---

# Session Dump

A skill for safely extracting conversation content from Claude Code and opencode into a repository's `.sessions/` directory as committed markdown transcripts — one file per session, named `<session-id>.md` — so that multi-session design work (grilling interviews, PRDs, checkpoint chains, cross-agent handoffs) can live in git instead of dying inside agent-private storage.

The skill bundles two Python scripts — one per source runtime. Each script is a pure argv-driven dumb tool: give it an output directory and a list of session IDs, it writes one `<session-id>.md` file per session into that directory. **No config file, no state on disk, no auto-detection, no concatenation.** Every invocation is a fresh explicit list. The agent running this skill is responsible for enumerating candidate sessions, presenting them to the user in chat, and calling the script with the IDs the user picks.

## Why this exists

Agent CLIs store conversation content in private, volatile-feeling locations:

- **Claude Code** writes one `.jsonl` file per session under `~/.claude/projects/<dir-hash>/<session-uuid>.jsonl`.
- **opencode** writes into a global sqlite DB at `~/.local/share/opencode/opencode.db`, with one row per message, keyed by session ID.

When users run long planning sessions — grilling interviews, multi-day PRD brainstorms, context-heavy design discussions — that content is the *only* record of the design reasoning. Context windows reset, models switch, rate limits force backend swaps, machines get wiped. If the transcript is not pulled out and committed, it is effectively write-only memory.

Naively-written dump scripts make this worse in two specific ways, both of which cause silent data loss:

1. **"Pick the newest file" (Claude Code)** — scripts that do `max(glob("*.jsonl"), key=mtime)` will cheerfully export whatever session ran most recently. The moment the user starts any new session in the same repo (debugging, a bug fix, or even the very session invocation that wants to run the export), the "newest" file changes and the previous planning transcript silently disappears from the next export.
2. **"Hardcode a single session ID" (opencode)** — scripts with `SESSION_ID = "ses_..."` baked in will keep dumping the same original session forever, even after the user resumes the interview in a new session. The continuation sessions are invisible to the script and their content is lost on the next export.

Both bugs look correct during the first export and fail later, which is the worst failure mode possible.

An earlier version of this skill used a committed `sessions.json` config file as the explicit list. That worked but had its own trap: if the user forgot to append new session IDs to the config after resuming, the new session's content silently dropped on the next dump. The current design moves the "which sessions" decision fully into the agent's conversation with the user: **every run is a fresh enumerate-and-ask loop, no stale list can exist anywhere**.

A second earlier version concatenated all picked sessions into a single giant markdown file. That made it hard to diff a single session's changes over time, and a long concatenated transcript became unwieldy once more than two or three sessions piled up. The current design writes one file per session, so each session has its own diffable history and the directory grows naturally as sessions are added.

## Convention: `.sessions/` at the repo root

Exports land in `<repo-root>/.sessions/<session-id>.md`. This is the default convention for all repos using this skill. Benefits:

- Predictable: any agent or tool inspecting the repo can find session dumps without hunting.
- One file per session means each session has its own git history — you can see exactly what changed in a single session without diffing against concatenated output.
- Filename is the canonical session ID, so cross-referencing back to `~/.claude/projects/` or opencode's DB is trivial.
- The directory name starts with a dot so it sorts out of the way in normal `ls` output but is not hidden from git.

If a repo already has a strong prior convention (`docs/sessions/`, `planning/transcripts/`, etc.), override by passing a different output directory. But prefer `.sessions/` unless there's a good reason not to.

## Preconditions

- The target repo is under git (`git rev-parse --show-toplevel` succeeds). The skill's value comes from committing the transcripts; an untracked repo defeats the point.
- Python 3.9+ is available (the scripts use `pathlib`, f-strings, `argparse`, and the `sqlite3` stdlib — no external deps).
- For the Claude Code dump: `~/.claude/projects/` exists and contains at least one project directory for the repo. The repo's project dir is named after its absolute path with `/` replaced by `-`, prefixed with a leading `-`. For example, `/home/alice/projects/foo` becomes `-home-alice-projects-foo`.
- For the opencode dump: `~/.local/share/opencode/opencode.db` exists. If opencode has never been run, there is nothing to dump and the opencode half of the skill is a no-op — tell the user and skip that half.

If neither runtime has produced any data on this machine, stop and tell the user; there is nothing to dump.

## Workflow

### 1. Confirm scope with the user

Ask (or infer from conversation) which runtimes to cover:

- Claude Code only
- opencode only
- Both

Use `.sessions/` at the repo root as the output directory unless the user explicitly asks for a different location.

### 2. Invoke the scripts from the skill install, not a per-repo copy

The scripts live alongside this SKILL.md at `scripts/export_claude_session.py` and `scripts/export_opencode_session.py`. Call them directly from this skill directory — do not copy them into every target repo. The claude script resolves the repo root from `cwd` by default (walking up to the nearest `.git`), or from an explicit `--repo-root` flag. The opencode script does not need a repo root at all since it filters by session ID against the global opencode DB.

Running the scripts from inside the target repo is the normal pattern. The paths below are already absolute — the installer replaces `__INSTALLED_SKILL_DIR__` with the absolute directory this SKILL.md lives in at install time:

```bash
cd /path/to/target/repo
python3 __INSTALLED_SKILL_DIR__/scripts/export_claude_session.py .sessions UUID1 UUID2
python3 __INSTALLED_SKILL_DIR__/scripts/export_opencode_session.py .sessions ses_abc ses_def
```

If for any reason the agent cannot `cd` into the target repo, pass `--repo-root /absolute/path/to/repo` on the claude invocation. The opencode invocation is unaffected.

### 3. Enumerate candidate sessions, present, and ask

This is the step that *replaces* a config file. Every dump run, the agent gathers the candidate list fresh, shows it to the user in chat, and waits for a pick.

#### Shortcut: "dump THIS session" (Claude Code)

When the user says "dump this session", "export the current chat", or anything that clearly means *the running Claude Code conversation*, skip the enumerate-and-ask flow and resolve the live session's UUID directly from your own system prompt.

Every Claude Code session on this machine is launched via a `cc` shell wrapper that injects `--session-id <uuid>` and `--append-system-prompt "<claude-session-id>$sid</claude-session-id>"`. The tag is present in your system prompt from turn zero.

To resolve the current session:

1. Scan your system prompt for the literal tag `<claude-session-id>...</claude-session-id>`.
2. Extract the UUID with regex `<claude-session-id>([0-9a-f-]{36})</claude-session-id>`.
3. Hand that UUID directly to `export_claude_session.py` as the single argv session ID.

No filesystem scan, no grep, no heuristics. The tag is structured so it cannot collide with prose the user might write.

**If the tag is missing, stop and tell the user.** Do not fall back to mtime, content-grep, or picking the newest `.jsonl` — those are the exact data-loss patterns this skill was built to prevent. A missing tag means the session was launched outside the `cc` wrapper (plain `claude`, `--continue`, `--resume`, IDE launch), and the correct action is to surface that to the user so they can either relaunch via `cc` or explicitly pick a session via the normal enumerate-and-ask path below.

This shortcut applies **only** to "dump the current Claude Code session". For opencode current-session dumps, or for any request that implies multiple sessions or historical sessions, fall through to the normal enumerate-and-ask path below.

**For Claude Code:**

The project directory is `~/.claude/projects/-<repo-path-with-slashes-as-dashes>`. List `.jsonl` files there and, for each one, extract:

- filename (the session UUID)
- file size (rough proxy for content volume)
- mtime (for chronological sort)
- first user message text (first ~100 chars — cheap heuristic for "is this the planning session?")
- optional: count of "Question N:" substrings, which is a strong signal for grilling-style sessions

A short Python one-liner over the project directory produces exactly this list. Present it to the user sorted by mtime ascending, with enough metadata per row that they can tell which sessions are planning-relevant. Wait for the user to pick.

**For opencode:**

opencode tags every session row with the working directory it was started in. Query the `session` table filtered by `directory` matching the repo's absolute path, sorted by `time_created`:

```sql
SELECT id, title, directory, time_created
FROM session
WHERE directory = '/absolute/path/to/repo'
ORDER BY time_created;
```

Present rows to the user with id, title, and rough timestamp. Wait for them to pick.

**Key rule: the user picks every time.** Do not cache the last pick, do not "remember" which sessions were picked last week, do not suggest "the usual list" without re-presenting the candidates. A stale cached answer is exactly the failure mode this design avoids. If the enumerate-and-ask dance feels repetitive to the user, that is the correct cost of the safety — not a signal to add persistence back.

Exception: if the user has just told you the session IDs directly in the same conversation (e.g., "dump sessions UUID1 and UUID2"), skip enumeration and use their explicit list. The skill's constraint is "explicit list every run", not "force an enumeration step even when unnecessary".

### 4. Invoke the script

From inside the target repo, call the canonical skill copy of each script. The installer expands `__INSTALLED_SKILL_DIR__` to an absolute path when this skill is materialized:

```bash
python3 __INSTALLED_SKILL_DIR__/scripts/export_claude_session.py .sessions UUID1 UUID2 UUID3
python3 __INSTALLED_SKILL_DIR__/scripts/export_opencode_session.py .sessions ses_abc ses_def
```

Each script prints one `wrote N messages: <path>` line per session written, then a summary line. On failure the scripts raise `SystemExit` with a clear message — do not catch these errors silently; they indicate a bad session ID or a missing source file, and fixing them is the whole point of the fail-loud behavior.

Output files are overwritten every run (for the session IDs passed), so re-running with the same IDs is idempotent. Sessions previously dumped but not passed in the current invocation are **not** deleted — the directory is a persistent record, and leftover files from prior runs are a feature, not a leak. If the user wants to drop a session, they delete its `.md` file directly.

### 5. Verify and commit

Open a few of the generated markdown files and spot-check:

- Each file starts with the session ID header and a message list.
- Message numbers increase monotonically within each file.
- Content matches what the user expected for that session.

Then commit `.sessions/` and the scripts (if bootstrapping a new setup) to git. The generated transcripts are *not* `.gitignore`d — the whole point is that they live in git as the durable record.

## Invariants

These are the rules that keep the skill from causing the data-loss bugs it was designed to prevent. Do not relax them:

- **No persisted session list.** No `sessions.json`, no environment variable list, no cached "last picked" state. The only input to each dump run is the argv the agent passes. An earlier version of this skill used a config file and moved the failure mode from "forgot to find the session" to "forgot to edit the file" — same class of bug, slightly different surface.
- **Enumerate candidates fresh every time.** Do not reuse a previous turn's enumeration across dump runs. New sessions may have been created since then, and the whole point of the ask-every-time design is to catch them.
- **One file per session.** Never concatenate multiple sessions into a single output file. Per-session files give each session its own git history, its own diffable timeline, and trivial rollback if a session is accidentally dumped.
- **Fail loud on missing sessions.** If a listed session ID does not correspond to an existing file (Claude Code) or DB row (opencode), the script must raise `SystemExit` with a clear message. Silently skipping hides data loss.
- **Deterministic content per session.** Re-running with the same session ID produces the same output file byte-for-byte (ignoring append-only changes to the underlying session). This makes `git diff` on a single session's `.md` file meaningful for tracking growth.
- **No external dependencies.** Stick to the Python stdlib. These scripts often run in environments where installing packages is friction or impossible. Keeping the scripts dependency-free keeps the skill installable everywhere.

## Common scenarios

**"I already have a dump script but it only exports one session."**

Almost certainly the data-loss pattern — `max(..., key=mtime)` for Claude Code or a hardcoded `SESSION_ID = "ses_..."` for opencode. Replace the script with the bundled version from this skill (argv-driven, explicit list, per-session output). Before deleting the old script, grab the hardcoded session ID (if any) so the user does not lose the original planning session from the next dump. Then enumerate candidates, confirm with the user, run the new script against `.sessions/`, verify the output files contain everything the old single-file transcript had, and commit.

**"I'm resuming a planning session in a new agent/chat."**

When it's time to dump, enumerate candidates — the new session will show up alongside the old ones — and include it in the pick list. The new session gets its own `.md` file in `.sessions/`, leaving the previous session files untouched.

**"I want to use this in a new repo that has never had a dump setup."**

Full workflow: enumerate candidates, ask user, run the script to populate `.sessions/`, commit. Takes a few minutes at most. The hardest step is always step 3 (identifying the right session IDs) — everything else is mechanical.

**"I accidentally dumped an unrelated session and the transcript directory is polluted."**

Delete the specific `.sessions/<bad-id>.md` file with `rm` and commit the removal. Because every session is a separate file, there's no "clean up after myself" rebuild step — targeted deletion is safe.

**"I want to refresh one session that has grown since the last dump without touching the others."**

Run the script with just that one session ID. The one file gets overwritten; all other files in `.sessions/` are untouched. This is the normal incremental workflow.

## What the bundled scripts assume

The scripts in `scripts/` are the exact correct implementation — do not rewrite them from memory. They live in the skill install and are called directly. Specifically:

- `export_claude_session.py` resolves the target repo root from `cwd` (walking up to the nearest `.git`) unless `--repo-root` is passed explicitly. This means the script lives once in the skill install and the agent just needs to `cd` into the target repo (or pass `--repo-root`) before calling it. Safety rail: if neither `cwd` nor the override lands on a real git repo with a matching Claude Code project directory, the script raises `SystemExit` with a clear message.
- `export_opencode_session.py` reads every listed session ID from the global opencode DB at `~/.local/share/opencode/opencode.db` and filters by ID only. If the user runs opencode with a non-default DB path, the constant at the top of the script needs to be updated.
- Both scripts write ASCII-only output (non-ASCII characters in messages are stripped). This matches common planning-transcript conventions and keeps transcripts diff-friendly across systems with different locale settings. If the user needs UTF-8 output, remove the `ascii_clean` step — but warn them that line-ending and locale edge cases can surface afterward.
- Both scripts create the output directory (and its parents) on demand via `mkdir -p` semantics, so pointing at `.sessions/` in a fresh repo just works.

## Limitations

- **Text content only.** Tool calls, tool results, images, and attachments are not exported — only user and assistant text. For a grilling-style planning transcript this is exactly right (the design reasoning lives in the text), but for debugging an agent's tool-use behavior this skill is the wrong tool.
- **No live-tail mode.** The scripts are one-shot: run them, they dump the given list, exit. They do not watch for new sessions. Every fresh dump requires the agent to re-enumerate and re-ask.
- **No cross-repo aggregation.** Each invocation targets one repo's sessions. If the user runs planning sessions across multiple repos and wants a unified transcript, they need one dump call per repo and then their own concatenation layer on top.
- **Opencode schema drift.** The opencode script queries the `session`, `message`, and `part` tables with specific column names (`data`, `time_created`, `directory`). If opencode changes its schema in a future release, the script will break with a clear sqlite error. Worth re-reading the schema with `PRAGMA table_info(session)` before blaming the script.

## Reference files

- [scripts/export_claude_session.py](scripts/export_claude_session.py) — Claude Code dump, argv-driven, one markdown file per session, walks up from `cwd` to find `.git` by default.
- [scripts/export_opencode_session.py](scripts/export_opencode_session.py) — opencode dump, argv-driven, one markdown file per session, filters by session ID from the opencode sqlite DB.
