# 安装

## 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/ubiomni/cyctl/main/install.sh | sh
```

脚本会自动检测系统和架构，从 GitHub Releases 下载对应的二进制文件。

## 手动下载

从 [GitHub Releases](https://github.com/ubiomni/cyctl/releases) 下载：

| 平台 | 架构 | 下载 |
|------|------|------|
| Linux | x86_64 | [cyctl-linux-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-amd64.tar.gz) |
| Linux | ARM64 | [cyctl-linux-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-linux-arm64.tar.gz) |
| macOS | Intel | [cyctl-darwin-amd64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-amd64.tar.gz) |
| macOS | Apple Silicon | [cyctl-darwin-arm64.tar.gz](https://github.com/ubiomni/cyctl/releases/latest/download/cyctl-darwin-arm64.tar.gz) |

```bash
tar xzf cyctl-linux-amd64.tar.gz
sudo mv cyctl /usr/local/bin/
cyctl version
```

## 指定版本安装

```bash
# 安装特定版本
curl -fsSL https://raw.githubusercontent.com/ubiomni/cyctl/main/install.sh | sh -s v0.1.0
```

## Shell 补全

```bash
# Bash
cyctl completion bash > /etc/bash_completion.d/cyctl

# Zsh
cyctl completion zsh > "${fpath[1]}/_cyctl"

# Fish
cyctl completion fish > ~/.config/fish/completions/cyctl.fish

# PowerShell
cyctl completion powershell > cyctl.ps1
```

## 生成 Man Pages

```bash
cyctl docs --path /usr/local/share/man/man1/
```
