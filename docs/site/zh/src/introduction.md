# 概览

> 版本: 0.1.0 | 更新日期: 2026-09

cyctl 是一个用 Rust 编写的 Kubernetes 集群生命周期管理 CLI 工具。它通过 SSH 将 OCI 集群镜像部署到目标节点，支持完全离线安装和内建高可用（HA）。

核心能力：
- **一键部署** — 单条命令完成多 master HA 集群的部署
- **声明式管理** — 通过 Clusterfile 描述期望状态，apply 即生效
- **弹性伸缩** — 一键添加/删除 worker 节点
- **离线支持** — 从上游组件构建 rootfs 镜像，完全离线部署
- **AI Agent 友好** — 所有输出支持 JSON 结构化格式，区分 exit code，支持 `--quiet` 静默模式

cyctl 是用 Rust 编写的 Kubernetes 集群生命周期管理工具，性能优秀，单一二进制（无 shell 脚本依赖），且原生支持 AI Agent 集成。
