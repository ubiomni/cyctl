# component — Component Management

The `component` command group manages Kubernetes add-on components: packaging for offline use, installing, uninstalling, and verifying.

## component pack

Package all component images and Helm charts into an offline archive.

```bash
cyctl component pack                           # standalone profile only
cyctl component pack --all-profiles            # include distributed images
cyctl component pack --profile distributed     # only distributed profile
cyctl component pack --skip-images             # config files only (no images)
cyctl component pack --output my-package.tar.gz
```

| Flag | Description | Default |
|------|-------------|---------|
| `--all-profiles` | Include images for all deployment profiles | `false` |
| `--profile` | Pack images for a specific profile only | `standalone` |
| `--skip-images` | Skip image packaging, only include configs | `false` |
| `--output` | Output archive path | auto-generated |

## component install

Install one or more components into the cluster.

```
cyctl component install NAMES --package PATH --storage-base PATH [OPTIONS]
```

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--package` | Offline package path (tar.gz or extracted directory) | -- |
| `--storage-base` | hostPath root directory for persistent volume data | -- |
| `--profile` | Deployment profile: `standalone` or `distributed` | `standalone` |
| `--set KEY=VALUE` | Override configuration values. Repeatable | -- |
| `--node-selector` | Pin component to a specific node (hostname or key=value) | -- |
| `--dry-run` | Preview generated manifests without applying | `false` |

### Examples

```bash
# Install a single component
cyctl component install prometheus \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Install multiple components
cyctl component install mysql,redis,postgresql \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Install with custom passwords
cyctl component install mysql,redis \
  --package /tmp/offline-pkg --storage-base /data/k8s \
  --set mysql_root_password=MySecurePass \
  --set redis_password=RedisSecurePass

# Distributed profile
cyctl component install loki,nats,prometheus \
  --package /tmp/offline-pkg --storage-base /data/k8s \
  --profile distributed

# Pin to a specific node
cyctl component install mysql --node-selector worker-01 \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Pin using arbitrary label
cyctl component install mysql --node-selector disktype=ssd \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Dry run
cyctl component install prometheus --dry-run \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

### Install Order and Dependencies

Components have dependency relationships that dictate install order. Install in the following sequence:

**1. K8s Infrastructure (no dependencies)**

```bash
cyctl component install volcano,kuberay,metrics-server,local-path-provisioner \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

**2. Middleware**

```bash
cyctl component install mysql,redis,postgresql,nginx \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

**3. Object Storage (install before Loki distributed)**

```bash
cyctl component install rustfs,nats \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

**4. Monitoring (Loki distributed requires RustFS)**

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

**5. Data Platform (requires PostgreSQL and other middleware)**

```bash
cyctl component install nessie,trino,spark-operator,strimzi-kafka,clickhouse-operator,alluxio \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

Key dependency relationships:

| Component | Depends On | Reason |
|-----------|-----------|--------|
| prometheus | local-path-provisioner | TSDB uses PVC (local-path StorageClass) |
| prometheus-adapter | prometheus | Reads metrics from Prometheus |
| alloy | loki | Pushes logs to Loki |
| loki (distributed) | rustfs | S3 object storage backend |
| nessie | postgresql | JDBC connection for catalog storage |
| alluxio | rustfs | S3 endpoint for object storage |

### Credentials

All middleware component passwords are **auto-generated** at install time and saved to `~/.cycore/component-secrets.env`. Use `--set` to override.

| Component | Variable | Override |
|-----------|----------|---------|
| MySQL | `mysql_root_password` | `--set mysql_root_password=XXX` |
| Redis | `redis_password` | `--set redis_password=XXX` |
| PostgreSQL | `postgresql_password` | `--set postgresql_password=XXX` |
| Grafana | `grafana_admin_password` | `--set grafana_admin_password=XXX` |
| RustFS | `rustfs_access_key` / `rustfs_secret_key` | `--set rustfs_secret_key=XXX` |
| Nessie | `nessie_db_password` | `--set nessie_db_password=XXX` |

To view the current password for a running component:

```bash
# From local secrets file
cat ~/.cycore/component-secrets.env

# From Kubernetes Secret
kubectl -n middleware get secret mysql -o jsonpath='{.data.root-password}' | base64 -d
kubectl -n middleware get secret redis -o jsonpath='{.data.redis-password}' | base64 -d
kubectl -n monitoring get secret prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
kubectl -n middleware get secret rustfs-secret \
  -o jsonpath='{.data.secret_key}' | base64 -d
```

To change a password after installation, re-run `component install` with the new value (equivalent to a Helm upgrade):

```bash
cyctl component install grafana \
  --package /tmp/offline-pkg \
  --set grafana_admin_password=NewSecurePass
```

### Node Selector

Stateful components using hostPath storage (MySQL, Redis, PostgreSQL, etc.) will lose data if their Pod is rescheduled to a different node. Use `--node-selector` to pin components:

```bash
# Shorthand: uses kubernetes.io/hostname as the label key
cyctl component install mysql --node-selector worker-01 \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Full key=value format: supports any label
cyctl component install mysql --node-selector disktype=ssd \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

Distributed-profile components are typically deployed across multiple nodes; using `--node-selector` to bind them to a single node is not recommended.

---

## component uninstall

Remove installed components.

```bash
# Uninstall specific components
cyctl component uninstall prometheus,loki

# Uninstall all components
cyctl component uninstall --all
```

---

## component list

List all available components defined in the component definitions.

```bash
cyctl component list
```

## component status

Show runtime status of installed components.

```bash
cyctl component status
```

## component verify

Validate that the offline package contains all images required by the component charts.

```bash
cyctl component verify --package /tmp/offline-pkg
```

---

## Distributed Profile

Several components support a `distributed` deployment profile for high availability. Use `--profile distributed` during installation. Components without a distributed profile automatically fall back to `standalone`.

| Component | Standalone | Distributed |
|-----------|-----------|-------------|
| **Loki** | Single binary, filesystem storage | Microservices (ingester x3, distributor x2, querier x2, compactor x1, gateway x1), S3/RustFS backend |
| **NATS** | Single node JetStream | 3-node Raft cluster |
| **Prometheus** | 1 replica, alertmanager disabled | 2 replicas + hard anti-affinity, alertmanager x2 |
| **Trino** | Coordinator + 2 workers | Coordinator + 3 workers |
| **Nessie** | 2 replicas | 3 replicas |
| **RustFS** | Single node | Distributed multi-node (erasure coding) |

Loki distributed mode requires RustFS as its S3 backend -- install RustFS first.

### Distributed Install Example

```bash
# Middleware with distributed profile (each node stores data independently)
cyctl component install rustfs,nats \
  --package /tmp/offline-pkg --storage-base /data/local \
  --profile distributed

# Monitoring stack
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package /tmp/offline-pkg --storage-base /data/shared \
  --profile distributed

# Data platform
cyctl component install nessie,trino,spark-operator \
  --package /tmp/offline-pkg --storage-base /data/shared \
  --profile distributed
```

### Offline Packaging for Distributed

```bash
# Default: only standalone images
cyctl component pack

# Include all profiles
cyctl component pack --all-profiles

# Only distributed profile images
cyctl component pack --profile distributed
```
