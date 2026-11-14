# Other Commands

Additional utility commands for health checking, shell completions, documentation generation, and version information.

## lvscare — IPVS Health Check

Run a long-lived health check daemon for IPVS-based API server load balancing. Monitors real server availability and updates IPVS rules accordingly.

```
cyctl lvscare care [OPTIONS]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--vs` | Virtual Service `IP:Port` | required |
| `--rs` | Real Server `IP:Port` (repeatable) | required |
| `--health-path` | Health check endpoint path | `/healthz` |
| `--health-schem` | Health check protocol: `http` or `https` | `https` |
| `--interval` | Check interval in seconds | `5` |

### Example

```bash
cyctl lvscare care \
  --vs 10.103.97.2:6443 \
  --rs 10.0.0.1:6443 \
  --rs 10.0.0.2:6443 \
  --rs 10.0.0.3:6443 \
  --interval 5
```

---

## completion — Shell Completions

Generate shell completion scripts for various shells.

```bash
cyctl completion bash       # Bash
cyctl completion zsh        # Zsh
cyctl completion fish       # Fish
cyctl completion powershell # PowerShell
```

### Installation

**Bash (Linux):**

```bash
cyctl completion bash | sudo tee /etc/bash_completion.d/cyctl
```

**Bash (macOS with Homebrew):**

```bash
cyctl completion bash > $(brew --prefix)/etc/bash_completion.d/cyctl
```

**Zsh:**

```bash
cyctl completion zsh > "${fpath[1]}/_cyctl"
compinit
```

**Fish:**

```bash
cyctl completion fish > ~/.config/fish/completions/cyctl.fish
```

---

## docs — Man Page Generation

Generate man pages for all cyctl commands.

```bash
# Default output to ./docs/man/
cyctl docs

# Custom directory
cyctl docs --path /usr/local/share/man/man1/

# View man pages after generation
man cyctl
man cyctl-cluster-run
```

---

## version

Display version, git commit, and build timestamp.

```bash
cyctl version
# Output: {"version": "0.1.0", "commit": "abc1234", "built": "2026-09-01T12:00:00Z"}
```

## env

Display the current environment variable configuration.

```bash
cyctl env
# Output: {"CYCORE_API_URL": "(not set)", "CYCORE_DATA_DIR": "...", ...}
```
