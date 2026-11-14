# 其他命令

## lvscare — IPVS 健康检查

```
cyctl lvscare care [OPTIONS]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--vs` | Virtual Service IP:Port | 必填 |
| `--rs` | Real Server IP:Port（可重复） | 必填 |
| `--health-path` | 健康检查路径 | `/healthz` |
| `--health-schem` | 协议 http/https | `https` |
| `--interval` | 检查间隔（秒） | `5` |

示例：
```bash
cyctl lvscare care \
  --vs 10.103.97.2:6443 \
  --rs 10.0.0.1:6443 \
  --rs 10.0.0.2:6443 \
  --rs 10.0.0.3:6443 \
  --interval 5
```

## completion — Shell 补全

```bash
cyctl completion bash       # Bash
cyctl completion zsh        # Zsh
cyctl completion fish       # Fish
cyctl completion powershell # PowerShell
```

### 安装补全

```bash
# Bash (Linux)
cyctl completion bash | sudo tee /etc/bash_completion.d/cyctl

# Bash (macOS)
cyctl completion bash > $(brew --prefix)/etc/bash_completion.d/cyctl

# Zsh
cyctl completion zsh > "${fpath[1]}/_cycore"
compinit

# Fish
cyctl completion fish > ~/.config/fish/completions/cycore.fish
```

## docs — 文档生成

生成 man page 文档。

```bash
# 默认输出到 ./docs/man/
cyctl docs

# 自定义目录
cyctl docs --path /usr/local/share/man/man1/

# 查看 man page
man cyctl
man cyctl-cluster-run
```

## version / env

```bash
# 版本信息（JSON）
cyctl version
# {"version": "0.1.0", "commit": "abc1234", "built": "2026-09-01T12:00:00Z"}

# 环境变量信息（JSON）
cyctl env
# {"CYCORE_API_URL": "(not set)", "CYCORE_DATA_DIR": "...", ...}
```
