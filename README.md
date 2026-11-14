# cyctl

[![Release](https://img.shields.io/github/v/release/ubiomni/cyctl)](https://github.com/ubiomni/cyctl/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Standalone Kubernetes cluster lifecycle management CLI. Single binary, no dependencies, fully offline capable.

[Documentation](https://ubiomni.github.io/cyctl) | [中文文档](https://ubiomni.github.io/cyctl/zh/)

## Features

- **One-command deploy** — Deploy a multi-master HA Kubernetes cluster with a single command over SSH
- **Fully offline** — Build OCI rootfs images from upstream components, deploy without internet access
- **Component management** — Pack, distribute, and install middleware (MySQL, Redis, monitoring, data platform) as offline bundles
- **Declarative management** — Describe desired cluster state in a Clusterfile, `apply` to converge
- **AI-friendly** — Structured JSON output, distinct exit codes, quiet mode for agent integration
- **Single binary** — Written in Rust, statically linked, no runtime dependencies

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ubiomni/cyctl/main/install.sh | sh
```

Or download from [Releases](https://github.com/ubiomni/cyctl/releases):

| Platform | Architecture | Download |
|----------|-------------|----------|
| Linux | x86_64 | [cyctl-linux-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-amd64.tar.gz) |
| Linux | ARM64 | [cyctl-linux-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-arm64.tar.gz) |
| macOS | Intel | [cyctl-darwin-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-amd64.tar.gz) |
| macOS | Apple Silicon | [cyctl-darwin-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-arm64.tar.gz) |

## Quick Start

### Deploy a Kubernetes cluster

```bash
# Single master + 2 workers
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.3 -p <ssh-password>

# HA: 3 masters with SSH key
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 -n 10.0.0.11 -k ~/.ssh/id_rsa
```

### Install components offline

```bash
# Pack components on a machine with internet access
cyctl component pack mysql,redis,nginx --arch amd64

# Transfer the package to the target server, then install
cyctl component install mysql,redis,nginx \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

### Check cluster status

```bash
cyctl cluster status
cyctl component status
```

## Shell Completions

```bash
# Bash
cyctl completion bash > /etc/bash_completion.d/cyctl

# Zsh
cyctl completion zsh > "${fpath[1]}/_cyctl"

# Fish
cyctl completion fish > ~/.config/fish/completions/cyctl.fish
```

## Documentation

Full documentation is available at [ubiomni.github.io/cyctl](https://ubiomni.github.io/cyctl).

- [English Documentation](https://ubiomni.github.io/cyctl/en/)
- [中文文档](https://ubiomni.github.io/cyctl/zh/)

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.
