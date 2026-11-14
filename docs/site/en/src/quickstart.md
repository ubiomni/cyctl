# Quick Start

This guide walks through the core workflow: building a rootfs image, deploying a cluster, scaling, and tearing down.

## 1. Build a Rootfs Image (Optional)

If you do not have a pre-built cluster image, build one from upstream components. This bundles Kubernetes binaries, container runtime, and system images into an OCI archive for offline deployment.

```bash
# Basic build for K8s v1.35.3
cyctl image build-rootfs --k8s-version v1.35.3

# With a download proxy
cyctl image build-rootfs --k8s-version v1.35.3 --proxy socks5://127.0.0.1:1080

# Include Calico CNI addon
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico

# Specify Calico version
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico:3.30.0

# Full example with registry mirror and output directory
cyctl image build-rootfs --k8s-version v1.35.3 \
  --arch amd64 \
  --addon calico \
  --registry-mirror registry.k8s.io=my-mirror.example.com/google_containers \
  --output-dir ./out
```

Output: `./out/kubernetes-v1.35.3-amd64.tar`

The rootfs image includes pre-fetched K8s system container images (kube-apiserver, etcd, etc.), so nodes do not need internet access during deployment.

## 2. Deploy a 3-Master HA Cluster

```bash
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p 'YourSecurePassword'
```

This command will:
1. Pull the cluster image (or use local cache)
2. Distribute it to all nodes via SSH
3. Initialize containerd and kubelet on each node
4. Bootstrap the first master with kubeadm, then join the remaining masters
5. Configure IPVS load balancing for HA
6. Join worker nodes to the cluster

For SSH key authentication instead of a password:

```bash
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -k ~/.ssh/id_rsa
```

To deploy from a local rootfs tar file:

```bash
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.2 -p 'YourSecurePassword'
```

## 3. Check Cluster Status

```bash
cyctl cluster status default
```

JSON output:
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

For human-readable output:

```bash
cyctl cluster status default -o table
```

## 4. Scale the Cluster

### Add worker nodes

```bash
cyctl node add -n 10.0.0.13 -p 'YourSecurePassword'
```

### Add a master node (extend HA)

```bash
cyctl node add -m 10.0.0.4 -p 'YourSecurePassword'
```

### Remove a worker node

```bash
cyctl node delete -n 10.0.0.12 -p 'YourSecurePassword'
```

## 5. Run Remote Commands

Execute commands on cluster nodes via SSH:

```bash
cyctl remote exec -m 10.0.0.1 -p 'YourSecurePassword' \
  -- 'kubectl get nodes -o wide'
```

## 6. Inspect the Cluster

Run a comprehensive audit of all nodes, collecting system information, K8s component versions, runtime status, network configuration, and disk usage:

```bash
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3 -p 'YourSecurePassword'
```

Or use a saved cluster spec:

```bash
cyctl cluster inspect -c default
```

## 7. Destroy the Cluster

### Standard reset

Runs `kubeadm reset`, clears K8s configuration, iptables/IPVS rules, and stops kubelet/containerd:

```bash
cyctl cluster reset default --force
```

### Full purge

In addition to the standard reset, removes all K8s binaries, containerd data, CNI interfaces, systemd units, and sysctl configuration. Restores the node to a pre-Kubernetes state:

```bash
cyctl cluster reset default --force --purge
```

> **Warning:** `--purge` is destructive and irreversible. Always inspect the cluster before resetting:
>
> ```bash
> cyctl cluster inspect -c default
> cyctl cluster reset default --force --purge
> ```
