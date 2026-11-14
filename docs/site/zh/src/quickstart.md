# 快速开始

## 构建 rootfs 镜像（可选，首次使用）

```bash
# 从上游下载 K8s v1.35.3 组件，打包为 OCI rootfs 镜像
cyctl image build-rootfs --k8s-version v1.35.3

# 通过代理加速下载
cyctl image build-rootfs --k8s-version v1.35.3 --proxy socks5://127.0.0.1:1080

# 包含 calico CNI 插件（支持版本指定）
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico:3.30.0

cyctl image build-rootfs \
     --k8s-version v1.35.3 \
     --cycore-bin target/x86_64-unknown-linux-musl/release/cyctl \
     --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
     --arch amd64 \
     --addon calico \
     --output-dir ./out
```

输出文件: `./kubernetes-v1.35.3-amd64.tar`

rootfs 镜像中已预置 K8s 系统容器镜像（kube-apiserver、etcd 等），部署时无需联网拉取。如果需要使用容器镜像 mirror 加速拉取：

```bash
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers
```

## 部署 3 Master HA 集群

```bash
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p 'YourSecurePassword'
```

如果节点已配置 SSH 免密登录，使用 `-k` 指定密钥：

```bash
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -k ~/.ssh/id_rsa
```

此命令会：
1. 拉取集群镜像（或使用本地缓存）
2. 通过 SSH 分发到所有节点
3. 在节点上初始化 containerd、kubelet
4. 使用 kubeadm 初始化第一个 master，其余 master join
5. 配置 IPVS 负载均衡 (HA)
6. Worker 节点 join 集群

## 检查集群状态

```bash
cyctl cluster status default
```

输出（JSON 格式）：
```json
{
  "name": "default",
  "phase": "running",
  "images": ["cycore/kubernetes:v1.35.3"],
  "masters": ["10.0.0.1", "10.0.0.2", "10.0.0.3"],
  "workers": ["10.0.0.11", "10.0.0.12"],
  "node_status": [
    {"ip": "10.0.0.1", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.2", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.3", "role": "master", "status": "Ready"},
    {"ip": "10.0.0.11", "role": "node", "status": "Ready"},
    {"ip": "10.0.0.12", "role": "node", "status": "Ready"}
  ]
}
```

## 扩缩容

```bash
# 添加 worker 节点
cyctl node add -n 10.0.0.13 -p 'YourSecurePassword'

# 删除 worker 节点
cyctl node delete -n 10.0.0.12 -p 'YourSecurePassword'
```

## 远程执行命令

```bash
cyctl remote exec -m 10.0.0.1 -p 'YourSecurePassword' \
  -- 'kubectl get nodes -o wide'
```

## 巡检集群

```bash
cyctl cluster inspect --hosts 10.0.0.1,10.0.0.2,10.0.0.3 -p 'YourSecurePassword'
```

## 销毁集群

```bash
# 标准 reset
cyctl cluster reset default --force

# 彻底清理（删除所有 K8s 组件和二进制）
cyctl cluster reset -c default --force --purge
```
