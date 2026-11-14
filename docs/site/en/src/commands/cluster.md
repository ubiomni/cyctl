# cluster -- Cluster Lifecycle

The `cluster` command group manages the full lifecycle of Kubernetes clusters: deployment, status inspection, certificate management, and teardown.

## cluster run

Deploy a K8s cluster from an OCI image or local tar archive.

```
cyctl cluster run [OPTIONS] -m <MASTERS> [IMAGES]...
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--masters` | `-m` | Master node IPs (comma-separated, required) | — |
| `--nodes` | `-n` | Worker node IPs (comma-separated) | `""` |
| `--passwd` | `-p` | SSH password | — |
| `--pk` | `-k` | SSH private key path | — |
| `--port` | — | SSH port | `22` |
| `--user` | `-u` | SSH user | `root` |
| `--env` | `-e` | Environment variable KEY=VALUE, repeatable | — |
| `--transport` | — | Image format: `oci-archive` or `docker-archive` | `oci-archive` |
| `--cluster-name` | `-c` | Cluster name | `default` |
| `--registry` | — | Private registry URL: `[scheme://][user:pass@]host[:port]` | — |
| `--vip` | — | IPVS VIP for HA load balancing | `10.103.97.2` |
| `--kubelet-config` | — | Custom KubeletConfiguration YAML path | — |

### What It Does

When you run `cluster run`, cyctl performs the following steps:

1. Pulls the cluster image (or uses local cache / local tar)
2. Distributes the image to all nodes via SSH
3. Initializes containerd and kubelet on each node
4. Uses kubeadm to initialize the first master node; remaining masters join the control plane
5. Configures IPVS load balancing for HA (when multiple masters are specified)
6. Worker nodes join the cluster

### Examples

```bash
# Basic: 1 master + 1 worker
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 -p 'YourPassword'

# HA: 3 masters + 2 workers
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p 'YourPassword'

# SSH key authentication
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 \
  -k ~/.ssh/id_rsa

# Custom cluster name + environment variables
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p 'YourPassword' \
  -c production \
  -e POD_CIDR=10.244.0.0/16 \
  -e SVC_CIDR=10.96.0.0/16

# Local tar file
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -p 'YourPassword' \
  --transport oci-archive

# Local tar + private HTTP registry with auth
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_ed25519 \
  --registry http://user:pass@192.168.1.100:30077

# Custom IPVS VIP (HA scenario)
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11 -p 'YourPassword' \
  --vip 10.103.97.100
```

---

## cluster apply

Declarative cluster management from a Clusterfile.

```
cyctl cluster apply [OPTIONS]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--file` | `-f` | Clusterfile path | — |
| `--values` | — | Additional values file | — |
| `--set` | — | Override variable KEY=VALUE, repeatable | — |
| `--cluster-name` | `-c` | Cluster name | `default` |

### Examples

```bash
# Apply a Clusterfile
cyctl cluster apply -f Clusterfile.yaml

# Override variables
cyctl cluster apply -f Clusterfile.yaml --set masters=3 --set nodes=5
```

---

## cluster status

Query the current status of a cluster.

```
cyctl cluster status [OPTIONS] [NAME]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `[NAME]` | — | Cluster name (positional) | `default` |
| `--cluster-name` | `-c` | Cluster name | `default` |

### Output

JSON output includes: `name`, `phase`, `images`, `masters[]`, `workers[]`, `node_status[]` (each with `ip`, `role`, `status`).

### Examples

```bash
# Default cluster
cyctl cluster status

# Named cluster
cyctl cluster status production

# Human-readable table format
cyctl cluster status default -o table
```

Sample JSON output:

```json
{
  "name": "default",
  "phase": "running",
  "images": ["cycore/kubernetes:v1.35.3"],
  "masters": ["10.0.0.1", "10.0.0.2", "10.0.0.3"],
  "workers": ["10.0.0.11", "10.0.0.12"],
  "node_status": [
    {"ip": "10.0.0.1", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.2", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.3", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.11", "role": "node", "status": "Ready"},
    {"ip": "10.0.0.12", "role": "node", "status": "Ready"}
  ]
}
```

---

## cluster inspect

Comprehensive audit of all nodes via SSH. Collects system information, K8s component versions, container runtime status, network configuration, disk usage, and cluster-level resources.

```
cyctl cluster inspect [OPTIONS]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--cluster-name` | `-c` | Cluster name (loads connection info from saved spec) | `default` |
| `--hosts` | — | Host IPs (comma-separated, bypasses cluster spec) | — |
| `--passwd` | `-p` | SSH password | — |
| `--pk` | `-k` | SSH private key path | auto-detected |
| `--port` | — | SSH port | `22` |
| `--user` | `-u` | SSH user | `root` |

### Two Modes

- **Cluster spec mode** — For clusters deployed with `cluster run`, reads saved connection info automatically.
- **Direct mode** — Specify hosts with `--hosts` and provide `--passwd` or `--pk`.

### Data Collected

| Category | Per-Node | Cluster-Level (master0) |
|----------|----------|------------------------|
| System | hostname, OS, kernel, uptime | — |
| K8s | kubeadm/kubelet/kubectl versions | nodes, namespaces, running pods |
| Runtime | containerd version and status, runc, crictl | — |
| Network | CNI interfaces (cali/tunl/vxlan), iptables rule count | services |
| Storage | containerd/etcd/kubelet disk usage | PV list |
| Resources | — | CRD count, `kubectl top nodes` |

### Examples

```bash
# Direct mode with password
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3 -p 'YourPassword'

# Direct mode with SSH key (auto-detected ~/.ssh/id_rsa)
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3

# Using saved cluster spec
cyctl cluster inspect -c mycluster
```

Output includes both human-readable reports and JSON structured data suitable for AI agent parsing.

---

## cluster reset

Destroy a cluster and clean up nodes.

> **WARNING**: This is a destructive operation. Always inspect the cluster before resetting.

```
cyctl cluster reset [OPTIONS] [NAME]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `[NAME]` | — | Cluster name (positional) | `default` |
| `--cluster-name` | `-c` | Cluster name | `default` |
| `--force` | — | Skip confirmation prompt | `false` |
| `--purge` | — | Full cleanup: remove all K8s binaries, runtimes, and data | `false` |

### Two Modes

**Standard reset** (`--force`) — Runs `kubeadm reset`, cleans K8s config directories, iptables/IPVS rules, and stops kubelet/containerd services. Suitable for redeploying the same K8s version.

**Full purge** (`--force --purge`) — In addition to the standard reset, also:
- Removes CNI network interfaces (cali*, tunl0, vxlan.calico, flannel.1, cni0)
- Cleans ip6tables rules
- Deletes containerd data and config (`/var/lib/containerd`, `/etc/containerd`)
- Deletes CNI data (`/var/lib/cni`, `/var/lib/calico`)
- Removes deployment directories (`/opt/cycore`)
- Removes K8s binaries (kubeadm, kubelet, kubectl)
- Removes containerd binaries (containerd, runc, crictl, ctr)
- Deletes systemd unit files and runs `daemon-reload`
- Cleans sysctl configuration
- Cleans libseccomp and ldconfig configuration

Suitable for full uninstall, version changes, or node decommissioning.

### Recommended Operation Sequence

```bash
# 1. Inspect cluster state first
cyctl cluster inspect -c default

# 2. Clean up failed pods if needed
kubectl get pods -A --field-selector=status.phase=Failed -o json | kubectl delete -f -

# 3. Reset after confirming it is safe to destroy
cyctl cluster reset -c default --force --purge
```

### Examples

```bash
# Interactive confirmation
cyctl cluster reset -c default

# Standard reset (for scripts / CI)
cyctl cluster reset -c default --force

# Full purge — restore nodes to pre-K8s state
cyctl cluster reset -c default --force --purge
```

---

## cluster cert

Manage K8s API server certificates.

```
cyctl cluster cert [OPTIONS] [NAME]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `[NAME]` | — | Cluster name (positional) | `default` |
| `--cluster-name` | `-c` | Cluster name | `default` |
| `--alt-names` | — | Additional SANs (comma-separated IPs/DNS names) | — |
| `--renew` | — | Renew all certificates | `false` |

### Examples

```bash
# Renew all certificates
cyctl cluster cert default --renew

# Add additional SANs
cyctl cluster cert default --alt-names api.example.com,10.0.0.100

# Add SANs and renew
cyctl cluster cert default --alt-names new-lb.example.com,10.0.0.100 --renew
```

K8s certificates are valid for 1 year by default. Renew them before expiration.

---

## cluster gen

Generate a Clusterfile from CLI arguments.

```
cyctl cluster gen [OPTIONS]
```

### Examples

```bash
# Generate to stdout
cyctl cluster gen -m 10.0.0.1,10.0.0.2,10.0.0.3 -n 10.0.0.11,10.0.0.12

# Write to file
cyctl cluster gen \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  --image cycore/kubernetes:v1.35.3 \
  -p 'YourPassword' \
  -f Clusterfile.yaml
```
