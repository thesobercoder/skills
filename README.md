# Skills

Custom [Claude Code](https://claude.com/claude-code) skills.

## Installation

Clone the repo and symlink each skill into `~/.claude/skills/`:

```bash
git clone https://github.com/thesobercoder/skills.git ~/projects/skills

for skill in ~/projects/skills/*/; do
  name=$(basename "$skill")
  [ "$name" = ".git" ] && continue
  ln -sf "$skill" ~/.claude/skills/"$name"
done
```

## Skills

| Skill | Description |
|-------|-------------|
| [composio](composio/) | Universal service aggregator — gateway to 500+ external apps via Composio MCP |
| [lan-proxy](lan-proxy/) | Expose local services over LAN via Caddy reverse proxy and ufw firewall |
