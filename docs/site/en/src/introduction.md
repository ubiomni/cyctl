# Introduction

cyctl is a Kubernetes cluster lifecycle management CLI written in Rust. It deploys OCI-based cluster images to target nodes over SSH, supporting fully offline installation and built-in high availability (HA).

## Why cyctl

AI training and inference platforms need more than a Kubernetes cluster — they need GPU scheduling, distributed storage, monitoring, and data lake engines. Setting these up manually means dealing with version compatibility, offline packaging, and configuration tuning, over and over.

cyctl reduces this to three steps: **build image → deploy cluster → install components**. All components ship with AI-optimized defaults, ready to use out of the box.

## Key Features

- **One-command deployment** — Deploy a multi-master HA cluster with a single command, auto-configured IPVS, containerd, and kubelet
- **Component orchestration** — 20+ built-in middleware and data platform components (MySQL, Redis, Prometheus, Trino, Spark, etc.) with automatic dependency ordering
- **Full offline support** — Build rootfs images from upstream, pack component bundles, deploy in air-gapped environments
- **Elastic scaling** — Add or remove worker nodes with one command
- **AI Agent native** — JSON structured output, categorized exit codes, `--quiet` mode for direct LLM Agent integration

## AI Infrastructure Scenarios

cyctl is deeply optimized for AI training and inference workloads:

### GPU Cluster Deployment

```bash
# Deploy K8s cluster (with GPU nodes)
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -k ~/.ssh/id_ed25519

# Install GPU operator + training framework scheduling
cyctl component install gpu-operator,training-operator,volcano \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

Once installed, you can submit distributed training jobs (PyTorchJob / MPIJob). Volcano handles Gang Scheduling to ensure GPU resources are allocated atomically.

### AI Data Platform

```bash
# Object storage + data lake engines
cyctl component install rustfs,nessie,trino,spark-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed
```

Build a complete data pipeline from storage to SQL queries:

| Layer | Component | Purpose |
|-------|-----------|---------|
| Object Storage | RustFS | S3-compatible storage for training data, model files, checkpoints |
| Data Catalog | Nessie | Apache Iceberg REST catalog with data versioning |
| Query Engine | Trino | Distributed SQL queries directly on Iceberg tables |
| Compute Engine | Spark | Large-scale data processing, ETL, feature engineering |
| Cache Layer | Alluxio | Data locality caching to accelerate Spark/Trino reads |

### Monitoring and Observability

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

Out-of-the-box monitoring stack: Prometheus collects GPU/node/Pod metrics, Loki aggregates training logs, Grafana provides visualization. prometheus-adapter exposes custom metrics to HPA, enabling auto-scaling of inference services based on GPU utilization.

### Kubelet Optimized for AI Training

cyctl ships with kubelet defaults tuned for AI workloads:

| Optimization | Description |
|-------------|-------------|
| `imageMinimumGCAge: 72h` | Protect images from premature GC in offline environments |
| `serializeImagePulls: false` | Parallel image pulls for faster large-scale deployment |
| `containerLogMaxSize: 50Mi` | Larger log limit for verbose training output |
| `kubeReserved / systemReserved` | Reserve CPU and memory for system processes, prevent training jobs from starving the node |
| `evictionHard.memory: 1Gi` | Early eviction to prevent OOM on GPU nodes |

### AI Agent Integration

All cyctl commands support JSON output and structured error codes, ready for direct invocation by LLM agents like Claude or GPT:

```bash
# Agent queries cluster status
cyctl cluster status default -o json --quiet

# Agent installs a component
cyctl component install redis --package ./pkg --storage-base /data/cycore -o json

# Agent checks Pod health
cyctl cluster inspect --hosts 10.0.0.1 -k ~/.ssh/id_rsa -o json --quiet
```

See the [AI Agent Integration Guide](./guides/ai-agent.md) for details.

## Architecture Overview

cyctl operates through SSH connections to target nodes:

1. **Image build** — Download K8s binaries, containerd, and system images from upstream, package into an OCI rootfs
2. **Image distribution** — Transfer the rootfs to all nodes via SSH
3. **Node initialization** — Install containerd, kubelet, configure kernel parameters and IPVS modules
4. **Cluster bootstrap** — `kubeadm init` on the first master, remaining masters and workers join
5. **HA configuration** — Auto-configure IPVS load balancing across API servers
6. **Registry setup** — Start a local OCI registry on each node and load pre-fetched system images

All cluster state is persisted locally, allowing subsequent operations (scaling, inspection, reset) to reference saved connection details without re-specifying credentials.
