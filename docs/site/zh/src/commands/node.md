# node — 节点管理

## `node add` — 添加节点

```
cyctl node add [OPTIONS]
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `--masters` | `-m` | 要添加的 master 节点 IP | — |
| `--nodes` | `-n` | 要添加的 worker 节点 IP | — |
| `--passwd` | `-p` | SSH 密码 | — |
| `--pk` | `-k` | SSH 私钥路径 | — |
| `--cluster-name` | `-c` | 集群名称 | `default` |

示例：
```bash
# 添加 worker
cyctl node add -n 10.0.0.13,10.0.0.14 -p xxx

# 添加 master（扩展 HA）
cyctl node add -m 10.0.0.4 -p xxx

# 指定集群
cyctl node add -n 10.0.0.15 -p xxx -c production
```

## `node delete` — 删除节点

```
cyctl node delete [OPTIONS]
```

参数与 `node add` 相同（`-c` 集群名称，`-m` master IP，`-n` node IP）。

示例：
```bash
# 删除 worker
cyctl node delete -n 10.0.0.14 -p xxx

# 删除 master
cyctl node delete -m 10.0.0.4 -p xxx
```
