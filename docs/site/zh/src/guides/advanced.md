# 高级用法

## Mirror 加速

`--mirror` 用于加速二进制组件下载（kubeadm、kubelet、containerd 等），替换下载 URL 中的 scheme+host 部分。`--registry-mirror` 用于替换容器镜像的 registry 前缀，支持两种模式：

**通用模式**（自建 Harbor 等，保留完整 repo 路径）：
```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror my-harbor.local
# registry.k8s.io/kube-apiserver:v1.35.3 → my-harbor.local/kube-apiserver:v1.35.3
# docker.io/library/busybox:latest       → my-harbor.local/library/busybox:latest
# quay.io/calico/node:v3.30.0           → my-harbor.local/calico/node:v3.30.0
```

**按源 registry 映射**（公共 mirror，扁平路径，只取镜像名）：
```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
  --registry-mirror docker.io=hub-mirror.example.com \
  --registry-mirror quay.io=quay.mirrors.example.com
# registry.k8s.io/coredns/coredns:v1.12.0 → registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.12.0
```

**混合模式**（按源 registry 优先，其余走通用）：
```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror my-harbor.local \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers
# registry.k8s.io/* → 走阿里云 mirror（扁平路径）
# docker.io/*       → 走 my-harbor.local（完整路径）
# quay.io/*         → 走 my-harbor.local（完整路径）
```

二进制下载 mirror：
```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --mirror https://my-mirror.company.com
```

## Addon 机制

`--addon` 参数将 K8s 附加组件（CNI、operator 等）的 manifest 和容器镜像打包进 rootfs。集群初始化后自动 `kubectl apply`。

**内置 addon**：

| 名称 | 说明 | 优先级 |
|------|------|--------|
| `calico` | Calico CNI（通过 tigera-operator 部署） | 10 |

```bash
# 构建包含 calico 的 rootfs
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico

# 部署时 calico 自动安装，集群直接进入 Ready 状态
cyctl cluster run http://registry/cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2 -p xxx
```

**自定义 addon**：

创建目录结构：
```
my-addon/
  addon.yaml          # name, priority, images 列表
  manifests/          # YAML 文件（按文件名排序 apply）
    01-namespace.yaml
    02-deployment.yaml
```

`addon.yaml` 示例：
```yaml
name: my-operator
priority: 100
images:
  - docker.io/myorg/operator:v1.0
```

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --addon calico --addon-dir ./my-addon/
```

Addon apply 顺序由 priority 决定（数值小的先执行），CNI 应设为最低优先级以确保网络先就绪。

## 组件依赖关系与安装顺序

部分组件依赖其他组件提供的服务，安装时需要遵循以下顺序：

#### 无依赖（基础层，可独立安装）

| 类别 | 组件 |
|------|------|
| 调度/算子 | volcano, training-operator, kuberay, gpu-operator |
| 中间件 | nats, mysql, redis, rustfs, postgresql, nginx |
| 数据平台（无依赖） | spark-operator, strimzi-kafka, clickhouse-operator |

#### 有依赖（必须先安装依赖项）

| 组件 | 依赖 | 说明 |
|------|------|------|
| prometheus | local-path-provisioner | TSDB 使用 PVC（local-path StorageClass） |
| prometheus-adapter | prometheus | 连接 prometheus 服务获取指标 |
| alloy | loki | 推送日志到 loki 服务 |
| loki (distributed) | rustfs | S3 对象存储后端（standalone 模式无此依赖） |
| nessie | postgresql | JDBC 连接 PostgreSQL，需要数据库/schema/用户（db_init 自动创建）|
| alluxio | rustfs | S3 endpoint 连接 RustFS 对象存储 |
| querybook | mysql, redis | 数据库 + 缓存/任务队列 |

#### 推荐安装顺序（standalone 模式）

分三批安装，每批内部无顺序要求：

**第一批 — 基础设施（无依赖）：**
```
local-path-provisioner, volcano, training-operator, kuberay, gpu-operator, nats, mysql, redis, rustfs, postgresql, nginx
```

**第二批 — 监控栈（内部有顺序）：**
```
metrics-server → prometheus → prometheus-adapter → loki → alloy
```

**第三批 — 数据平台（依赖第一批中间件）：**
```
nessie(需 postgresql), alluxio(需 rustfs), spark-operator, strimzi-kafka, trino, clickhouse-operator, querybook(需 mysql + redis)
```

> **注意：** `nessie` 安装时会自动在 PostgreSQL 中创建所需的数据库、schema、用户和 K8s Secret（通过 `db_init` 机制）。如需自定义密码，使用 `--set nessie_db_password=xxx`。

#### 推荐安装顺序（distributed 分布式模式）

使用 `--profile distributed` 部署高可用/分布式架构时，需注意额外的依赖关系（Loki distributed 依赖 RustFS）。

存储路径说明：
- `/data/cycore` — 各物理机本地磁盘，用于分布式中间件（RustFS、NATS）等自带副本机制、各节点数据独立的组件
- `/mnt/public/cycore` — 共享高性能存储（支持 `O_DIRECT`），用于数据库、无状态组件、监控、数据平台等

> 根据实际环境替换上述路径。共享存储必须支持 `O_DIRECT`（可用 `dd oflag=direct` 验证），否则 MySQL 不能使用。如果没有共享存储，所有组件均使用本地磁盘 + `--node-selector` 固定节点。

**第一步 — K8s 基础设施（无依赖，无状态）：**
```bash
# local-path-provisioner 的 storage-base 决定 PVC 数据存放位置
# 指向共享存储可让 PVC 数据在 pod 漂移后不丢失
cyctl component install local-path-provisioner \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore

cyctl component install volcano,training-operator,kuberay,gpu-operator,metrics-server \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore
```

**第二步 — 中间件（后续组件的基础）：**
```bash
# 数据库/缓存 — 共享高性能存储（支持 O_DIRECT），pod 漂移不丢数据，无需 --node-selector
# 如果共享存储不支持 O_DIRECT，需改用本地磁盘 + --node-selector 固定节点
cyctl component install mysql,redis,postgresql,nginx \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore

# 分布式中间件 — 各节点独立存储，自带副本机制，不能用共享存储
# 安装 RustFS 前务必清空原有数据目录
# shared=false: 每个 pod 绑定不同节点（需节点数 >= replicaCount）
# shared=true: 允许多 pod 共享节点（节点数不足时使用）
cyctl component install rustfs,nats \
  --package /tmp/cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed
```

> RustFS 必须在 Loki distributed 之前安装，Loki 的 S3 后端指向 `rustfs-svc.middleware.svc.cluster.local:9000`。

**第三步 — 监控 + 日志：**
```bash
# 安装 Loki distributed 前需先创建 RustFS bucket:
#   loki-chunks, loki-ruler, loki-admin

cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore \
  --profile distributed \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=300Gi
```

> Prometheus 存储说明：`retention=15d` 保留 15 天指标数据，`storage=300Gi` 为 PVC 声明大小。使用 `local-path-provisioner` 时 PVC 大小为声明值，不强制限制实际磁盘占用。磁盘空间估算：10 节点 + GPU exporter 约 30-50Gi/15天，300Gi 足够支撑大规模集群长期运行。

**第四步 — 数据平台（依赖 postgresql + rustfs）：**
```bash
cyctl component install nessie,trino,spark-operator,strimzi-kafka,clickhouse-operator \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore \
  --profile distributed

cyctl component install alluxio \
  --package /tmp/cycore-k8s-offline --storage-base /data/cycore

# Querybook — 依赖 MySQL + Redis（第二步），内置 OpenSearch
# Trino 非启动依赖，装完后在 Admin UI 中添加 Trino 引擎即可
cyctl component install querybook \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore
```

> `--profile distributed` 只对有 distributed profile 的组件生效（见下表），其余组件自动使用默认 standalone 配置。

## 分布式部署（--profile distributed）

支持分布式部署的组件及其部署架构：

| 组件 | standalone（默认） | distributed | 存储方式 | 说明 |
|------|-------------------|-------------|----------|------|
| loki | SingleBinary 1 副本，filesystem 存储 | Distributed 微服务模式（ingester×3, distributor×2, querier×2, compactor×1, gateway×1） | **共享存储（S3/RustFS）** | 依赖 RustFS；日志保留 30 天 |
| prometheus | 单副本，alertmanager 关闭 | 双副本（podAntiAffinity: hard）+ alertmanager×2 | 本机 hostPath（各副本独立） | 两副本强制调度到不同节点，各存各的 |
| nats | 单节点 JetStream | 3 节点集群 | 本机 hostPath（各副本独立） | topologySpreadConstraints 跨节点，Raft 协议同步 |
| trino | coordinator（chart 默认 2 workers） | coordinator + 3 workers | 无存储（计算引擎） | worker 配置 2Gi～4Gi 内存 |
| nessie | 2 副本（JDBC 后端） | 3 副本 | 无存储（数据在 PostgreSQL） | 无状态应用，依赖 PostgreSQL |
| rustfs | 单节点 | 分布式多节点 | 本机 hostPath | 已有 distributed profile |
| alluxio | standalone | HA 模式 | 本机 hostPath | 已有 ha profile |
| mysql | 单实例 | InnoDB Cluster | 本机 hostPath | cluster profile 需 Oracle 镜像认证 |

> **存储说明：** 除 Loki distributed 需要共享存储（S3/RustFS）外，其他所有组件的 distributed 模式均使用本机 hostPath（`--storage-base` 指定的目录），各节点各副本的数据独立，不需要共享磁盘或 NFS。Loki distributed 依赖 RustFS 提供 S3 兼容接口，必须先安装 RustFS。详见 [8.17 组件存储要求](#817-组件存储要求)。

**使用方式：**
```bash
# 单个组件指定 profile
cyctl component install loki --profile distributed \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/k8s

# 批量安装时 --profile 对所有组件生效（无该 profile 的组件自动回退到默认）
cyctl component install prometheus,loki,nats,trino,nessie \
  --profile distributed \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/k8s
```

**离线打包：**
```bash
# 默认只打包 standalone 镜像
cyctl component pack

# 打包所有 profiles 的镜像（含 distributed）
cyctl component pack --all-profiles

# 只打包指定 profile 的镜像
cyctl component pack --profile distributed
```

**Loki distributed 存储说明：**

Loki distributed 模式使用 RustFS 作为 S3 对象存储后端，自动创建以下 bucket：
- `loki-chunks` — 日志数据块
- `loki-ruler` — 告警规则
- `loki-admin` — 管理数据

默认连接配置（`loki-distributed.yaml`）：
```yaml
loki:
  storage:
    type: s3
    s3:
      endpoint: http://rustfs.middleware.svc.cluster.local:9000
      accessKeyId: <auto-generated>    # 安装时自动生成，见 ~/.cycore/component-secrets.env
      secretAccessKey: <auto-generated>  # 安装时自动生成，见 ~/.cycore/component-secrets.env
      s3ForcePathStyle: true
  limits_config:
    retention_period: 720h            # 30 天自动清理
  compactor:
    retention_enabled: true
```

> 如需调整日志保留时间，修改 `values/loki-distributed.yaml` 中的 `retention_period`，如 `168h`（7 天）、`336h`（14 天）。

## 节点绑定（--node-selector）

使用 hostPath 存储的有状态组件（MySQL、Redis、PostgreSQL 等），Pod 被调度到不同节点后数据会丢失。通过 `--node-selector` 将组件固定到指定节点，确保重启后不发生漂移。

**两种格式：**
```bash
# 简写：自动使用 kubernetes.io/hostname 作为 label key
cyctl component install mysql --node-selector worker-01 \
  --package /tmp/pkg --storage-base /data/k8s

# 完整 key=value 格式：支持任意 label
cyctl component install mysql --node-selector disktype=ssd \
  --package /tmp/pkg --storage-base /data/k8s
```

**典型场景：**
```bash
# 数据库组件固定到专用存储节点
cyctl component install mysql,redis,postgresql \
  --node-selector worker-01 \
  --package /tmp/pkg --storage-base /data/k8s

# 多个组件分别绑定到不同节点
cyctl component install mysql --node-selector db-node \
  --package /tmp/pkg --storage-base /data/k8s
cyctl component install redis --node-selector cache-node \
  --package /tmp/pkg --storage-base /data/k8s
```

**支持的组件：**

| 组件 | 安装方式 | 节点绑定方式 |
|------|---------|-------------|
| mysql | manifest | YAML nodeSelector 注入 |
| redis | manifest | YAML nodeSelector 注入 |
| postgresql | manifest | YAML nodeSelector 注入 |
| rustfs | helm | `--set nodeSelector.<key>=<val>` |
| loki | helm | `--set singleBinary.nodeSelector.<key>=<val>` |
| prometheus | helm | `--set prometheus.prometheusSpec.nodeSelector.<key>=<val>` + grafana |
| nats | helm | `--set podTemplate.merge.spec.nodeSelector.<key>=<val>` |
| nessie | helm | `--set nodeSelector.<key>=<val>` |
| trino | helm | `--set nodeSelector.<key>=<val>` |

> **注意：** 分布式模式（`--profile distributed`）的组件通常部署在多个节点上，不建议使用 `--node-selector` 绑定单一节点。如需绑定，按组件分别执行安装命令。

## 代理配置

```bash
# HTTP 代理
cyctl image build-rootfs --k8s-version v1.35.3 \
  --proxy http://proxy.company.com:8080

# SOCKS5 代理
cyctl image build-rootfs --k8s-version v1.35.3 \
  --proxy socks5://127.0.0.1:1080
```

## 离线部署

完全离线环境的部署流程：

```bash
# === 在有网环境 ===

# 1. 构建 rootfs 镜像（默认包含 K8s 系统容器镜像）
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64

# 国内环境使用 mirror 加速
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64 \
  --proxy socks5://127.0.0.1:1080 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers

# 2. 准备应用镜像
cyctl image pull docker.io/library/nginx:latest
cyctl image save nginx:latest --output nginx.tar

# 3. 拷贝到离线环境
scp kubernetes-v1.35.3-amd64.tar offline-bastion:/data/
scp nginx.tar offline-bastion:/data/
scp cyctl offline-bastion:/usr/local/bin/

# === 在离线环境 ===

# 4. 部署集群（rootfs 中已包含系统镜像，无需联网）
cyctl cluster run /data/kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 \
  -n 10.0.0.11 \
  -p xxx \
  --transport oci-archive

# 5. 加载应用镜像
cyctl image load --input /data/nginx.tar
```

> rootfs tar 中的 `registry/images.tar.gz` 包含预取的 K8s 系统镜像。部署时 cyctl 会自动启动节点本地 registry 并通过 `ctl registry-load` 加载这些镜像，节点无需联网拉取。

## 自定义 rootfs

通过 Kubefile 自定义集群镜像：

```dockerfile
# Kubefile
FROM cycore/kubernetes:v1.35.3

# 添加自定义 CNI
COPY calico.yaml manifests/

# 添加自定义配置
COPY custom-config.yaml etc/

# 添加自定义脚本
COPY post-install.sh scripts/
```

```bash
cyctl image build -t my-k8s:v1.35.3 -f Kubefile .
cyctl cluster run my-k8s:v1.35.3 -m 10.0.0.1 -p xxx
```

## 多集群管理

```bash
# 部署 dev 集群
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.1.0.1 -n 10.1.0.11 \
  -p xxx -c dev

# 部署 prod 集群
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.2.0.1,10.2.0.2,10.2.0.3 \
  -n 10.2.0.11,10.2.0.12,10.2.0.13 \
  -p xxx -c prod

# 分别查看状态
cyctl cluster status dev
cyctl cluster status prod

# 独立操作
cyctl node add -n 10.2.0.14 -p xxx -c prod
```

## 调试模式

```bash
# 开启 debug 日志
RUST_LOG=cycore=debug cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p xxx

# 开启 trace 日志（最详细）
RUST_LOG=cycore=trace cyctl cluster run ...

# 只看 SSH 模块日志
RUST_LOG=cycore::ssh=debug cyctl remote exec ...
```

## 证书续签

K8s 证书默认有效期 1 年，到期前需要续签：

```bash
# 续签证书
cyctl cluster cert default --renew

# 添加新的 SAN（如负载均衡器 VIP 变更）
cyctl cluster cert default --alt-names new-lb.example.com,10.0.0.100 --renew
```

## Kubelet 配置优化

`cyctl cluster run` 使用 kubeadm `--config` 方式部署集群，内置了针对**离线环境和 AI 训练场景**优化的 KubeletConfiguration 默认值：

| 参数 | cyctl 默认值 | K8s 默认值 | 优化原因 |
|------|-------------|-----------|----------|
| `imageMinimumGCAge` | 72h | 0s/2m | 离线环境镜像删了无法重新拉取，72h 保护短期停用的镜像 |
| `imageGCHighThresholdPercent` | 75 | 85 | 在 eviction 阈值(85%)前留 10% 缓冲，给 GC 时间清理 |
| `imageGCLowThresholdPercent` | 70 | 80 | 与 high 配合 |
| `cgroupDriver` | systemd | cgroupfs | 现代发行版标配 |
| `kubeReserved` | cpu:2, memory:2Gi, ephemeral-storage:1Gi | 无 | 为 kubelet/kube-proxy 预留资源，防 OOM |
| `systemReserved` | cpu:2, memory:2Gi, ephemeral-storage:1Gi | 无 | 为 systemd/sshd 等系统进程预留 |
| `evictionHard.memory.available` | 1Gi | 100Mi | 提前驱逐，避免节点真正 OOM |
| `evictionHard.imagefs.available` | 15% | 15% | 保持默认 |
| `containerLogMaxFiles` | 5 | 5 | 控制日志磁盘占用 |
| `containerLogMaxSize` | 50Mi | 10Mi | 放宽单文件大小，训练日志量较大 |
| `serializeImagePulls` | false | true | 允许并行拉镜像，加速部署 |
| `maxPods` | 110 | 110 | 保持默认 |
| `protectKernelDefaults` | true | false | 保护 sysctl 内核参数不被意外覆盖 |

**条件注入：**
- cgroupv1 + K8s >= 1.35：自动注入 `failCgroupV1: false`（1.35 起默认拒绝 cgroupv1）

**自定义覆盖：**

通过 `--kubelet-config` 传入 YAML 文件，覆盖上述任意默认值（deep merge，用户值优先）：

```bash
# kubelet-overrides.yaml
# imageMinimumGCAge: 168h
# kubeReserved:
#   cpu: "4"
#   memory: 4Gi

cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --kubelet-config kubelet-overrides.yaml
```

## 动态 IP 环境部署（DHCP / 无固定 IP）

Kubernetes 假定节点 IP 是稳定的（etcd 成员列表、apiserver 证书 SAN、kubelet 注册地址等都绑定物理 IP）。如果物理机使用 DHCP 且无法固定 IP，可以通过 loopback 虚拟 IP 解决。

#### 方案：loopback 固定 IP（单机开发测试）

在 loopback 接口上绑定一个固定 IP，不依赖任何外部网络：

```bash
# 1. 添加虚拟 IP（立即生效）
sudo ip addr add 10.10.10.1/32 dev lo

# 2. 持久化（重启后自动生效）
# Ubuntu/Debian（netplan）：
cat > /etc/netplan/99-lo-static.yaml <<'EOF'
network:
  version: 2
  ethernets:
    lo:
      addresses:
        - 10.10.10.1/32
EOF

# 3. 验证
ip addr show lo
# 应看到: inet 10.10.10.1/32 scope global lo
```

#### 前置：内核参数

kubelet 要求以下内核参数，部分桌面/开发机默认未设置，缺失会导致 kubelet 启动失败（`Failed to start ContainerManager: invalid kernel flag`）：

```bash
# 设置并持久化
sysctl -w kernel.panic=10 kernel.panic_on_oops=1
cat >> /etc/sysctl.d/99-kubernetes.conf <<'EOF'
kernel.panic=10
kernel.panic_on_oops=1
EOF
```

#### 部署集群

```bash
# 确认 SSH 连通
ssh -i ~/.ssh/id_ed25519 root@10.10.10.1 "hostname"

# 部署单机集群
cyctl cluster run 192.168.1.100:5000/cycore/kubernetes:v1.35.3 \
    -m 10.10.10.1 \
    -k ~/.ssh/id_ed25519 \
    --registry http://user:pass@192.168.1.100:5000
```

> **注意**：`127.0.0.1` 不能用作 master IP，kubeadm 会将其写入证书和 advertise-address，导致 apiserver 通信异常。

#### IP 地址选择建议

| 场景 | 推荐方案 |
|------|---------|
| 单机开发测试 | loopback 虚拟 IP（如 `10.10.10.1`） |
| 多机 + DHCP | DHCP MAC 绑定保留固定 IP（最可靠） |
| 多机 + 无法固定 IP | Tailscale / WireGuard 固定隧道 IP（注意 MTU 和性能） |
| 生产环境 | 静态 IP（必须），有线网络 |

#### 多机场景

如果多台机器都无法固定 IP，优先考虑网络侧解决（DHCP 保留、静态 IP）。K8s 核心组件深度依赖节点 IP：

- **etcd**：成员 peer URL 是 IP
- **apiserver**：证书 SAN 包含 IP，advertise-address 是 IP
- **kubelet**：注册时上报 InternalIP
- **Calico/CNI**：BGP peer 基于 node IP

节点 IP 变化基本等于需要重新 join。如果 IP 频繁变化，可以将节点视为 cattle（而非 pet），IP 变化后 `cyctl node delete` + `cyctl node add` 重新加入。

## 组件密码配置

所有中间件组件的密码在安装时**自动生成 24 位随机值**，保存到 `~/.cycore/component-secrets.env`。用 `--set` 可手动指定。

> 共享变量（如 `rustfs_secret_key`）在多个组件间自动复用同一个值。

#### 密码变量一览

| 组件 | 变量名 | 默认行为 |
|------|--------|----------|
| MySQL | `mysql_root_password` | 自动生成 |
| Redis | `redis_password` | 自动生成 |
| PostgreSQL | `postgresql_password` | 自动生成 |
| Grafana | `grafana_admin_password` | 自动生成 |
| RustFS | `rustfs_access_key` | 自动生成 |
| RustFS | `rustfs_secret_key` | 自动生成 |
| Nessie | `nessie_db_password` | 自动生成 |

#### 安装时指定密码

```bash
cyctl component install mysql \
  --package /tmp/cycore-k8s-offline \
  --set mysql_root_password=MySecurePassword123

cyctl component install redis,mysql,rustfs \
  --package /tmp/cycore-k8s-offline \
  --set mysql_root_password=MySQL@Prod \
  --set redis_password=Redis@Prod \
  --set rustfs_secret_key=RustFS@Prod
```

#### 已安装组件修改密码

对已运行的组件，重新执行 `component install` 并带上新密码即可（等同于 helm upgrade）：

```bash
cyctl component install grafana \
  --package /tmp/cycore-k8s-offline \
  --set grafana_admin_password=NewAdmin@2026
```

> **注意**：MySQL、PostgreSQL 修改 root 密码后，需要同步更新依赖该密码的应用配置（如 后端应用的数据库连接串）。

#### 查看当前密码

从 Kubernetes Secret 中读取已部署组件的密码：

```bash
# MySQL
kubectl -n middleware get secret mysql -o jsonpath='{.data.root-password}' | base64 -d; echo

# Redis
kubectl -n middleware get secret redis -o jsonpath='{.data.redis-password}' | base64 -d; echo

# Grafana
kubectl -n monitoring get secret prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo

# RustFS
kubectl -n middleware get secret rustfs-secret -o jsonpath='{.data.secret_key}' | base64 -d; echo
```

## Nginx 配置与前端部署

Nginx 以 Deployment 方式运行在 `middleware` 命名空间，通过两个 ConfigMap 管理配置：

- `nginx-conf`：主配置（`nginx.conf`）
- `nginx-site`：站点配置（`/etc/nginx/conf.d/*.conf`）

前端静态文件挂载在 `${STORAGE_BASE}/nginx/html`（hostPath），默认监听 80/443 端口，NodePort 为 30180（HTTP）和 30443（HTTPS）。

Nginx 自带 `nginx-reloader` sidecar，修改 ConfigMap 后自动 reload，无需重启 pod。

#### 修改站点配置

```bash
kubectl -n middleware edit configmap nginx-site
```

例如添加 API 反向代理：

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://my-backend-svc.default.svc.cluster.local:8080/;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 代理
    location /ws/ {
        proxy_pass http://my-backend-svc.default.svc.cluster.local:8080/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }

    location /health {
        access_log off;
        return 200 'ok';
    }
}
```

保存后 reloader sidecar 自动检测变更并执行 `nginx -s reload`。

#### 部署前端应用

将前端构建产物复制到 Nginx 的 hostPath 目录：

```bash
# 在 master 节点上
STORAGE_BASE=/data/cycore   # 与 component install 时的 --storage-base 一致
cp -r dist/* ${STORAGE_BASE}/nginx/html/
```

或通过 kubectl cp 复制到 pod 内（数据会同步到 hostPath）：

```bash
kubectl -n middleware cp dist/. nginx-xxx:/usr/share/nginx/html/
```

#### 配置 TLS/HTTPS

1. 创建 TLS Secret：

```bash
kubectl -n middleware create secret tls nginx-tls-secret \
  --cert=server.crt --key=server.key
```

2. 编辑 `nginx-site` ConfigMap，启用 443 server 段：

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /etc/nginx/ssl/tls.crt;
    ssl_certificate_key /etc/nginx/ssl/tls.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
```

#### 修改主配置

如需调整 `worker_processes`、`client_max_body_size` 等全局参数：

```bash
kubectl -n middleware edit configmap nginx-conf
```

## kube-proxy IPVS 模式

`cyctl cluster run` 默认配置 kube-proxy 为 **IPVS 模式**。相比 iptables 模式，IPVS 有以下优势：

| 对比项 | iptables | IPVS |
|--------|----------|------|
| 性能 | Service 数量增加时规则线性增长，万级 Service 时延迟明显 | 哈希查找 O(1)，大规模场景性能稳定 |
| 负载均衡 | 随机（iptables probability） | 支持 rr/wrr/lc/sh 等多种算法 |
| VPN/隧道兼容 | NodePort DNAT 在 PREROUTING 链处理，tun 设备注入的包可能跳过此链导致不通 | NodePort 在 INPUT 链处理，tun 设备（如 Tailscale/WireGuard）的包能被正确转发 |
| 内核模块 | 无额外依赖 | 需要 `ip_vs`、`ip_vs_rr`、`ip_vs_wrr`、`ip_vs_sh`、`nf_conntrack` |

cyctl 的节点初始化流程会自动加载所需的 IPVS 内核模块，无需手动配置。

#### Tailscale + NodePort 兼容性说明

kube-proxy iptables 模式下，NodePort 不会在主机上打开端口，完全依赖 iptables `nat PREROUTING` 链做 DNAT。通过 tun 设备（如 Tailscale）进入的包不经过 PREROUTING 链，导致 DNAT 不生效，NodePort 不通。

IPVS 模式在 INPUT 链处理 NodePort 流量，tun 设备注入的包正常经过 INPUT 链，因此 Tailscale IP 可以直接访问 NodePort 服务。

#### 已有集群切换到 IPVS 模式

```bash
# 1. 加载 IPVS 内核模块
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack

# 2. 修改 kube-proxy configmap
kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed 's/mode: ""/mode: "ipvs"/' | kubectl apply -f -

# 3. 重启 kube-proxy
kubectl rollout restart daemonset kube-proxy -n kube-system

# 4. 验证
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=5
# 应看到: Using ipvs Proxier
```

> **注意：** IPVS 模式下，`cyctl ctl clean` 会额外清理 `kube-ipvs0` 虚拟网卡和 IPVS 规则。`cluster reset` 已自动处理。

## 组件存储要求

组件使用 `--storage-base` 指定的目录存储数据（hostPath）。部分组件对存储类型有严格要求，即使共享存储性能足够，仍可能因语义不兼容导致数据损坏。

下表将限制分为两类：
- **正确性问题**：即使共享存储性能很高，仍然不能用，因为依赖 `O_DIRECT`、`mmap`、严格 `fsync` 等 POSIX 特性，或应用层自带副本机制导致多 pod 写同一目录会冲突
- **性能问题**：共享存储功能上可以用，但延迟敏感，本地盘显著更优

#### 即使高性能共享存储也不能用（正确性问题）

| 组件 | 原因 |
|------|------|
| **Prometheus** | TSDB 使用 `mmap` 映射数据文件，NFS 不支持 `mmap`（或行为不正确），compaction 期间会 crash |
| **NATS** (distributed) | 3 个 pod 各自维护独立的 Raft 日志，如果挂载到同一个共享目录，多个 pod 会覆盖彼此的 WAL 文件，导致 Raft 状态机损坏 |
| **RustFS** (distributed) | 对象存储引擎自带纠删码/多副本，各节点的数据目录内容不同（分片），共享目录会导致分片覆盖 |

#### 取决于共享存储类型

| 组件 | 关键约束 | 判断方法 |
|------|---------|---------|
| **MySQL** | InnoDB 依赖 `O_DIRECT` 绕过 OS page cache | `dd if=/dev/zero of=<path>/test bs=4k count=1 oflag=direct`，成功则可用。Lustre/GPFS/BeeGFS 通常支持；NFS/CephFS 通常不支持 |

> MySQL 在支持 `O_DIRECT` 的共享高性能存储上可以正常运行，且 pod 漂移不丢数据，无需 `--node-selector`。

#### 高性能共享存储可以用，但本地盘更优（性能问题）

| 组件 | 说明 |
|------|------|
| **PostgreSQL** | WAL 和 checkpoint 依赖 `fsync`，高性能共享存储功能上可行，但 fsync 延迟直接影响事务吞吐 |
| **Redis** | AOF `fsync` 频率高（everysec 或 always），高性能共享存储可以用，但每次 fsync 的网络往返会增加 P99 延迟 |

#### 可以使用共享存储

| 组件 | 原因 |
|------|------|
| **Loki** (standalone) | 日志文件顺序写入，对 `fsync` 要求不高，单副本场景共享存储可接受 |
| **Loki** (distributed) | 已配置走 S3（RustFS），不使用本地存储 |
| **Grafana** | 只存 dashboard/session 等元数据，IO 极轻 |
| **Nginx** | 静态文件服务，以读为主 |
| **OpenSearch** (Querybook) | 单节点搜索索引，IO 不密集 |
| **NATS** (standalone) | 单 pod，无多写冲突，高性能共享存储功能上可行 |

#### 判断规则

1. **应用层多副本 + 各副本写独立数据** → 不能用共享存储（NATS distributed、RustFS distributed）
2. **依赖 `mmap`** → 不能用 NFS（Prometheus）
3. **依赖 `O_DIRECT`** → 需验证共享存储是否支持（MySQL），用 `dd oflag=direct` 测试
4. **依赖严格 `fsync`** → 高性能共享存储功能上可行，但性能劣化（PostgreSQL、Redis）
5. **轻量 IO 或无状态** → 共享存储没问题（Grafana、Nginx、Loki distributed）

#### distributed 模式的存储说明

distributed 模式下各组件的数据冗余由应用层保证，不需要存储层再做一次副本：

| 组件 | 副本机制 | 存储方式 |
|------|---------|---------|
| NATS (3 节点) | Raft 协议同步，每条 stream 3 副本 | 各节点独立 hostPath |
| Prometheus (2 副本) | 两副本各自独立采集，podAntiAffinity 分布到不同节点 | 各节点独立 hostPath |
| RustFS (4 节点) | 纠删码 EC:4 或副本模式 | 各节点独立 hostPath |
| Loki (distributed) | 无本地持久化 | S3 后端（RustFS） |
| Nessie (3 副本) | 无状态，数据在 PostgreSQL | 无本地存储 |
| Trino | 无状态计算引擎 | 无本地存储 |

如果使用共享存储（如 NFS）挂载 `--storage-base`，NATS 3 个 pod 会同时写入同一个目录，加上应用层 3 副本 × 存储层 N 副本 = 3N 份冗余数据。更严重的是，NFS 的 `fsync` 语义不可靠，可能导致 Raft 日志损坏。

## 节点迁移（RustFS 分布式模式）

当某个节点磁盘即将写满，需要将 RustFS 数据迁移到新节点时。适用于分布式模式（StatefulSet + directMount hostPath + 纠删码 EC 2+2）。

**整个过程 RustFS 不需要停服务**，纠删码可容忍 1 个节点缺失。

#### 操作步骤

```bash
# 1. 将新节点加入 K8s 集群
cyctl node add --nodes <新节点IP> -k ~/.ssh/id_ed25519

# 如果 kubelet 启动失败报 kernel flag 错误（ProtectKernelDefaults）：
ssh <新节点IP> "sysctl -w kernel.panic_on_oops=1 && sysctl -w kernel.panic=10"
ssh <新节点IP> "echo 'kernel.panic_on_oops=1' >> /etc/sysctl.conf && echo 'kernel.panic=10' >> /etc/sysctl.conf"
ssh <新节点IP> "systemctl restart kubelet"

# 2. 确认新节点 Ready
kubectl get nodes -o wide

# 3. 封锁旧节点（禁止新 pod 调度，现有 pod 继续运行）
kubectl cordon <旧节点名>

# 4. 确认旧节点上的 rustfs pod
kubectl get pod -n middleware -l app.kubernetes.io/name=rustfs -o wide

# 5. 删除旧节点上的 rustfs pod（StatefulSet 自动在新节点重建）
kubectl delete pod <pod名> -n middleware

# 6. 等待新 pod Ready（RustFS 自动从其他节点 healing 重建数据分片）
kubectl get pod -n middleware -l app.kubernetes.io/name=rustfs -o wide -w

# 7. 验证集群健康（任意 pod 上查均可，返回全局状态）
kubectl exec -n middleware rustfs-0 -- curl -s http://localhost:9000/minio/health/cluster
# 预期：{"status":"ok","ready":true,"degradedReasons":[]}

# 8. 观察一段时间确认稳定后，下线旧节点
kubectl drain <旧节点名> --ignore-daemonsets --delete-emptydir-data
cyctl node delete --nodes <旧节点IP>
```

#### 说明

| 问题 | 说明 |
|------|------|
| 需要 rsync 吗？ | 数据量较小（< 几十 GB）不需要，RustFS 纠删码自动从其余节点 healing 重建。TB 级数据可先 rsync 减少 healing 时间 |
| 需要停服务吗？ | 不需要。删 pod 后短暂降级（3/4 节点），healing 完成后恢复 4/4 |
| 能加副本吗？ | 不能。纠删码节点数在初始化时确定（4 节点 = EC 2+2），只能替换，不能通过增加 `rustfs-4` 扩容 |
| 在线写入影响 rsync？ | RustFS 在线时持续写入，rsync 不保证一致性。但这不影响——rsync 只是减少 healing 量的优化，healing 机制本身保证最终一致 |
