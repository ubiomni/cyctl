# ctl — System Control

The `ctl` command group contains low-level node operations for system configuration, runtime initialization, and diagnostics. These commands are typically invoked automatically by higher-level commands like `cluster run` and `node add`, but they can also be used manually for debugging or custom deployment workflows.

## ctl hosts

Manage `/etc/hosts` entries on the local node.

```bash
# List all entries
cyctl ctl hosts list

# Add an entry
cyctl ctl hosts add --ip 10.0.0.1 --domain apiserver.cluster.local

# Delete an entry
cyctl ctl hosts delete --domain apiserver.cluster.local
```

## ctl hostname

Return the local hostname.

```bash
cyctl ctl hostname
# Output: {"hostname": "node01"}
```

## ctl cri

Detect container runtime interface (CRI) configuration.

```bash
# Detect CRI socket path
cyctl ctl cri socket
# Output: {"socket": "/run/containerd/containerd.sock"}

# Get cgroup driver
cyctl ctl cri cgroup-driver
# Output: {"cgroup_driver": "systemd"}
```

## ctl cert

Generate low-level Kubernetes PKI certificates.

```bash
cyctl ctl cert \
  --cert-path /etc/kubernetes/pki \
  --alt-names 10.0.0.1,api.example.com \
  --node-name master01 \
  --service-cidr 10.96.0.0/16 \
  --dns-domain cluster.local
```

## ctl ipvs

Manage IPVS load balancing rules for API server high availability.

```bash
# Create IPVS rules
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --rs 10.0.0.2:6443

# Run as daemon with health checking
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --rs 10.0.0.2:6443 --run

# Clean up IPVS rules
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --clean
```

## ctl initsystem

Manage systemd services on the local node.

```bash
cyctl ctl initsystem enable --name kubelet
cyctl ctl initsystem start --name containerd
cyctl ctl initsystem stop --name kubelet
cyctl ctl initsystem restart --name containerd

cyctl ctl initsystem is-active --name kubelet
# Output: {"active": true}

cyctl ctl initsystem is-enabled --name kubelet
# Output: {"enabled": true}

cyctl ctl initsystem is-exists --name kubelet
# Output: {"exists": true}
```

## ctl init-kube

Initialize Kubernetes components on a node. Installs kubelet, kubeadm, kubectl, configures sysctl parameters, and loads required kernel modules.

```bash
cyctl ctl init-kube --bin-dir /usr/local/bin --rootfs /var/lib/cycore/rootfs
```

## ctl init-cri

Initialize the container runtime (containerd). Supports both containerd v1.x and v2.x, with automatic version detection and configuration generation.

```
cyctl ctl init-cri [OPTIONS]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--registry-domain` | Registry domain/IP | `cycore.hub` |
| `--registry-port` | Registry port | `4000` |
| `--registry-scheme` | Protocol: `http` or `https` | `https` |
| `--containerd-version` | containerd major version (1 or 2) | auto-detect |
| `--bin-dir` | Binary install directory | `/usr/bin` |
| `--rootfs` | Rootfs path | -- |

### Examples

```bash
# Standard (auto-detect containerd version)
cyctl ctl init-cri \
  --registry-domain cycore.hub \
  --registry-port 4000 \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs

# Force containerd 2.x (K8s 1.33+)
cyctl ctl init-cri \
  --registry-domain cycore.hub \
  --registry-port 4000 \
  --containerd-version 2 \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs

# HTTP private registry
cyctl ctl init-cri \
  --registry-domain 192.168.1.100 \
  --registry-port 5000 \
  --registry-scheme http \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs
```

## ctl registry-load

Load prefetched container images from a rootfs archive into a running registry. After cluster deployment, the registry automatically contains K8s system images.

```
cyctl ctl registry-load [OPTIONS]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--archive` | Image archive path (OCI tar.gz) | required |
| `--registry` | Target registry address | `cycore.hub:4000` |
| `--insecure` | Allow HTTP registry | `false` |

```bash
# Load into local registry
cyctl ctl registry-load --archive /opt/cycore/registry/images.tar.gz

# Load into remote HTTP registry
cyctl ctl registry-load \
  --archive /opt/cycore/registry/images.tar.gz \
  --registry 192.168.1.100:5000 \
  --insecure
```

## ctl init-registry

Initialize a local registry instance.

```bash
cyctl ctl init-registry \
  --data /var/lib/registry \
  --config /etc/registry \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs
```

## ctl check

Run pre-flight checks before cluster deployment. Verifies root privileges, port availability, Docker conflicts, and existing Kubernetes installations.

```bash
cyctl ctl check
```

## ctl clean

Clean up node artifacts (container runtime data, registry data, binaries).

```bash
cyctl ctl clean \
  --cri-data /var/lib/containerd \
  --registry-data /var/lib/registry \
  --registry-config /etc/registry \
  --bin-dir /usr/local/bin
```

## ctl token

Generate a kubeadm join token for adding nodes to the cluster.

```bash
cyctl ctl token
# Output: {"join_command": "kubeadm join 10.0.0.1:6443 --token abc123 --discovery-token-ca-cert-hash sha256:..."}
```

## ctl tar / untar

Archive and extract utilities.

```bash
cyctl ctl tar --source /path/to/dir --dest /path/to/archive.tar.gz
cyctl ctl untar --source /path/to/archive.tar.gz --dest /path/to/dir
```

## ctl render

Render a template file with variable substitution.

```bash
cyctl ctl render --file template.tmpl --env KEY1=val1 --values values.yaml
```

## ctl static-pod apiserver-lb

Generate a static Pod manifest for the API server load balancer.

```bash
cyctl ctl static-pod apiserver-lb \
  --vip 10.103.97.2 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  --image cycore.hub:4000/library/busybox:latest
```

## ctl cri-shim

Run a CRI image service proxy as a daemon. Intercepts containerd image pull requests and automatically rewrites them to point to a local registry.

```bash
cyctl ctl cri-shim \
  --config /etc/cycore/cri-shim.yaml \
  --socket /var/run/cycore-cri-shim.sock
```

Configuration file example:

```yaml
# /etc/cycore/cri-shim.yaml
address: /var/run/cycore-cri-shim.sock
force: true
image: 192.168.1.100:5000
```
