# component — 组件管理

`component` 子命令用于管理 K8s 集群上的中间件和数据平台组件。

## component install — 安装组件

```
cyctl component install <COMPONENTS> [OPTIONS]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `<COMPONENTS>` | 组件名称（逗号分隔，支持批量安装） | 必填 |
| `--package` | 离线安装包路径 | — |
| `--storage-base` | 数据存储根目录（hostPath） | — |
| `--profile` | 部署模式：standalone / distributed | `standalone` |
| `--node-selector` | 节点绑定（简写主机名或 key=value） | — |
| `--set` | 覆盖变量 KEY=VALUE，可重复 | — |

示例：
```bash
# 安装单个组件
cyctl component install mysql \
  --package /tmp/cycore-k8s-offline --storage-base /data/k8s

# 批量安装
cyctl component install mysql,redis,postgresql,nginx \
  --package /tmp/cycore-k8s-offline --storage-base /mnt/public/cycore

# 分布式模式
cyctl component install rustfs,nats \
  --package /tmp/cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed

# 自定义参数
cyctl component install mysql \
  --package /tmp/cycore-k8s-offline \
  --set mysql_root_password=MySecurePassword123
```

## component pack — 离线打包

```bash
# 默认只打包 standalone 镜像
cyctl component pack

# 打包所有 profiles 的镜像（含 distributed）
cyctl component pack --all-profiles

# 只打包指定 profile 的镜像
cyctl component pack --profile distributed
```

## 组件依赖关系与安装顺序

部分组件依赖其他组件提供的服务，安装时需要遵循以下顺序：

### 无依赖（基础层，可独立安装）

| 类别 | 组件 |
|------|------|
| 调度/算子 | volcano, training-operator, kuberay, gpu-operator |
| 中间件 | nats, mysql, redis, rustfs, postgresql, nginx |
| 数据平台（无依赖） | spark-operator, strimzi-kafka, clickhouse-operator |

### 有依赖（必须先安装依赖项）

| 组件 | 依赖 | 说明 |
|------|------|------|
| prometheus | local-path-provisioner | TSDB 使用 PVC（local-path StorageClass） |
| prometheus-adapter | prometheus | 连接 prometheus 服务获取指标 |
| alloy | loki | 推送日志到 loki 服务 |
| loki (distributed) | rustfs | S3 对象存储后端（standalone 模式无此依赖） |
| nessie | postgresql | JDBC 连接 PostgreSQL，需要数据库/schema/用户（db_init 自动创建）|
| alluxio | rustfs | S3 endpoint 连接 RustFS 对象存储 |
| querybook | mysql, redis | 数据库 + 缓存/任务队列 |

### 推荐安装顺序（standalone 模式）

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

### 推荐安装顺序（distributed 分布式模式）

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

> **存储说明：** 除 Loki distributed 需要共享存储（S3/RustFS）外，其他所有组件的 distributed 模式均使用本机 hostPath（`--storage-base` 指定的目录），各节点各副本的数据独立，不需要共享磁盘或 NFS。Loki distributed 依赖 RustFS 提供 S3 兼容接口，必须先安装 RustFS。详见 [组件存储要求](../guides/advanced.md#组件存储要求)。

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
      accessKeyId: cycoreadmin        # RustFS 默认 Access Key
      secretAccessKey: CycoreRustFS2026  # RustFS 默认 Secret Key
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

## 组件密码配置

所有中间件组件的密码通过 `config_schema` 定义默认值，安装时用 `--set` 覆盖。

### 默认密码一览

| 组件 | 变量名 | 默认值 |
|------|--------|--------|
| MySQL | `mysql_root_password` | `CycoreMySQL2026` |
| Redis | `redis_password` | `CycoreRedis2026` |
| PostgreSQL | `postgresql_password` | `CycorePostgres2026` |
| Grafana | `grafana_admin_password` | `CycoreAdmin2026` |
| RustFS | `rustfs_access_key` | `cycoreadmin` |
| RustFS | `rustfs_secret_key` | `CycoreRustFS2026` |
| Nessie | `nessie_db_password` | `NessieDB2026` |

### 安装时指定密码

```bash
cyctl component install mysql \
  --package /tmp/cycore-k8s-offline \
  --set mysql_root_password=MySecurePassword123

cyctl component install redis,mysql,rustfs \
  --package /tmp/cycore-k8s-offline \
  --set mysql_root_password=MySQL@2026 \
  --set redis_password=Redis@2026 \
  --set rustfs_secret_key=RustFS@2026
```

### 已安装组件修改密码

对已运行的组件，重新执行 `component install` 并带上新密码即可（等同于 helm upgrade）：

```bash
cyctl component install grafana \
  --package /tmp/cycore-k8s-offline \
  --set grafana_admin_password=NewAdmin@2026
```

> **注意**：MySQL、PostgreSQL 修改 root 密码后，需要同步更新依赖该密码的应用配置（如数据库连接串）。

### 查看当前密码

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
