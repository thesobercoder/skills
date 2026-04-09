# Skills

Custom skills plus selected third-party skills managed from this repository.

## Installation

Run the root installer:

```
./install.sh
```

This installer:

- installs all local skills in this repo
- clones selected third-party skill repos into `./.external/`
- refreshes both `~/.agents/skills` and `~/.claude/skills`

Third-party skill sources are configured in `skills.json`.

Most skills are installed as symlinks. Skills with `install_mode: materialize` are copied into the target directories so install-time placeholders can be expanded safely.

## Skills In This Repo

| Skill | Description |
|-------|-------------|
| [composio](composio/) | Universal service aggregator — gateway to 500+ external apps via Composio MCP |
| [lan-proxy](lan-proxy/) | Expose local services over LAN via Caddy reverse proxy and ufw firewall |
| [repo-skill-creator](repo-skill-creator/) | Create repo-backed skills here, refresh them with `./install.sh`, and keep the README updated |
| [opencode-contributor](opencode-contributor/) | Run the opencode contribution workflow from repo checks through PR drafting |
| [user-service](user-service/) | Create and manage systemd user-level services for CLI tools |
