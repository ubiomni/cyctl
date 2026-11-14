# ctl — 系统控制工具

`ctl` 包含节点级系统操作，通常由 `cluster run` / `node add` 等高级命令自动调用。也可手动使用进行调试或自定义部署。

## `ctl hosts` — /etc/hosts 管理

```bash
# 列出所有条目
cyctl ctl hosts list

# 添加
cyctl ctl hosts add --ip 10.0.0.1 --domain apiserver.cluster.local

# 删除
cyctl ctl hosts delete --domain apiserver.cluster.local
```

## `ctl hostname` — 获取主机名

```bash
cyctl ctl hostname
# 输出: {"hostname": "node01"}
```

## `ctl cri` — CRI 运行时探测

```bash
# 探测 CRI socket
cyctl ctl cri socket
# 输出: {"socket": "/run/containerd/containerd.sock"}

# 获取 cgroup driver
cyctl ctl cri cgroup-driver
# 输出: {"cgroup_driver": "systemd"}
```

## `ctl cert` — 低级证书生成

```bash
cyctl ctl cert \
  --cert-path /etc/kubernetes/pki \
  --alt-names 10.0.0.1,api.example.com \
  --node-name master01 \
  --service-cidr 10.96.0.0/16 \
  --dns-domain cluster.local
```

## `ctl ipvs` — IPVS 负载均衡

```bash
# 创建 IPVS 规则
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --rs 10.0.0.2:6443

# 以守护进程运行（含健康检查）
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --rs 10.0.0.2:6443 --run

# 清理
cyctl ctl ipvs --vs 10.103.97.2:6443 --rs 10.0.0.1:6443 --clean
```

## `ctl initsystem` — systemd 服务管理

```bash
cyctl ctl initsystem enable --name kubelet
cyctl ctl initsystem start --name containerd
cyctl ctl initsystem stop --name kubelet
cyctl ctl initsystem restart --name containerd
cyctl ctl initsystem is-active --name kubelet
# 输出: {"active": true}
cyctl ctl initsystem is-enabled --name kubelet
# 输出: {"enabled": true}
cyctl ctl initsystem is-exists --name kubelet
# 输出: {"exists": true}
```

## `ctl init-kube` — 初始化 K8s 组件

替代原有 init-kube.sh，在节点上安装 kubelet/kubeadm/kubectl、配置 sysctl、加载内核模块等。

```bash
cyctl ctl init-kube --bin-dir /usr/local/bin --rootfs /var/lib/cycore/rootfs
```

## `ctl init-cri` — 初始化容器运行时

替代原有 init-containerd.sh。支持 containerd v1.x 和 v2.x，自动检测版本生成对应配置。

```bash
# 标准用法（自动检测 containerd 版本）
cyctl ctl init-cri \
  --registry-domain cycore.hub \
  --registry-port 4000 \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs

# K8s 1.33+ 使用 containerd 2.x
cyctl ctl init-cri \
  --registry-domain cycore.hub \
  --registry-port 4000 \
  --containerd-version 2 \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs

# 配置 HTTP 私有仓库（非 HTTPS）
cyctl ctl init-cri \
  --registry-domain 192.168.1.100 \
  --registry-port 30077 \
  --registry-scheme http \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--registry-domain` | `cycore.hub` | 镜像仓库域名/IP |
| `--registry-port` | `4000` | 镜像仓库端口 |
| `--registry-scheme` | `https` | 协议: `http` 或 `https` |
| `--containerd-version` | 自动检测 | containerd 大版本 (1 或 2) |
| `--bin-dir` | `/usr/bin` | 二进制安装目录 |
| `--rootfs` | — | rootfs 路径 |

## `ctl registry-load` — 加载预取镜像到 Registry

将 rootfs 中预取的容器镜像 archive 加载到运行中的 registry。集群部署后，registry 中会自动包含 K8s 系统镜像。

```
cyctl ctl registry-load [OPTIONS]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--archive` | 镜像 archive 路径（OCI tar.gz） | 必填 |
| `--registry` | 目标 registry 地址 | `cycore.hub:4000` |
| `--insecure` | 允许 HTTP registry | `false` |

示例：
```bash
# 加载到本地 registry
cyctl ctl registry-load --archive /opt/cycore/registry/images.tar.gz

# 加载到远端 HTTP registry
cyctl ctl registry-load \
  --archive /opt/cycore/registry/images.tar.gz \
  --registry 192.168.1.100:5000 \
  --insecure
```

## `ctl init-registry` — 初始化 Registry

```bash
cyctl ctl init-registry \
  --data /var/lib/registry \
  --config /etc/registry \
  --bin-dir /usr/local/bin \
  --rootfs /var/lib/cycore/rootfs
```

## `ctl check` — 预检查

```bash
cyctl ctl check
# 检查: root 权限、端口占用、Docker 冲突、现有 K8s
```

## `ctl clean` — 节点清理

```bash
cyctl ctl clean \
  --cri-data /var/lib/containerd \
  --registry-data /var/lib/registry \
  --registry-config /etc/registry \
  --bin-dir /usr/local/bin
```

## `ctl token` — 生成 join token

```bash
cyctl ctl token
# 输出: {"join_command": "kubeadm join 10.0.0.1:6443 --token abc123 --discovery-token-ca-cert-hash sha256:..."}
```

## `ctl tar` / `untar`

```bash
cyctl ctl tar --source /path/to/dir --dest /path/to/archive.tar.gz
cyctl ctl untar --source /path/to/archive.tar.gz --dest /path/to/dir
```

## `ctl render` — 模板渲染

```bash
cyctl ctl render --file template.tmpl --env KEY1=val1 --values values.yaml
```

## `ctl static-pod apiserver-lb` — 生成 apiserver-lb 静态 Pod 清单

```bash
cyctl ctl static-pod apiserver-lb \
  --vip 10.103.97.2 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  --image cycore.hub:4000/library/busybox:latest
```

## `ctl cri-shim` — CRI 镜像服务代理

作为守护进程运行，拦截 containerd 的镜像拉取请求，自动重写为本地 registry 地址。

```bash
cyctl ctl cri-shim \
  --config /etc/cycore/cri-shim.yaml \
  --socket /var/run/cycore-cri-shim.sock
```
