# 私有镜像仓库配置

## HTTPS 私有仓库

如果你的私有仓库使用 HTTPS（即使是自签名证书），cyctl 会自动配置 containerd 的 `skip_verify = true`：

```bash
# 部署时指定私有 registry
cyctl cluster run myregistry.com:4000/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p xxx
```

## HTTP 私有仓库（非 HTTPS）

对于 HTTP 协议的私有仓库（如 `http://192.168.1.100:5000/`），需要额外配置 containerd 允许 HTTP 访问。

#### 方法一：部署时通过 --registry-* 参数自动配置（推荐）

`cluster run` 支持通过 `--registry-domain/port/scheme` 在部署时自动配置所有节点的 containerd registry mirror：

```bash
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.11 -p xxx \
  --registry-domain 192.168.1.100 --registry-port 30077 --registry-scheme http
```

这会在所有节点上自动创建 `/etc/containerd/certs.d/192.168.1.100:5000/hosts.toml` 配置。

#### 方法二：集群部署后手动配置

```bash
# 1. 在每个节点上创建 hosts.toml 配置
cyctl remote exec -m 10.0.0.1 -n 10.0.0.11 -p xxx -- '
mkdir -p /etc/containerd/certs.d/192.168.1.100:5000

cat > /etc/containerd/certs.d/192.168.1.100:5000/hosts.toml << EOF
server = "http://192.168.1.100:5000"

[host."http://192.168.1.100:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
'

# 2. 重启 containerd（无需重启）
# containerd 会自动检测 certs.d 目录的变更
```

#### 方法三：使用 cri-shim 自动重写

cri-shim 可以拦截所有镜像拉取请求，自动重写为本地 registry 地址：

```yaml
# /etc/cycore/cri-shim.yaml
address: /var/run/cycore-cri-shim.sock
force: true
image: 192.168.1.100:5000
```

```bash
# 在每个节点上启动 cri-shim
cyctl ctl cri-shim --config /etc/cycore/cri-shim.yaml
```

#### 方法四：配置 containerd config.toml（最完整）

在节点上编辑 `/etc/containerd/config.toml`：

```toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
```

然后创建 hosts.toml：

```bash
mkdir -p /etc/containerd/certs.d/192.168.1.100:5000

cat > /etc/containerd/certs.d/192.168.1.100:5000/hosts.toml << 'EOF'
server = "http://192.168.1.100:5000"

[host."http://192.168.1.100:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

# 如果项目非 public，配置认证
mkdir -p /etc/containerd/certs.d/192.168.1.100:5000

# 为 containerd 配置认证凭据
cat > /etc/containerd/config.toml << 'EOF'
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
  address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
EOF
```

## 私有仓库认证（非 public 项目）

对于需要认证的私有镜像仓库，有三种方式配置凭据：

#### crictl 方式（K8s 原生）

```bash
# 在每个节点上配置
cat > /etc/containerd/certs.d/192.168.1.100:5000/hosts.toml << 'EOF'
server = "http://192.168.1.100:5000"

[host."http://192.168.1.100:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true

  [host."http://192.168.1.100:5000".header]
    Authorization = ["Basic dXNlcjpwYXNzd29yZA=="]
EOF
```

> `dXNlcjpwYXNzd29yZA==` 是 `user:password` 的 base64 编码。
> 生成方式: `echo -n 'user:password' | base64`

#### K8s ImagePullSecret 方式

```bash
# 创建 docker-registry secret
kubectl create secret docker-registry my-registry-cred \
  --docker-server=http://192.168.1.100:5000 \
  --docker-username=admin \
  --docker-password='YourPassword' \
  --docker-email=admin@example.com

# 在 Pod spec 或 ServiceAccount 中引用
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  imagePullSecrets:
    - name: my-registry-cred
  containers:
    - name: app
      image: 192.168.1.100:5000/myproject/myapp:v1.0
```

#### 全局配置 containerd 认证

```bash
# /etc/containerd/certs.d/192.168.1.100:5000/hosts.toml
server = "http://192.168.1.100:5000"

[host."http://192.168.1.100:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true

  # 使用 Docker 认证配置
  [host."http://192.168.1.100:5000".header]
    Authorization = ["Basic dXNlcm5hbWU6cGFzc3dvcmQ="]
```

## 完整示例：部署集群 + 配置 HTTP 私仓

```bash
# 1. 部署集群（同时配置 HTTP 私仓，推荐方式）
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p xxx \
  --registry-domain 192.168.1.100 --registry-port 30077 --registry-scheme http

# 2. 如果 registry 需要认证，额外在所有节点配置
cyctl remote exec -c default -p xxx --role all -- '
mkdir -p /etc/containerd/certs.d/192.168.1.100:5000
cat > /etc/containerd/certs.d/192.168.1.100:5000/hosts.toml << INNER_EOF
server = "http://192.168.1.100:5000"

[host."http://192.168.1.100:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true

  [host."http://192.168.1.100:5000".header]
    Authorization = ["Basic $(echo -n admin:password123 | base64)"]
INNER_EOF
'

# 3. 创建 K8s ImagePullSecret
cyctl remote exec -m 10.0.0.1 -p xxx -- '
kubectl create secret docker-registry private-reg \
  --docker-server=http://192.168.1.100:5000 \
  --docker-username=admin \
  --docker-password=password123
'

# 4. 测试拉取
cyctl remote exec -m 10.0.0.1 -p xxx -- '
crictl pull 192.168.1.100:5000/myproject/myapp:v1.0
'
```
