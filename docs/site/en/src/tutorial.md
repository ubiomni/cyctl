# Tutorial: Complete Offline Deployment

This tutorial walks through the entire process of building a Kubernetes cluster from scratch and installing a full component platform, step by step.

Three phases:

| Phase | Content | End State |
|-------|---------|-----------|
| 1 | Build image, deploy minimal cluster | All nodes Ready |
| 2 | Pack and install base components | Storage, middleware, monitoring Pods Running |
| 3 | Distributed deployment and data platform | Data platform Pods Running |

---

## Phase 1: Build Image and Deploy Cluster

### 1.1 Build the Cluster Image

On a machine with internet access, build a Kubernetes rootfs image:

```bash
cyctl image build-rootfs \
  --k8s-version v1.35.3 \
  --arch amd64 \
  --addon calico \
  --output-dir ./out
```

Check the output:

```bash
ls -lh ./out
# kubernetes-v1.35.3-amd64.tar
```

### 1.2 Distribute to Target Server

**Option A: Direct upload**

```bash
scp ./out/kubernetes-v1.35.3-amd64.tar root@<MASTER_IP>:/tmp/
```

**Option B: Push to private registry**

```bash
cyctl image load --input ./out/kubernetes-v1.35.3-amd64.tar
cyctl image push <REGISTRY>/kubernetes:v1.35.3
```

### 1.3 Deploy the Cluster

On the target server, deploy with a single command:

```bash
# Single master
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m <MASTER_IP> \
  -k ~/.ssh/id_ed25519

# HA: 3 masters + workers
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m <MASTER1>,<MASTER2>,<MASTER3> \
  -n <WORKER1>,<WORKER2> \
  -k ~/.ssh/id_ed25519 \
  --registry http://<USER>:<PASS>@<REGISTRY_IP>:<PORT>
```

### 1.4 Verify

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes should be `Ready` and system Pods `Running`.

---

## Phase 2: Install Base Components

### 2.1 Pack the Offline Bundle

On a machine with internet access:

```bash
# Pack all components
cyctl component pack --all-profiles

# Pack specific components only
cyctl component pack mysql,redis,prometheus

# Config only (skip image pull)
cyctl component pack --skip-images
```

Transfer to the target server:

```bash
scp cycore-k8s-offline-*.tar.gz root@<MASTER_IP>:/tmp/
```

### 2.2 Extract

```bash
cd /tmp
tar xf cycore-k8s-offline-*.tar.gz
```

### 2.3 Storage and Infrastructure

> Components have dependencies. Install in the order shown.

```bash
# Batch 1: Local storage
cyctl component install local-path-provisioner \
  --package ./cycore-k8s-offline --storage-base /data/cycore

# Batch 2: Scheduling and metrics
cyctl component install volcano,kuberay,metrics-server \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

### 2.4 Middleware

```bash
cyctl component install mysql,redis,nginx \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

> Without shared storage, pin stateful services to a specific node:
> ```bash
> cyctl component install mysql \
>   --package ./cycore-k8s-offline --storage-base /data/cycore \
>   --node-selector <NODE_NAME>
> ```

### 2.5 Monitoring and Logging

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### 2.6 Training and GPU (Optional)

```bash
cyctl component install training-operator,gpu-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

Verify GPU:

```bash
kubectl run gpu-test --rm -it --restart=Never \
  --image=cycore.local:4000/cuda:12.4.1-base-ubi8 \
  --overrides='{"spec":{"containers":[{"name":"gpu-test","image":"cycore.local:4000/cuda:12.4.1-base-ubi8","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}' \
  --command -- nvidia-smi
```

### 2.7 Verify

```bash
kubectl get pods -A
kubectl top nodes
```

---

## Phase 3: Distributed Deployment and Data Platform

### 3.1 Distributed Storage and Monitoring

Use `--profile distributed` to switch to HA architecture:

```bash
# Step 1: Object storage and message queue
cyctl component install rustfs,nats \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed

# Step 2: Monitoring and logging (Loki depends on RustFS)
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed
```

> Distributed Loki requires pre-created buckets: `loki-chunks`, `loki-ruler`, `loki-admin`

**Components with distributed support:**

| Component | Default Mode | Distributed Mode |
|-----------|-------------|-----------------|
| loki | Single instance, local storage | Microservices, S3 via RustFS |
| prometheus | Single replica | Dual replica, cross-node |
| nats | Single node | 3-node cluster |
| trino | Single coordinator | Coordinator + 3 workers |
| nessie | 2 replicas | 3 replicas, depends on PostgreSQL |
| rustfs | Single node | Multi-node |
| alluxio | Standalone | HA mode |

### 3.2 Data Platform

```bash
# Prerequisite: Nessie depends on PostgreSQL
cyctl component install postgresql \
  --package ./cycore-k8s-offline --storage-base /data/cycore

# Data platform components
cyctl component install nessie,trino,spark-operator,strimzi-kafka,clickhouse-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed

# Cache layer (pin to a node without shared storage)
cyctl component install alluxio \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --node-selector kubernetes.io/hostname=<NODE_NAME>
```

### 3.3 Verify

```bash
kubectl get pods -A
kubectl top nodes
```

### 3.4 Uninstall and Reset

```bash
# Uninstall specific components
cyctl component uninstall metrics-server,prometheus,loki,alloy \
  --package ./cycore-k8s-offline

# Reset the entire cluster
cyctl cluster reset --data-dir ~/.cycore --force
```
