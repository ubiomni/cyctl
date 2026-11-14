# remote — 远程操作

## `remote exec` — 远程执行命令

```
cyctl remote exec [OPTIONS] -- <COMMAND>...
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `--masters` | `-m` | Master 节点 IP（逗号分隔） | — |
| `--nodes` | `-n` | Worker 节点 IP（逗号分隔） | — |
| `--passwd` | `-p` | SSH 密码 | — |
| `--pk` | `-k` | SSH 私钥路径 | — |
| `--user` | `-u` | SSH 用户 | `root` |
| `--port` | — | SSH 端口 | `22` |
| `--role` | `-r` | 目标角色过滤：master / node / all | `all` |
| `--cluster-name` | `-c` | 从已保存的集群状态加载主机列表 | — |

示例：
```bash
# 在所有 master 上执行
cyctl remote exec -m 10.0.0.1,10.0.0.2,10.0.0.3 -p xxx \
  -- 'kubectl get nodes -o wide'

# 在所有节点上执行
cyctl remote exec -m 10.0.0.1 -n 10.0.0.11,10.0.0.12 -p xxx \
  -- 'systemctl status kubelet'

# 使用集群名称（自动加载节点列表）
cyctl remote exec -c default -p xxx -r master -- 'kubeadm token list'
```

输出（JSON）：
```json
[
  {"host": "10.0.0.1", "status": "ok", "output": "NAME   STATUS   ROLES    AGE   VERSION\n..."},
  {"host": "10.0.0.2", "status": "ok", "output": "NAME   STATUS   ROLES    AGE   VERSION\n..."}
]
```

## `remote scp` — 远程文件传输

```
cyctl remote scp [OPTIONS] <LOCAL> <REMOTE>
```

| 参数 | 短参数 | 说明 |
|------|--------|------|
| `<LOCAL>` | — | 本地路径 |
| `<REMOTE>` | — | 远程路径 |
| `--masters` | `-m` | Master 节点 IP（逗号分隔） |
| `--nodes` | `-n` | Worker 节点 IP（逗号分隔） |
| `--passwd` | `-p` | SSH 密码 |
| `--pk` | `-k` | SSH 私钥路径 |
| `--user` | `-u` | SSH 用户（默认 root） |
| `--port` | — | SSH 端口（默认 22） |
| `--role` | `-r` | 目标角色过滤：master / node / all（默认 all） |
| `--cluster-name` | `-c` | 从已保存的集群状态加载主机列表 |
| `--download` | `-d` | 下载模式（默认是上传） |

示例：
```bash
# 上传到所有节点
cyctl remote scp -m 10.0.0.1 -n 10.0.0.11 -p xxx \
  ./config.yaml /etc/kubernetes/config.yaml

# 使用集群名称上传 cyctl 到所有节点
cyctl remote scp -c prod-gpu ./cyctl /usr/local/bin/cyctl

# 从所有 master 下载
cyctl remote scp -m 10.0.0.1,10.0.0.2 -p xxx \
  -d /tmp/downloaded/ /etc/kubernetes/admin.conf
```
