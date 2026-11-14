# 概览

> 版本: 0.1.0 | 更新日期: 2026-11

cyctl 是一个用 Rust 编写的 Kubernetes 集群生命周期管理 CLI 工具。它通过 SSH 将 OCI 集群镜像部署到目标节点，支持完全离线安装和内建高可用（HA）。

## 为什么做 cyctl

AI 训练和推理平台需要的不只是一个 K8s 集群 — 还需要 GPU 调度、分布式存储、监控告警、数据湖引擎等一整套基础设施。传统方式需要逐个手动部署这些组件，版本兼容、离线打包、配置调优都是重复劳动。

cyctl 将这个过程缩短为三步：**构建镜像 → 部署集群 → 安装组件**。所有组件预置了面向 AI 场景的默认配置，开箱可用。

## 核心能力

- **一键部署** — 单条命令完成多 master HA 集群部署，自动配置 IPVS、containerd、kubelet
- **组件编排** — 内置 20+ 中间件和数据平台组件（MySQL、Redis、Prometheus、Trino、Spark 等），自动处理依赖顺序
- **完全离线** — 从上游构建 rootfs 镜像，打包组件离线包，在无网环境一键安装
- **弹性伸缩** — 一键添加/删除 worker 节点
- **AI Agent 原生支持** — JSON 结构化输出、分类 exit code、`--quiet` 静默模式，可直接被 LLM Agent 调用

## AI 基础设施场景

cyctl 针对 AI 训练和推理场景做了深度优化：

### GPU 集群部署

```bash
# 部署 K8s 集群（含 GPU 节点）
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -k ~/.ssh/id_ed25519

# 安装 GPU operator + 训练框架调度
cyctl component install gpu-operator,training-operator,volcano \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

安装完成后即可提交分布式训练任务（PyTorchJob / MPIJob），Volcano 负责 Gang Scheduling 保证 GPU 资源整体分配。

### AI 数据平台

```bash
# 对象存储 + 数据湖引擎
cyctl component install rustfs,nessie,trino,spark-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed
```

构建从数据存储到 SQL 查询的完整数据链路：

| 层级 | 组件 | 用途 |
|------|------|------|
| 对象存储 | RustFS | S3 兼容存储，训练数据 / 模型文件 / checkpoint |
| 数据目录 | Nessie | Apache Iceberg REST catalog，数据版本管理 |
| 查询引擎 | Trino | 分布式 SQL 查询，直接查 Iceberg 表 |
| 计算引擎 | Spark | 大规模数据处理、ETL、特征工程 |
| 缓存加速 | Alluxio | 数据本地化缓存，加速 Spark/Trino 读取 |

### 监控与可观测性

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

开箱即用的监控栈：Prometheus 采集 GPU/节点/Pod 指标，Loki 收集训练日志，Grafana 提供可视化。prometheus-adapter 将自定义指标暴露给 HPA，支持基于 GPU 利用率自动扩缩推理服务。

### Kubelet 针对 AI 训练优化

cyctl 内置了面向 AI 场景的 kubelet 默认值：

| 优化项 | 说明 |
|--------|------|
| `imageMinimumGCAge: 72h` | 离线环境保护镜像不被过早清理 |
| `serializeImagePulls: false` | 并行拉取镜像，加速大规模部署 |
| `containerLogMaxSize: 50Mi` | 放宽日志上限，适配训练任务大量输出 |
| `kubeReserved / systemReserved` | 为系统预留 CPU 和内存，防止训练任务挤占 |
| `evictionHard.memory: 1Gi` | 提前驱逐，避免 GPU 节点 OOM |

### AI Agent 集成

cyctl 所有命令支持 JSON 输出和结构化错误码，可以直接被 Claude、GPT 等 LLM Agent 调用：

```bash
# Agent 查询集群状态
cyctl cluster status default -o json --quiet

# Agent 安装组件
cyctl component install redis --package ./pkg --storage-base /data/cycore -o json

# Agent 检查 Pod 健康
cyctl cluster inspect --hosts 10.0.0.1 -k ~/.ssh/id_rsa -o json --quiet
```

详见 [AI Agent 集成指南](./guides/ai-agent.md)。

## 架构概览

cyctl 通过 SSH 连接目标节点完成部署：

1. **镜像构建** — 从上游下载 K8s 二进制、containerd、系统镜像，打包为 OCI rootfs
2. **镜像分发** — 通过 SSH 将 rootfs 传输到所有节点
3. **节点初始化** — 安装 containerd、kubelet，配置内核参数和 IPVS 模块
4. **集群引导** — kubeadm init 第一个 master，其余 master 和 worker join
5. **HA 配置** — 自动配置 IPVS 负载均衡到多个 apiserver
6. **Registry 启动** — 每个节点启动本地 OCI registry，加载预取的系统镜像

所有集群状态持久化到本地，后续操作（扩缩容、巡检、重置）无需重复输入连接信息。
