# cluster — 集群生命周期

## `cluster run` — 部署集群

从 OCI 集群镜像部署 K8s 集群。

```
cyctl cluster run [OPTIONS] -m <MASTERS> [IMAGES]...
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `[IMAGES]...` | — | OCI 镜像引用（第一个必须是 rootfs，其余为应用） | — |
| `--masters` | `-m` | Master 节点 IP（逗号分隔） | 必填 |
| `--nodes` | `-n` | Worker 节点 IP（逗号分隔） | `""` |
| `--passwd` | `-p` | SSH 密码 | — |
| `--pk` | `-k` | SSH 私钥路径 | — |
| `--port` | — | SSH 端口 | `22` |
| `--user` | `-u` | SSH 用户 | `root` |
| `--env` | `-e` | 环境变量 KEY=VALUE，可重复 | — |
| `--transport` | — | 镜像传输格式：oci-archive / docker-archive | `oci-archive` |
| `--cluster-name` | `-c` | 集群名称 | `default` |
| `--registry` | — | 私有 registry URL：`[scheme://][user:pass@]host[:port]` | — |
| `--vip` | — | IPVS apiserver 负载均衡虚拟 IP (HA) | `10.103.97.2` |
| `--kubelet-config` | — | KubeletConfiguration 覆盖 YAML 文件路径 | — |

> `--registry` 合并了原来的 `--registry-domain`、`--registry-port`、`--registry-scheme`、`--registry-username`、`--registry-password` 五个参数（旧参数仍可用）。

示例：
```bash
# 基本部署（单 master + 单 worker）
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 -p xxx

# 3 master HA 集群
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p xxx

# 使用 SSH key 认证
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 \
  -k ~/.ssh/id_rsa

# 自定义集群名称 + 传入环境变量
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p xxx \
  -c production \
  -e POD_CIDR=10.244.0.0/16 \
  -e SVC_CIDR=10.96.0.0/16

# 使用本地构建的 rootfs
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -p xxx \
  --transport oci-archive

# 使用本地 rootfs + 配置 HTTP 私有 registry
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 -p xxx \
  --registry http://192.168.1.100:5000

# 使用需要认证的 HTTP 私有 registry
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --registry http://myuser:mypassword@192.168.1.100:5000

# 从远程 registry 拉取并部署
cyctl cluster run 192.168.1.100:5000/cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --registry http://myuser:mypassword@192.168.1.100:5000

# 自定义 IPVS VIP（HA 场景）
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11 -p xxx \
  --vip 10.103.97.100
```

## `cluster apply` — 声明式管理

基于 Clusterfile 声明式管理集群。

```
cyctl cluster apply [OPTIONS]
```

| 参数 | 说明 | 默认值 |
| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `--file` | `-f` | Clusterfile 路径 | — |
| `--values` | — | 额外变量文件 | — |
| `--set` | — | 覆盖变量 KEY=VALUE，可重复 | — |
| `--cluster-name` | `-c` | 集群名称 | `default` |

示例：
```bash
# 应用 Clusterfile
cyctl cluster apply -f Clusterfile.yaml

# 覆盖变量
cyctl cluster apply -f Clusterfile.yaml --set masters=3 --set nodes=5
```

## `cluster status` — 集群状态

```
cyctl cluster status [OPTIONS] [NAME]
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `[NAME]` | — | 集群名称 | `default` |
| `--cluster-name` | `-c` | 集群名称 | `default` |

示例：
```bash
# 默认集群
cyctl cluster status

# 指定集群
cyctl cluster status production

# Table 格式
cyctl cluster status default -o table
```

## `cluster inspect` — 集群巡检

SSH 到所有节点采集系统信息、K8s 组件版本、容器运行时状态、网络配置、磁盘占用，以及集群级资源（节点、Pod、PV、Service、CRD）。适合在 reset 之前确认集群状态，或日常巡检。

```
cyctl cluster inspect [OPTIONS]
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `--cluster-name` | `-c` | 集群名称（从已保存的 spec 读取连接信息） | `default` |
| `--hosts` | — | 主机 IP 列表（逗号分隔，绕过 cluster spec） | — |
| `--passwd` | `-p` | SSH 密码 | — |
| `--pk` | `-k` | SSH 私钥路径 | `~/.ssh/id_rsa`（自动探测） |
| `--port` | — | SSH 端口 | `22` |
| `--user` | `-u` | SSH 用户 | `root` |

两种使用模式：
- **cluster spec 模式**：已用 `cluster run` 部署过的集群，直接读取保存的连接信息
- **直连模式**：通过 `--hosts` 指定 IP，需要提供 `--passwd` 或 `--pk`

采集项：

| 类别 | 节点级 | 集群级（master0） |
|------|--------|-------------------|
| 系统 | hostname、OS、kernel、uptime | — |
| K8s | kubeadm/kubelet/kubectl 版本 | nodes、namespaces、running pods |
| 运行时 | containerd 版本及状态、runc、crictl | — |
| 网络 | CNI 接口（cali/tunl/vxlan）、iptables 规则数 | services |
| 存储 | containerd/etcd/kubelet/cycore 磁盘占用 | PV 列表 |
| 资源 | — | CRD 数量、kubectl top nodes |

示例：
```bash
# 直连模式（密码认证）
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3 -p 'yourpass'

# 直连模式（密钥认证，~/.ssh/id_rsa 自动探测）
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3

# 使用已保存的 cluster spec
cyctl cluster inspect -c mycluster
```

输出同时包含人类可读报告和 JSON 结构化数据，适合 AI Agent 解析。

## `cluster reset` — 销毁集群

```
cyctl cluster reset [OPTIONS] [NAME]
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `[NAME]` | — | 集群名称 | `default` |
| `--cluster-name` | `-c` | 集群名称 | `default` |
| `--force` | — | 跳过确认提示 | `false` |
| `--purge` | — | 彻底清理所有 K8s 组件（二进制、运行时、systemd 单元等） | `false` |

**两种模式：**

**标准 reset**（`--force`）：执行 `kubeadm reset`，清理 K8s 配置目录、iptables/IPVS 规则，停止 kubelet/containerd 服务。适合重新部署同版本集群。

**彻底清理**（`--force --purge`）：在标准 reset 基础上，额外执行：
- 删除 CNI 网络接口（cali*、tunl0、vxlan.calico、flannel.1、cni0）
- 清理 ip6tables 规则
- 删除 containerd 数据和配置（`/var/lib/containerd`、`/etc/containerd`）
- 删除 CNI 数据（`/var/lib/cni`、`/var/lib/calico`）
- 删除 cycore 部署目录（`/opt/cycore`）
- 删除 K8s 二进制（kubeadm、kubelet、kubectl）
- 删除 containerd 二进制（containerd、runc、crictl、ctr）
- 删除 systemd unit 文件并执行 `daemon-reload`
- 清理 sysctl 配置（`/etc/sysctl.d/k8s.conf`）
- 清理 libseccomp 和 ldconfig 配置

适合彻底卸载、更换版本或退役节点。

示例：
```bash
# 交互确认
cyctl cluster reset -c default

# 标准 reset（脚本/CI 用）
cyctl cluster reset -c default --force

# 彻底清理 — 节点恢复到未安装 K8s 的状态
cyctl cluster reset -c default --force --purge
```

推荐操作顺序：
```bash
# 1. 先巡检确认集群状态
cyctl cluster inspect -c default

# 2. 清理无用 pod（如 Evicted pod）
kubectl get pods -A --field-selector=status.phase=Failed -o json | kubectl delete -f -

# 3. 确认可以销毁后执行 reset
cyctl cluster reset -c default --force --purge
```

## `cluster cert` — 证书管理

更新/续签 K8s API Server 证书。

```
cyctl cluster cert [OPTIONS] [NAME]
```

| 参数 | 短参数 | 说明 | 默认值 |
|------|--------|------|--------|
| `[NAME]` | — | 集群名称 | `default` |
| `--cluster-name` | `-c` | 集群名称 | `default` |
| `--alt-names` | — | 额外 SAN（逗号分隔的 IP/DNS） | — |
| `--renew` | — | 续签模式 | `false` |

示例：
```bash
# 添加额外 SAN
cyctl cluster cert default --alt-names api.example.com,10.0.0.100

# 续签证书
cyctl cluster cert default --renew
```

## `cluster gen` — 生成 Clusterfile

```
cyctl cluster gen -m <MASTERS> -n <NODES> [OPTIONS]
```

示例：
```bash
# 生成到标准输出
cyctl cluster gen -m 10.0.0.1,10.0.0.2,10.0.0.3 -n 10.0.0.11,10.0.0.12

# 写入文件
cyctl cluster gen \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  --image cycore/kubernetes:v1.35.3 \
  -p xxx \
  -f Clusterfile.yaml
```
