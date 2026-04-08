---
name: lan-proxy
description: Expose local services over LAN via Caddy reverse proxy and ufw firewall. Use whenever the user wants to make a local service accessible from other devices, add/remove a proxied service, open/close a port, troubleshoot LAN connectivity, or mentions Caddy, ufw, iptables, firewall, reverse proxy, or "can't connect" to a service from another device.
---

# LAN Service Proxy

This machine (Arch Linux) runs **Caddy** as a reverse proxy to expose local services over the LAN, with **ufw** managing the firewall. Docker is also installed, which complicates firewall rules.

## Architecture

```
Other devices on LAN
        │
        ▼
   ufw firewall (before.rules bypass for Docker)
        │
        ▼
   Caddy (0.0.0.0:<external-port>)
        │
        ▼
   Service (127.0.0.1:<internal-port>)
```

**Port convention**: external port `N` maps to internal port `1N` (prefix with 1). For example:
- External `:3100` → Internal `127.0.0.1:13100`
- External `:8080` → Internal `127.0.0.1:18080`
- External `:3001` → Internal `127.0.0.1:13001`

Services bind to `127.0.0.1` only — Caddy handles all external-facing traffic.

## How to Expose a New Service

Three things are needed. Since steps 1 and 3 require sudo, write a single bash script for the user to execute.

### 1. Add the Caddy proxy entry

Create a file in `/etc/caddy/conf.d/<service-name>.caddy`:

```
:<external-port> {
	reverse_proxy 127.0.0.1:<internal-port> {
		header_up Host 127.0.0.1:<internal-port>
	}
}
```

Make this the default for localhost-bound services. Some backends validate the `Host` header and reject the LAN-facing host that Caddy forwards by default.

Example: a service on `127.0.0.1:14788` proxied from LAN port `4788` can reject `Host: 192.168.0.222:4788` as forbidden. Rewriting the upstream `Host` to `127.0.0.1:14788` avoids that class of failure.

### 2. Configure the service to bind to localhost

The service must bind to `127.0.0.1:<internal-port>` instead of `0.0.0.0:<external-port>`. How to do this depends on the service — check its config file.

### 3. Add the firewall rule

Docker's iptables chains silently drop incoming LAN traffic even when ufw shows ALLOW. Two things are needed — a ufw rule alone is NOT sufficient:

```bash
# ufw rule
sudo ufw allow <external-port>/tcp

# before.rules entry (this is what actually bypasses Docker's interference)
# Add after an existing entry in /etc/ufw/before.rules
sudo sed -i '/-A ufw-before-input -p tcp --dport <existing-port> -j ACCEPT/a\
-A ufw-before-input -p tcp --dport <new-port> -j ACCEPT' /etc/ufw/before.rules
```

### 4. Reload everything

```bash
sudo ufw reload
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Then restart the service so it picks up the new port binding.

## How to Remove a Service

Write a script for the user:

```bash
# Remove Caddy config
sudo rm /etc/caddy/conf.d/<service-name>.caddy

# Remove firewall rule
sudo ufw delete allow <external-port>/tcp

# Remove before.rules entry
sudo sed -i '/-A ufw-before-input -p tcp --dport <external-port>/d' /etc/ufw/before.rules

# Reload
sudo ufw reload
sudo systemctl reload caddy
```

## Script Pattern

Since sudo requires a terminal password prompt, always write a single bash script that does all the work. Pattern:

```bash
#!/bin/bash
set -euo pipefail

# 1. Create Caddy proxy config
cat > /etc/caddy/conf.d/<service-name>.caddy << 'EOF'
:<external-port> {
	reverse_proxy 127.0.0.1:<internal-port> {
		header_up Host 127.0.0.1:<internal-port>
	}
}
EOF

# 2. Add firewall rules
sudo ufw allow <external-port>/tcp
sudo sed -i '/-A ufw-before-input -p tcp --dport <existing-port> -j ACCEPT/a\
-A ufw-before-input -p tcp --dport <external-port> -j ACCEPT' /etc/ufw/before.rules

# 3. Reload
sudo ufw reload
caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy

echo "Done. <service-name> is now accessible on :<external-port>"
```

Save to `~/setup-proxy.sh`, make executable, tell user to run it. Clean up after use.

## Caddy Configuration

- Main config: `/etc/caddy/Caddyfile` — global options only, imports from `conf.d/`
- Per-service configs: `/etc/caddy/conf.d/<service-name>.caddy`
- Caddy runs as a system service: `systemctl status caddy`
- Auto HTTPS is disabled (LAN-only, no domain names)
- Default proxy behavior for localhost-bound services: rewrite upstream `Host` to `127.0.0.1:<internal-port>`

## Why Docker Breaks ufw

Docker installs iptables chains (DOCKER-USER, DOCKER-FORWARD, etc.) that process packets before ufw's rules. `ufw allow <port>` adds the rule correctly, but incoming LAN traffic gets silently dropped. The symptom is a connection **timeout** (not refused) from other devices while localhost works fine.

The fix is adding rules to `/etc/ufw/before.rules` which get inserted early in the INPUT chain, before Docker's chains interfere. SSH works without this because it has a direct INPUT chain ACCEPT rule.

## Diagnosing Connectivity Issues

Run these commands when a service is not reachable from LAN. Run as many as possible in parallel.

### Step 1: Gather state

```bash
# Get LAN IP
ip -4 addr show | grep -oP 'inet \K[0-9.]+' | grep -v '127.0.0.1' | head -1

# Is the service listening?
ss -tlnp | grep <port>

# Is Caddy running and proxying this port?
systemctl status caddy --no-pager | head -5
ls /etc/caddy/conf.d/

# Is the firewall allowing it?
# (requires sudo — ask user to run if needed)
sudo ufw status | grep <port>

# Is there a before.rules entry?
grep <port> /etc/ufw/before.rules

# Test the full chain via LAN IP
curl -s -o /dev/null -w "%{http_code}" http://<LAN_IP>:<port>

# Test the backend directly
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:<internal-port>
```

If the backend works directly on `127.0.0.1:<internal-port>` but the LAN-facing proxy returns `403` or another app-level rejection, inspect the Caddy config for a missing `header_up Host 127.0.0.1:<internal-port>`.

### Step 2: Interpret results

| Caddy | Backend | ufw | before.rules | Diagnosis |
|-------|---------|-----|--------------|-----------|
| running | listening on 127.0.0.1 | ALLOW | present | Should work — ask user to test from remote device |
| running | listening on 127.0.0.1 | ALLOW | missing | Docker dropping traffic — add before.rules entry |
| running | listening on 127.0.0.1 | missing | missing | Firewall not configured — add both ufw rule and before.rules |
| running | listening on 127.0.0.1 | ALLOW | present | Direct localhost works but LAN proxy returns 403 — backend is likely rejecting the forwarded Host header, so add `header_up Host 127.0.0.1:<internal-port>` |
| running | not listening | — | — | Service is down — restart it |
| running | listening on 0.0.0.0 | — | — | Service not reconfigured — change it to bind to 127.0.0.1:<internal-port> |
| not running | — | — | — | Start Caddy: `sudo systemctl start caddy` |
| port conflict | — | — | — | Something else is on the external port — kill it or pick a different port |

### Step 3: Ask user to verify from remote device

```bash
curl -v --connect-timeout 5 http://<LAN_IP>:<port>
```
- **Timeout** = packets being dropped (firewall/Docker issue)
- **Connection refused** = nothing listening on that port (Caddy not running or not configured)
- **502** = Caddy running but backend is down
- **200/HTML** = working

## Checking Current State

Always derive current state from the system. Run these:

```bash
# LAN IP
ip -4 addr show | grep -oP 'inet \K[0-9.]+' | grep -v '127.0.0.1' | head -1

# Active proxy configs
ls /etc/caddy/conf.d/

# Open firewall ports (requires sudo)
sudo ufw status

# before.rules entries
grep 'ufw-before-input.*dport' /etc/ufw/before.rules

# What's listening
ss -tlnp
```
