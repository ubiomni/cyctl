# Advanced Usage

## Mirror Acceleration

### Container Image Mirrors (`--registry-mirror`)

`--registry-mirror` replaces the registry prefix in container image references during `image build-rootfs`. It supports two modes.

**Universal mode** -- for self-hosted registries that mirror all upstream registries. The full repository path is preserved:

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror my-harbor.local
# registry.k8s.io/kube-apiserver:v1.35.3 -> my-harbor.local/kube-apiserver:v1.35.3
# docker.io/library/busybox:latest        -> my-harbor.local/library/busybox:latest
# quay.io/calico/node:v3.30.0            -> my-harbor.local/calico/node:v3.30.0
```

**Per-source registry mapping** -- for public mirrors with flattened paths. Only the image name is kept:

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=mirror.example.com/google_containers \
  --registry-mirror docker.io=hub-mirror.example.com \
  --registry-mirror quay.io=quay.mirrors.example.com
# registry.k8s.io/coredns/coredns:v1.12.0 -> mirror.example.com/google_containers/coredns:v1.12.0
```

**Mixed mode** -- per-source mappings take priority; unmatched registries fall back to the universal mirror:

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror my-harbor.local \
  --registry-mirror registry.k8s.io=mirror.example.com/google_containers
# registry.k8s.io/* -> mirror.example.com (per-source, flattened path)
# docker.io/*       -> my-harbor.local (universal, full path)
# quay.io/*         -> my-harbor.local (universal, full path)
```

### Binary Download Mirror (`--mirror`)

`--mirror` accelerates binary component downloads (kubeadm, kubelet, containerd, etc.) by replacing the scheme and host in download URLs:

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --mirror https://my-mirror.example.com
```

### Proxy

For environments with a forward proxy:

```bash
# HTTP proxy
cyctl image build-rootfs --k8s-version v1.35.3 \
  --proxy http://proxy.example.com:8080

# SOCKS5 proxy
cyctl image build-rootfs --k8s-version v1.35.3 \
  --proxy socks5://127.0.0.1:1080
```

## Offline Deployment

Complete workflow for deploying in an air-gapped environment.

```bash
# === On a connected machine ===

# 1. Build the rootfs image (includes K8s system container images)
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64

# With mirror acceleration
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64 \
  --proxy socks5://127.0.0.1:1080 \
  --registry-mirror registry.k8s.io=mirror.example.com/google_containers

# 2. Prepare application images
cyctl image pull docker.io/library/nginx:latest
cyctl image save nginx:latest --output nginx.tar

# 3. Transfer to the air-gapped environment
scp kubernetes-v1.35.3-amd64.tar bastion:/data/
scp nginx.tar bastion:/data/
scp cyctl bastion:/usr/local/bin/

# === On the air-gapped machine ===

# 4. Deploy the cluster (rootfs already contains system images)
cyctl cluster run /data/kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 \
  -n 10.0.0.11 \
  -p YourPassword \
  --transport oci-archive

# 5. Load application images
cyctl image load --input /data/nginx.tar
```

The rootfs tar file includes `registry/images.tar.gz` containing pre-fetched K8s system images. During deployment, cyctl starts a local registry on each node and loads these images via `ctl registry-load`, so nodes never need internet access.

## Multi-Cluster Management

cyctl supports managing multiple named clusters on the same machine:

```bash
# Deploy dev cluster
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.1.0.1 -n 10.1.0.11 \
  -p YourPassword -c dev

# Deploy prod cluster
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.2.0.1,10.2.0.2,10.2.0.3 \
  -n 10.2.0.11,10.2.0.12,10.2.0.13 \
  -p YourPassword -c prod

# Check status independently
cyctl cluster status dev
cyctl cluster status prod

# Operate on a specific cluster
cyctl node add -n 10.2.0.14 -p YourPassword -c prod
```

## Custom Rootfs

Use a Kubefile to customize the cluster image:

```dockerfile
FROM cycore/kubernetes:v1.35.3

# Add custom CNI manifests
COPY calico.yaml manifests/

# Add custom configuration
COPY custom-config.yaml etc/

# Add custom post-install script
COPY post-install.sh scripts/
```

```bash
cyctl image build -t my-k8s:v1.35.3 -f Kubefile .
cyctl cluster run my-k8s:v1.35.3 -m 10.0.0.1 -p YourPassword
```

## Debug Mode

Control log verbosity with the `RUST_LOG` environment variable:

```bash
# Debug-level logging
RUST_LOG=cycore=debug cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p YourPassword

# Trace-level logging (most verbose)
RUST_LOG=cycore=trace cyctl cluster run ...

# Module-specific logging
RUST_LOG=cycore::ssh=debug cyctl remote exec ...
```

## Certificate Renewal

Kubernetes certificates are valid for one year by default. Renew them before expiration:

```bash
# Renew all certificates
cyctl cluster cert default --renew

# Add new SANs (e.g., after a load balancer VIP change)
cyctl cluster cert default --alt-names new-lb.example.com,10.0.0.100 --renew
```

## Kubelet Configuration

`cyctl cluster run` deploys the cluster via kubeadm `--config` and includes kubelet defaults optimized for offline environments and AI training workloads:

| Parameter | cyctl Default | K8s Default | Reason |
|-----------|--------------|-------------|--------|
| `imageMinimumGCAge` | 72h | 0s/2m | Protects offline images from premature GC |
| `imageGCHighThresholdPercent` | 75 | 85 | Leaves 10% buffer before eviction threshold |
| `imageGCLowThresholdPercent` | 70 | 80 | Pairs with high threshold |
| `cgroupDriver` | systemd | cgroupfs | Standard for modern distributions |
| `kubeReserved` | cpu:2, memory:2Gi, ephemeral-storage:1Gi | none | Reserves resources for kubelet/kube-proxy |
| `systemReserved` | cpu:2, memory:2Gi, ephemeral-storage:1Gi | none | Reserves resources for system processes |
| `evictionHard.memory.available` | 1Gi | 100Mi | Earlier eviction prevents node OOM |
| `containerLogMaxSize` | 50Mi | 10Mi | Larger logs for training workloads |
| `serializeImagePulls` | false | true | Parallel image pulls speed up deployment |
| `protectKernelDefaults` | true | false | Protects sysctl kernel parameters |

Additional built-in optimization: kube-proxy runs in IPVS mode for better performance and VPN compatibility.

**Custom overrides:** Pass a YAML file with `--kubelet-config` to override any default (deep merge, user values take priority):

```yaml
# kubelet-overrides.yaml
imageMinimumGCAge: 168h
kubeReserved:
  cpu: "4"
  memory: 4Gi
```

```bash
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 \
  -k ~/.ssh/id_rsa \
  --kubelet-config kubelet-overrides.yaml
```

## Component Dependencies and Install Order

Some components depend on services provided by other components.

### Standalone Mode

Install in three batches. Components within each batch have no ordering requirements.

**Batch 1 -- Infrastructure (no dependencies):**

```
local-path-provisioner, volcano, training-operator, kuberay,
gpu-operator, nats, mysql, redis, rustfs, postgresql, nginx
```

**Batch 2 -- Monitoring stack (internal ordering):**

```
metrics-server -> prometheus -> prometheus-adapter -> loki -> alloy
```

**Batch 3 -- Data platform (depends on Batch 1 middleware):**

```
nessie (requires postgresql), alluxio (requires rustfs),
spark-operator, strimzi-kafka, trino, clickhouse-operator
```

### Distributed Mode

Use `--profile distributed` for HA architectures. Note the additional dependency: Loki distributed requires RustFS.

**Step 1 -- K8s infrastructure (stateless, no dependencies):**

```bash
cyctl component install local-path-provisioner \
  --package /tmp/offline-pkg --storage-base /mnt/shared

cyctl component install volcano,training-operator,kuberay,gpu-operator,metrics-server \
  --package /tmp/offline-pkg --storage-base /mnt/shared
```

**Step 2 -- Middleware:**

```bash
# Databases and caches -- shared high-performance storage
cyctl component install mysql,redis,postgresql,nginx \
  --package /tmp/offline-pkg --storage-base /mnt/shared

# Distributed middleware -- each node stores data independently
cyctl component install rustfs,nats \
  --package /tmp/offline-pkg --storage-base /data/local \
  --profile distributed
```

**Step 3 -- Monitoring and logging:**

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package /tmp/offline-pkg --storage-base /mnt/shared \
  --profile distributed
```

**Step 4 -- Data platform (requires postgresql + rustfs):**

```bash
cyctl component install nessie,trino,spark-operator,strimzi-kafka,clickhouse-operator \
  --package /tmp/offline-pkg --storage-base /mnt/shared \
  --profile distributed

cyctl component install alluxio \
  --package /tmp/offline-pkg --storage-base /data/local
```

## Distributed Profiles

Components that support `--profile distributed`:

| Component | Standalone | Distributed | Storage | Notes |
|-----------|-----------|-------------|---------|-------|
| Loki | Single binary, filesystem | Microservices (ingester x3, distributor x2, querier x2) | S3 via RustFS | Requires RustFS; 30-day retention |
| Prometheus | 1 replica | 2 replicas + hard anti-affinity | Local hostPath per replica | Replicas on separate nodes |
| NATS | Single node JetStream | 3-node Raft cluster | Local hostPath per node | Topology spread constraints |
| Trino | coordinator + 2 workers | coordinator + 3 workers | None (compute engine) | 2-4 GiB worker memory |
| Nessie | 2 replicas | 3 replicas | None (data in PostgreSQL) | Stateless, depends on PostgreSQL |
| RustFS | Single node | Distributed multi-node | Local hostPath | Erasure coding |

`--profile distributed` only affects components that define a distributed profile. Other components automatically use the default standalone configuration.

```bash
# Single component
cyctl component install loki --profile distributed \
  --package /tmp/offline-pkg --storage-base /mnt/shared

# Batch install -- profile applies only to components that support it
cyctl component install prometheus,loki,nats,trino,nessie \
  --profile distributed \
  --package /tmp/offline-pkg --storage-base /mnt/shared
```

## Node Selector

Stateful components using hostPath storage can lose data if their pod is rescheduled to a different node. Use `--node-selector` to pin them:

```bash
# Shorthand: automatically uses kubernetes.io/hostname as the label key
cyctl component install mysql --node-selector worker-01 \
  --package /tmp/offline-pkg --storage-base /data/k8s

# Full key=value format: supports any label
cyctl component install mysql --node-selector disktype=ssd \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

Pin multiple components to a dedicated storage node:

```bash
cyctl component install mysql,redis,postgresql \
  --node-selector worker-01 \
  --package /tmp/offline-pkg --storage-base /data/k8s
```

Distributed-mode components deploy across multiple nodes, so `--node-selector` binding to a single node is generally not recommended.

## Component Password Configuration

All middleware component passwords are **auto-generated** (24-character random values) at install time and saved to `~/.cycore/component-secrets.env`. Use `--set` to override.

> Shared variables (e.g., `rustfs_secret_key`) are automatically reused across components that depend on them.

### Password Variables

| Component | Variable | Default |
|-----------|----------|---------|
| MySQL | `mysql_root_password` | Auto-generated |
| Redis | `redis_password` | Auto-generated |
| PostgreSQL | `postgresql_password` | Auto-generated |
| Grafana | `grafana_admin_password` | Auto-generated |
| RustFS | `rustfs_access_key` | Auto-generated |
| RustFS | `rustfs_secret_key` | Auto-generated |
| Nessie | `nessie_db_password` | Auto-generated |

### Override at Install Time

```bash
cyctl component install redis,mysql,rustfs \
  --package /tmp/offline-pkg \
  --set mysql_root_password=MySQL@Prod \
  --set redis_password=Redis@Prod \
  --set rustfs_secret_key=RustFS@Prod
```

### Update Passwords on Running Components

Re-run `component install` with the new password (equivalent to `helm upgrade`):

```bash
cyctl component install grafana \
  --package /tmp/offline-pkg \
  --set grafana_admin_password=NewAdmin@2026
```

### View Current Passwords

Read from Kubernetes Secrets:

```bash
# MySQL
kubectl -n middleware get secret mysql -o jsonpath='{.data.root-password}' | base64 -d; echo

# Redis
kubectl -n middleware get secret redis -o jsonpath='{.data.redis-password}' | base64 -d; echo

# Grafana
kubectl -n monitoring get secret prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo

# RustFS
kubectl -n middleware get secret rustfs-secret -o jsonpath='{.data.secret_key}' | base64 -d; echo
```

## Component Storage Requirements

Components use the `--storage-base` directory for hostPath storage. Some components have strict storage type requirements.

### Cannot Use Shared Storage (Correctness Issues)

These components must use node-local storage, even if shared storage is high-performance:

| Component | Reason |
|-----------|--------|
| Prometheus | TSDB uses `mmap` for data files. NFS does not support `mmap` correctly, causing crashes during compaction. |
| NATS (distributed) | Each pod maintains an independent Raft log. Shared directories cause WAL corruption as pods overwrite each other's files. |
| RustFS (distributed) | Erasure-coded shards are unique per node. Shared directories cause shard overwrites. |

### Depends on Shared Storage Type

| Component | Constraint | How to Test |
|-----------|-----------|-------------|
| MySQL | InnoDB requires `O_DIRECT` to bypass OS page cache | `dd if=/dev/zero of=<path>/test bs=4k count=1 oflag=direct` -- success means the storage works. Lustre/GPFS/BeeGFS typically support it; NFS/CephFS typically do not. |

### Prefers Local Disk (Performance)

Shared storage works functionally but degrades performance:

| Component | Notes |
|-----------|-------|
| PostgreSQL | WAL and checkpoints rely on `fsync`. Network round-trip per `fsync` increases transaction latency. |
| Redis | AOF `fsync` frequency (everysec/always) adds latency on network storage. |

### Can Use Shared Storage

| Component | Reason |
|-----------|--------|
| Loki (standalone) | Sequential writes, low `fsync` requirements |
| Loki (distributed) | Uses S3 backend (RustFS), no local storage |
| Grafana | Lightweight metadata only |
| Nginx | Primarily read-only static file serving |
| NATS (standalone) | Single pod, no multi-write conflicts |

### Decision Rules

1. Application-layer multi-replica with independent data per replica -> local storage only (NATS distributed, RustFS distributed)
2. Requires `mmap` -> cannot use NFS (Prometheus)
3. Requires `O_DIRECT` -> test with `dd oflag=direct` (MySQL)
4. Requires strict `fsync` -> shared storage works but hurts performance (PostgreSQL, Redis)
5. Lightweight IO or stateless -> shared storage is fine (Grafana, Nginx, Loki distributed)
