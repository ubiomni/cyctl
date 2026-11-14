# Introduction

cyctl is a Kubernetes cluster lifecycle management CLI tool written in Rust. It deploys OCI-based cluster images to target nodes over SSH, supporting fully offline installation and built-in high availability (HA).

## Key Features

- **Single binary** -- No shell script dependencies. One self-contained executable handles the entire cluster lifecycle.
- **One-command deployment** -- Deploy a multi-master HA cluster with a single command.
- **Declarative management** -- Describe your desired cluster state in a Clusterfile and apply it.
- **Elastic scaling** -- Add or remove worker nodes with one command.
- **Full offline support** -- Build rootfs images from upstream components and deploy clusters without internet access.
- **AI Agent friendly** -- All output supports JSON format, structured error codes, and `--quiet` mode for machine consumption.
- **Component management** -- Install, configure, and manage middleware and data platform components with built-in dependency ordering.
- **Embedded OCI registry** -- Ship and serve container images without external registry infrastructure.
- **IPVS by default** -- kube-proxy runs in IPVS mode for better performance and VPN compatibility.
- **Kubelet optimized** -- Pre-configured for AI training workloads with tuned GC, resource reservations, and parallel image pulls.

## Architecture Overview

cyctl operates through SSH connections to target nodes. The deployment workflow:

1. **Image preparation** -- Build or pull an OCI rootfs image containing Kubernetes binaries, container runtime, and pre-fetched system images.
2. **Distribution** -- Transfer the rootfs image to all target nodes via SSH.
3. **Node initialization** -- Install containerd, kubelet, and required kernel modules on each node.
4. **Cluster bootstrap** -- Initialize the first master with kubeadm, then join additional masters and workers.
5. **HA configuration** -- Set up IPVS load balancing across API servers for high availability.
6. **Registry setup** -- Start a local OCI registry on each node and load pre-fetched images for offline operation.

All cluster state is persisted locally, allowing subsequent operations (scaling, inspection, reset) to reference saved connection details without re-specifying credentials.

## Output Formats

cyctl defaults to JSON output (`-o json`) for programmatic consumption. Use `-o table` for human-readable output:

```bash
# JSON (default, suitable for scripts and AI agents)
cyctl cluster status default

# Human-readable table
cyctl cluster status default -o table
```

Errors are written to stderr as structured JSON with categorized exit codes (0-7), making it straightforward to handle failures in automation pipelines.
