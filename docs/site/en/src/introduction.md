# Introduction

**cyctl — From bare metal to AI-ready, in minutes** *One binary · Full stack · Fully offline*

## Key Features

- **Full offline support** — Build rootfs images and pack component bundles for air-gapped deployment
- **Dependency orchestration** — Automatic component dependency ordering, no need to remember what goes first
- **AI workload optimized** — Kubelet pre-configured: image GC protection, parallel pulls, resource reservations, early OOM eviction
- **Elastic scaling** — Add or remove nodes with one command
- **AI Agent friendly** — JSON output, structured error codes, `--quiet` mode for direct LLM Agent invocation

## How It Works

1. **Build image** — Package K8s binaries, containerd, and system images into an OCI rootfs
2. **Deploy cluster** — Distribute via SSH, initialize nodes, bootstrap with kubeadm, configure IPVS HA
3. **Install components** — Extract offline bundles, install in dependency order

All cluster state is persisted locally — subsequent operations need no repeated credentials.
