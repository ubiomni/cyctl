# node -- Node Management

The `node` command group manages adding and removing nodes from an existing cluster.

## node add

Add worker or master nodes to a cluster.

```
cyctl node add [OPTIONS]
```

### Flags

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--masters` | `-m` | Master node IPs to add (comma-separated) | — |
| `--nodes` | `-n` | Worker node IPs to add (comma-separated) | — |
| `--passwd` | `-p` | SSH password | — |
| `--pk` | `-k` | SSH private key path | — |
| `--cluster-name` | `-c` | Cluster name | `default` |

### Examples

```bash
# Add worker nodes
cyctl node add -n 10.0.0.13,10.0.0.14 -p 'YourPassword'

# Add a master node (extends HA)
cyctl node add -m 10.0.0.4 -p 'YourPassword'

# Use SSH key authentication
cyctl node add -n 10.0.0.13 -k ~/.ssh/id_rsa

# Specify a named cluster
cyctl node add -n 10.0.0.15 -p 'YourPassword' -c production
```

---

## node delete

Remove worker or master nodes from a cluster. The node is drained (pods are evicted) before removal.

```
cyctl node delete [OPTIONS]
```

### Flags

Same as `node add`: `--masters`, `--nodes`, `--passwd`, `--pk`, `--cluster-name`.

### Examples

```bash
# Delete a worker node
cyctl node delete -n 10.0.0.14 -p 'YourPassword'

# Delete a master node
cyctl node delete -m 10.0.0.4 -p 'YourPassword'

# Delete from a named cluster
cyctl node delete -n 10.0.0.14 -p 'YourPassword' -c production
```

> Pods running on the deleted node are drained first, then the node is removed from the cluster. Plan for workload redistribution before removing nodes.
