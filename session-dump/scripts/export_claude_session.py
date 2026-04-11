#!/usr/bin/env python3
"""Dump listed Claude Code sessions for this repo, one markdown file per session.

Usage:
    export_claude_session.py OUTPUT_DIR SESSION_ID [SESSION_ID ...]

Writes one `<session-id>.md` file inside OUTPUT_DIR for every listed session.
Session IDs are the UUID filenames (without `.jsonl`) under
`~/.claude/projects/<repo-dir-hash>/`. The script resolves the project
directory from `cwd` by default (walking up to the nearest `.git`) or from
an explicit `--repo-root` flag.

Fails loud (SystemExit) if any listed session ID has no matching jsonl file.
Silent skipping would reintroduce the data-loss bugs this script exists to
prevent.
"""
import argparse
import json
from pathlib import Path


def find_repo_root(start: Path) -> Path:
    for p in [start, *start.parents]:
        if (p / ".git").exists():
            return p
    raise SystemExit(f"no git repo found above {start}")


def ascii_clean(s: str) -> str:
    return s.encode("ascii", "ignore").decode("ascii").strip()


def extract_text(content) -> str:
    if isinstance(content, str):
        return ascii_clean(content)
    if isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text":
                parts.append(ascii_clean(block.get("text", "")))
        return "\n\n".join(p for p in parts if p)
    return ""


def is_tool_result_only(content) -> bool:
    if not isinstance(content, list):
        return False
    return all(isinstance(b, dict) and b.get("type") == "tool_result" for b in content)


def load_session(path: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    with path.open() as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            if t not in ("user", "assistant"):
                continue
            msg = d.get("message", {})
            content = msg.get("content")
            if t == "user" and is_tool_result_only(content):
                continue
            text = extract_text(content)
            if not text:
                continue
            rows.append((t, text))
    return rows


def write_session_md(out_path: Path, sid: str, rows: list[tuple[str, str]]) -> None:
    with out_path.open("w") as f:
        f.write(f"# Claude Code session `{sid}`\n\n")
        f.write("Exported by session-dump.\n\n---\n\n")
        for i, (role, text) in enumerate(rows, 1):
            f.write(f"### [{i}] {role}\n\n{text}\n\n---\n\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Dump Claude Code sessions, one markdown file per session.")
    parser.add_argument("output_dir", type=Path, help="Output directory; one <session-id>.md file is written per session")
    parser.add_argument("session_ids", nargs="+", help="Claude Code session UUIDs to dump")
    parser.add_argument("--repo-root", type=Path, default=None, help="Repo root override (default: walk up from cwd until .git)")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve() if args.repo_root else find_repo_root(Path.cwd())
    projects_dir = Path.home() / ".claude/projects" / ("-" + str(repo_root).replace("/", "-").lstrip("-"))

    if not projects_dir.exists():
        raise SystemExit(f"claude projects dir does not exist: {projects_dir}")

    missing = [sid for sid in args.session_ids if not (projects_dir / f"{sid}.jsonl").exists()]
    if missing:
        raise SystemExit(f"missing jsonl files for: {missing} (under {projects_dir})")

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    written = 0
    for sid in args.session_ids:
        rows = load_session(projects_dir / f"{sid}.jsonl")
        if not rows:
            print(f"skipped (no text content): {sid}")
            continue
        out_path = out_dir / f"{sid}.md"
        write_session_md(out_path, sid, rows)
        print(f"wrote {len(rows)} messages: {out_path}")
        written += 1

    print(f"done: {written}/{len(args.session_ids)} session(s) written to {out_dir}")


if __name__ == "__main__":
    main()
