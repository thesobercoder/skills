---
name: user-service
description: Create, list, manage, or troubleshoot systemd user-level services for CLI tools. Use when the user wants to run a command as a persistent background service, create a systemd unit, enable/disable/restart a user service, list running services, or check service status and logs.
---

# User-Level Systemd Services

This machine (Arch Linux) uses `systemd --user` services to run CLI tools as persistent background processes. Services are managed per-user without requiring root.

## Service location

All user service files live in:

```
~/.config/systemd/user/<service-name>.service
```

## Creating a new service

### 1. Resolve the binary path

CLI tools are typically installed via mise. Always resolve the full path:

```bash
which <command>
```

This usually returns something like:
```
/home/thesobercoder/.local/share/mise/installs/node/<version>/bin/<command>
```

**Always use the full absolute path** in `ExecStart` — systemd user services don't load shell profiles, so PATH-dependent commands will fail silently.

### 2. Write the service file

Create `~/.config/systemd/user/<service-name>.service`:

```ini
[Unit]
Description=<Service Name> Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=<full-binary-path> <args>
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

Notes:
- `After=network-online.target` ensures network is ready (important for web services)
- `Restart=on-failure` with `RestartSec=5` provides automatic recovery
- `WantedBy=default.target` starts the service on user login

### 3. Enable and start

Tell the user to run:

```bash
systemctl --user daemon-reload && systemctl --user enable --now <service-name>.service
```

`daemon-reload` picks up the new unit file. `enable --now` both enables on boot and starts immediately.

## LAN exposure

If the service needs to be accessible from other devices on the LAN, use the `lan-proxy` skill after creating the service. The port convention is:

- Service binds to `127.0.0.1:<internal-port>` (prefix external port with `1`)
- Caddy proxies from `0.0.0.0:<external-port>` to the internal port

## Managing existing services

```bash
# Check status
systemctl --user status <service-name>

# View logs
journalctl --user -u <service-name> -f

# Restart
systemctl --user restart <service-name>

# Stop and disable
systemctl --user disable --now <service-name>

# List all user services
systemctl --user list-units --type=service --all
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `(code=exited, status=203/EXEC)` | Binary path wrong or not executable | Verify with `which`, use full path |
| `(code=exited, status=217/USER)` | User directive in a user service | Remove `User=` line — user services already run as the user |
| Service stops after logout | Lingering not enabled | `loginctl enable-linger thesobercoder` |
| Service starts but port not listening | Wrong `--port` or bind address | Check with `ss -tlnp \| grep <port>` |

## Removing a service

```bash
systemctl --user disable --now <service-name>
rm ~/.config/systemd/user/<service-name>.service
systemctl --user daemon-reload
```

If the service was exposed via LAN proxy, also remove the Caddy config and firewall rules using the `lan-proxy` skill.
