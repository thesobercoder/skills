#!/usr/bin/env python3
"""Dump listed opencode sessions, one markdown file per session.

Usage:
    export_opencode_session.py OUTPUT_DIR SESSION_ID [SESSION_ID ...]

Writes one `<session-id>.md` file inside OUTPUT_DIR for every listed session.
Session IDs are the `ses_...` identifiers from the opencode sqlite DB at
`~/.local/share/opencode/opencode.db`.

Fails loud (SystemExit) if any listed session ID has no matching row.
Silent skipping would reintroduce the data-loss bugs this script exists
to prevent.
"""
import argparse
import json
import sqlite3
from pathlib import Path

DB = Path.home() / ".local/share/opencode/opencode.db"


def render_text(p: sqlite3.Row) -> str:
    try:
        d = json.loads(p["data"])
    except Exception:
        return ""
    if d.get("type") == "text":
        text = d.get("text", "")
        text = text.encode("ascii", "ignore").decode("ascii")
        return text.strip()
    return ""


def write_session_md(out_path: Path, sid: str, title: str, con: sqlite3.Connection) -> int:
    msgs = con.execute(
        "SELECT id, data FROM message WHERE session_id=? ORDER BY time_created",
        (sid,),
    ).fetchall()

    parts_by_msg: dict[str, list[sqlite3.Row]] = {}
    for row in con.execute(
        "SELECT id, message_id, data FROM part WHERE session_id=? ORDER BY time_created",
        (sid,),
    ).fetchall():
        parts_by_msg.setdefault(row["message_id"], []).append(row)

    written = 0
    with out_path.open("w") as f:
        f.write(f"# opencode session `{sid}`\n\n")
        if title:
            f.write(f"Title: {title}\n\n")
        f.write("Exported by session-dump.\n\n---\n\n")
        i = 0
        for m in msgs:
            role = json.loads(m["data"]).get("role", "?")
            pieces = [r for p in parts_by_msg.get(m["id"], []) if (r := render_text(p))]
            if not pieces:
                continue
            i += 1
            f.write(f"### [{i}] {role}\n\n")
            for p in pieces:
                f.write(p + "\n\n")
            f.write("---\n\n")
            written += 1
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description="Dump opencode sessions, one markdown file per session.")
    parser.add_argument("output_dir", type=Path, help="Output directory; one <session-id>.md file is written per session")
    parser.add_argument("session_ids", nargs="+", help="opencode session IDs to dump")
    args = parser.parse_args()

    if not DB.exists():
        raise SystemExit(f"opencode DB does not exist: {DB}")

    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row

    for sid in args.session_ids:
        r = con.execute("SELECT id FROM session WHERE id=?", (sid,)).fetchone()
        if r is None:
            raise SystemExit(f"session not found in opencode DB: {sid}")

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    written = 0
    for sid in args.session_ids:
        row = con.execute("SELECT id, title FROM session WHERE id=?", (sid,)).fetchone()
        title = row["title"] or ""
        out_path = out_dir / f"{sid}.md"
        count = write_session_md(out_path, sid, title, con)
        if count == 0:
            print(f"skipped (no text content): {sid}")
            continue
        print(f"wrote {count} messages: {out_path}")
        written += 1

    print(f"done: {written}/{len(args.session_ids)} session(s) written to {out_dir}")


if __name__ == "__main__":
    main()
