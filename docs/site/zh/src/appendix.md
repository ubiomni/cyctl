# 附录

## 默认组件版本映射

`cyctl image build-rootfs` 根据指定的 K8s 版本自动选择匹配的容器运行时和工具版本：

| K8s 版本 | containerd | runc | crictl | registry |
|---------|-----------|------|--------|----------|
| ≤1.28 | 1.7.27 | 1.1.14 | 1.28.0 | 2.8.3 |
| 1.29 | 1.7.27 | 1.1.14 | 1.29.0 | 2.8.3 |
| 1.30 | 1.7.27 | 1.1.14 | 1.30.1 | 2.8.3 |
| 1.31 | 1.7.27 | 1.2.6 | 1.31.1 | 2.8.3 |
| 1.32 | 1.7.27 | 1.2.6 | 1.32.0 | 2.8.3 |
| 1.33 | 2.0.4 | 1.2.6 | 1.33.0 | 2.8.3 |
| 1.34+ | 2.1.1 | 1.2.6 | 1.33.0 | 2.8.3 |

> K8s 1.33 起默认使用 containerd 2.x。containerd 2.x 移除了 v1 CRI 插件配置格式，cyctl 会自动生成对应版本的配置。

## 内置组件全景

cyctl 内置 20+ 组件，围绕 AI 数据生命周期构建完整技术栈：

| 阶段 | 组件 | 作用 |
|------|------|------|
| **数据采集** | Kafka (Strimzi), NATS | 实时数据摄入、语料流式采集、事件驱动管线 |
| **数据存储** | RustFS | S3 兼容对象存储，承载数据集、语料库、模型文件、checkpoint |
| **数据集管理** | Nessie | Iceberg REST catalog，数据集版本控制（可追溯哪次训练用了哪版数据） |
| **数据处理** | Spark | 语料清洗、特征工程、大规模 ETL |
| **数据查询** | Trino | 分布式 SQL，直接查询 Iceberg 表探索数据集 |
| **数据缓存** | Alluxio | 热数据本地化，加速训练读取和 Spark/Trino 计算 |
| **GPU 训练** | gpu-operator, training-operator, volcano | GPU 驱动管理、PyTorchJob/MPIJob、Gang Scheduling |
| **推理服务** | KubeRay | Ray Serve 模型部署、分布式推理、自动扩缩 |
| **监控运维** | Prometheus, Loki, Alloy, Grafana | GPU/节点指标、训练日志、可视化、基于 GPU 利用率的 HPA |
| **中间件** | MySQL, Redis, PostgreSQL, Nginx | 业务数据库、缓存、网关 |
| **分析** | ClickHouse | 训练指标分析、数据质量统计、OLAP |

所有组件支持 standalone 和 distributed 两种部署模式，通过 `--profile` 切换。
