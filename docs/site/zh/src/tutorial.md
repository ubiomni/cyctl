# 教程：离线部署完整流程

本教程按实际操作顺序，演示从零搭建 Kubernetes 集群到安装完整组件平台的全过程。

共分三个阶段：

| 阶段 | 内容 | 结束状态 |
|------|------|---------|
| 一 | 构建镜像，启动最小集群 | `kubectl get nodes` 全部 Ready |
| 二 | 打包并安装基础组件 | 存储、中间件、监控 Pod 全部 Running |
| 三 | 分布式部署与数据平台 | 数据平台 Pod 全部 Running |

---

## 阶段一：构建镜像并启动集群

### 1.1 构建集群镜像

在有外网的机器上，从上游构建 Kubernetes rootfs 镜像：

```bash
cyctl image build-rootfs \
  --k8s-version v1.35.3 \
  --arch amd64 \
  --addon calico \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
  --output-dir ./out
```

构建完成后检查产物：

```bash
ls -lh ./out
# kubernetes-v1.35.3-amd64.tar
```

### 1.2 分发镜像到目标服务器

**方式一：直接上传**

```bash
scp ./out/kubernetes-v1.35.3-amd64.tar root@<MASTER_IP>:/tmp/
```

**方式二：推送到私有仓库**

```bash
cyctl image load --input ./out/kubernetes-v1.35.3-amd64.tar
cyctl image push <REGISTRY>/kubernetes:v1.35.3
```

### 1.3 启动最小集群

登录目标服务器，一条命令启动集群：

```bash
# 单 master
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m <MASTER_IP> \
  -k ~/.ssh/id_ed25519

# 多 master HA + worker 节点
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m <MASTER1>,<MASTER2>,<MASTER3> \
  -n <WORKER1>,<WORKER2> \
  -k ~/.ssh/id_ed25519 \
  --registry http://<USER>:<PASS>@<REGISTRY_IP>:<PORT>
```

### 1.4 验证集群

```bash
kubectl get nodes
kubectl get pods -A
```

所有节点 `Ready`，系统 Pod 全部 `Running` 即成功。

---

## 阶段二：安装基础组件

### 2.1 打包组件离线包

在有外网的机器上打包：

```bash
# 打包全部组件
cyctl component pack --all-profiles

# 只打包指定组件
cyctl component pack mysql,redis,prometheus

# 仅更新配置（跳过镜像拉取）
cyctl component pack --skip-images
```

将产物上传到目标服务器：

```bash
scp cycore-k8s-offline-*.tar.gz root@<MASTER_IP>:/tmp/
```

### 2.2 解压离线包

```bash
cd /tmp
tar xf cycore-k8s-offline-*.tar.gz
```

### 2.3 安装存储与基础设施

> 组件之间有依赖关系，请按以下顺序安装。

```bash
# 第一批：本地存储
cyctl component install local-path-provisioner \
  --package ./cycore-k8s-offline --storage-base /data/cycore

# 第二批：调度与监控基础
cyctl component install volcano,kuberay,metrics-server \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

### 2.4 安装中间件

```bash
cyctl component install mysql,redis,nginx \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

> 没有共享磁盘时，用 `--node-selector` 将有状态服务固定到特定节点：
> ```bash
> cyctl component install mysql \
>   --package ./cycore-k8s-offline --storage-base /data/cycore \
>   --node-selector <NODE_NAME>
> ```

### 2.5 安装监控与日志

```bash
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### 2.6 安装训练与 GPU 组件（可选）

```bash
cyctl component install training-operator,gpu-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore
```

验证 GPU：

```bash
kubectl run gpu-test --rm -it --restart=Never \
  --image=cycore.local:4000/cuda:12.4.1-base-ubi8 \
  --overrides='{"spec":{"containers":[{"name":"gpu-test","image":"cycore.local:4000/cuda:12.4.1-base-ubi8","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}' \
  --command -- nvidia-smi
```

### 2.7 验证

```bash
kubectl get pods -A
kubectl top nodes
```

---

## 阶段三：分布式部署与数据平台

### 3.1 分布式存储与监控

用 `--profile distributed` 切换到分布式高可用架构：

```bash
# 第一步：对象存储与消息队列
cyctl component install rustfs,nats \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed

# 第二步：监控与日志（Loki 依赖 RustFS）
cyctl component install prometheus,prometheus-adapter,loki,alloy \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed
```

> Loki 分布式模式需要提前创建 bucket：`loki-chunks`、`loki-ruler`、`loki-admin`

**支持分布式的组件：**

| 组件 | 默认模式 | 分布式模式 |
|------|---------|-----------|
| loki | 单实例，本地存储 | 微服务模式，S3 存储，依赖 RustFS |
| prometheus | 单副本 | 双副本，跨节点部署 |
| nats | 单节点 | 三节点集群 |
| trino | 单 coordinator | coordinator + 3 worker |
| nessie | 2 副本 | 3 副本，依赖 PostgreSQL |
| rustfs | 单节点 | 多节点 |
| alluxio | 单机 | 高可用模式 |

### 3.2 数据平台

```bash
# 前置：Nessie 依赖 PostgreSQL
cyctl component install postgresql \
  --package ./cycore-k8s-offline --storage-base /data/cycore

# 数据平台组件
cyctl component install nessie,trino,spark-operator,strimzi-kafka,clickhouse-operator \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --profile distributed

# 缓存层（无共享磁盘时固定节点）
cyctl component install alluxio \
  --package ./cycore-k8s-offline --storage-base /data/cycore \
  --node-selector kubernetes.io/hostname=<NODE_NAME>
```

### 3.3 验证

```bash
kubectl get pods -A
kubectl top nodes
```

### 3.4 卸载与重置

```bash
# 按组件卸载
cyctl component uninstall metrics-server,prometheus,loki,alloy \
  --package ./cycore-k8s-offline

# 重置整个集群
cyctl cluster reset --data-dir ~/.cycore --force
```
