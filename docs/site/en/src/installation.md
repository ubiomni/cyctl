# Installation

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/ubiomni/cyctl/main/install.sh | sh
```

The script detects your OS and architecture automatically and downloads the appropriate binary from GitHub Releases.

## Manual Download

Pre-built binaries are available on the [GitHub Releases](https://github.com/ubiomni/cyctl/releases) page:

| Platform | Architecture | Download |
|----------|-------------|----------|
| Linux | x86_64 | [cyctl-linux-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-amd64.tar.gz) |
| Linux | ARM64 | [cyctl-linux-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-arm64.tar.gz) |
| macOS | Intel | [cyctl-darwin-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-amd64.tar.gz) |
| macOS | Apple Silicon | [cyctl-darwin-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-arm64.tar.gz) |

```bash
tar xzf cyctl-linux-amd64.tar.gz
sudo mv cyctl /usr/local/bin/
cyctl version
```

## Install a Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/ubiomni/cyctl/main/install.sh | sh -s v0.1.0
```

## Shell Completions

### Bash

```bash
# Linux
cyctl completion bash | sudo tee /etc/bash_completion.d/cyctl > /dev/null

# macOS (with Homebrew)
cyctl completion bash > "$(brew --prefix)/etc/bash_completion.d/cyctl"
```

### Zsh

```bash
cyctl completion zsh > "${fpath[1]}/_cyctl"
compinit
```

### Fish

```bash
cyctl completion fish > ~/.config/fish/completions/cyctl.fish
```

### PowerShell

```powershell
cyctl completion powershell > cyctl.ps1
```

## Man Pages

```bash
cyctl docs --path /usr/local/share/man/man1/
man cyctl
man cyctl-cluster-run
```
