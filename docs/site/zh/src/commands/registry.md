# registry — 镜像仓库管理

## `registry serve` — 运行本地 Registry

```
cyctl registry serve [OPTIONS]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--listen` | 监听地址 | `0.0.0.0:4000` |
| `--data-dir` | 数据目录（文件系统存储） | — |
| `--inmem` | 使用内存存储 | `false` |

示例：
```bash
# 基本启动
cyctl registry serve --data-dir /var/lib/registry

# 自定义端口
cyctl registry serve --listen 0.0.0.0:5443 --data-dir /data/registry

# 内存模式（测试用）
cyctl registry serve --inmem
```

## `registry save`

将镜像保存到本地 registry 目录。

```bash
cyctl registry save nginx:latest redis:7 --output /data/offline-registry
```

## `registry sync`

在两个 registry 之间同步所有镜像。

```bash
cyctl registry sync \
  --source docker.io/library \
  --destination 10.0.0.1:4000/library
```

## `registry copy`

复制单个镜像。

```bash
cyctl registry copy \
  docker.io/library/nginx:latest \
  myregistry.com:4000/nginx:latest
```

## `registry passwd`

设置 registry htpasswd 认证。

```bash
cyctl registry passwd --username admin --password 'SecurePass123'
```
