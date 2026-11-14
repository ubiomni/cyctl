# remote -- Remote Operations

The `remote` command group executes commands and transfers files across cluster nodes via SSH.

## remote exec

Execute a command on cluster nodes via SSH.

```
cyctl remote exec [OPTIONS] -- <COMMAND>...
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--masters` | `-m` | Master node IPs (comma-separated) | — |
| `--nodes` | `-n` | Worker node IPs (comma-separated) | — |
| `--passwd` | `-p` | SSH password | — |
| `--pk` | `-k` | SSH private key path | — |
| `--user` | `-u` | SSH user | `root` |
| `--port` | — | SSH port | `22` |
| `--role` | `-r` | Target role filter: `master`, `node`, or `all` | `all` |
| `--cluster-name` | `-c` | Load host list from saved cluster spec | — |

### Two Modes

- **Direct host specification** — Provide `--masters` and/or `--nodes` with SSH credentials.
- **Cluster spec mode** — Use `-c <cluster-name>` to load hosts from a previously deployed cluster's saved spec.

### Examples

```bash
# Execute on specific masters
cyctl remote exec -m 10.0.0.1,10.0.0.2,10.0.0.3 -p 'YourPassword' \
  -- 'kubectl get nodes -o wide'

# Execute on all nodes (masters + workers)
cyctl remote exec -m 10.0.0.1 -n 10.0.0.11,10.0.0.12 -p 'YourPassword' \
  -- 'systemctl status kubelet'

# Using saved cluster spec, target only masters
cyctl remote exec -c default -r master -- 'kubeadm token list'

# Using saved cluster spec, target all nodes
cyctl remote exec -c default -r all -- 'df -h /var/lib/containerd'

# Check uptime on specific hosts with SSH key
cyctl remote exec --hosts 10.0.0.1 -k ~/.ssh/id_rsa -- 'uptime'
```

### JSON Output

```json
[
  {"host": "10.0.0.1", "status": "ok", "output": "NAME   STATUS   ROLES    AGE   VERSION\n..."},
  {"host": "10.0.0.2", "status": "ok", "output": "NAME   STATUS   ROLES    AGE   VERSION\n..."}
]
```

---

## remote scp

Transfer files to or from cluster nodes via SCP.

```
cyctl remote scp [OPTIONS] <LOCAL> <REMOTE>
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `<LOCAL>` | — | Local file path | — |
| `<REMOTE>` | — | Remote file path | — |
| `--masters` | `-m` | Master node IPs (comma-separated) | — |
| `--nodes` | `-n` | Worker node IPs (comma-separated) | — |
| `--passwd` | `-p` | SSH password | — |
| `--pk` | `-k` | SSH private key path | — |
| `--user` | `-u` | SSH user | `root` |
| `--port` | — | SSH port | `22` |
| `--role` | `-r` | Target role filter: `master`, `node`, or `all` | `all` |
| `--cluster-name` | `-c` | Load host list from saved cluster spec | — |
| `--download` | `-d` | Download mode (default is upload) | `false` |

### Examples

```bash
# Upload a file to all nodes
cyctl remote scp -m 10.0.0.1 -n 10.0.0.11 -p 'YourPassword' \
  ./config.yaml /etc/kubernetes/config.yaml

# Upload cyctl binary to all nodes using cluster spec
cyctl remote scp -c prod ./cyctl /usr/local/bin/cyctl

# Download files from masters
cyctl remote scp -m 10.0.0.1,10.0.0.2 -p 'YourPassword' \
  -d /tmp/downloaded/ /etc/kubernetes/admin.conf
```
