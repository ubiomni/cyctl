# image — 镜像管理

## `image build-rootfs` — 构建 rootfs 镜像

从上游组件（kubeadm、kubelet、kubectl、containerd、runc、crictl、registry）自动下载并打包成 OCI rootfs 镜像。

```
cyctl image build-rootfs [OPTIONS] --k8s-version <VERSION>
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--k8s-version` | Kubernetes 版本 | 必填 |
| `--cri` | 容器运行时 | `containerd` |
| `--arch` | 目标架构：amd64 / arm64 | `amd64` |
| `-t, --tag` | 输出镜像 tag | `cycore/kubernetes` |
| `--cache-dir` | 缓存目录 | `~/.cycore/cache/binaries` |
| `--no-cache` | 禁用缓存 | `false` |
| `--mirror` | 二进制下载 mirror（替换下载 URL 的 scheme+host 部分） | — |
| `--proxy` | 代理 URL（http/socks5） | — |
| `--output-dir` | 输出目录 | `.` |
| `--registry-mirror` | 镜像 registry 替换（可重复）。无 `=` 为通用替换（保留完整路径），有 `=` 为按源 registry 替换（扁平路径） | — |
| `--extra-images` | 额外要包含的容器镜像（逗号分隔） | — |
| `--image-list` | 自定义镜像列表文件（覆盖自动生成的默认列表） | — |
| `--no-prefetch-images` | 跳过容器镜像预取（rootfs 中不包含系统镜像） | `false` |
| `--insecure-registry` | 允许从 HTTP registry 拉取容器镜像 | `false` |
| `--addon` | 内置 addon，支持版本指定（如 `calico` 或 `calico:3.30.0`），可重复 | — |
| `--addon-dir` | 自定义 addon 目录（含 addon.yaml + manifests/），可重复 | — |

自动选择的组件版本映射：

| K8s 版本 | containerd | runc | crictl | registry |
|----------|-----------|------|--------|----------|
| ≤ 1.28 | 1.7.27 | 1.1.14 | 1.28.0 | 2.8.3 |
| 1.29 | 1.7.27 | 1.1.14 | 1.29.0 | 2.8.3 |
| 1.30 | 1.7.27 | 1.1.14 | 1.30.1 | 2.8.3 |
| 1.31 | 1.7.27 | 1.2.6 | 1.31.1 | 2.8.3 |
| 1.32 | 1.7.27 | 1.2.6 | 1.32.0 | 2.8.3 |
| **1.33** | **2.0.4** | 1.2.6 | 1.33.0 | 2.8.3 |
| **1.34+** | **2.1.1** | 1.2.6 | 1.33.0 | 2.8.3 |

> K8s 1.33 起默认使用 containerd 2.x（[GKE](https://cloud.google.com/kubernetes-engine/docs/deprecations/migrate-containerd-2) 和 [ACK](https://help.aliyun.com/en/ack/product-overview/introduction-to-containerd-2-1) 均已默认 2.x）。K8s 1.35 将是最后一个支持 containerd 1.x 的版本。

示例：
```bash
# 基本构建
cyctl image build-rootfs --k8s-version v1.35.3

# 使用自定义 mirror 加速二进制下载
cyctl image build-rootfs --k8s-version v1.35.3 \
  --mirror https://my-mirror.company.com

# 构建 ARM64 版本
cyctl image build-rootfs --k8s-version v1.35.3 --arch arm64

# 自定义 tag + 输出目录
cyctl image build-rootfs --k8s-version v1.35.3 \
  --tag myrepo/kubernetes --output-dir /data/images

# 通过 SOCKS5 代理下载
cyctl image build-rootfs --k8s-version v1.35.3 --proxy socks5://127.0.0.1:1080

# 禁用缓存（强制重新下载）
cyctl image build-rootfs --k8s-version v1.35.3 --no-cache

# 使用容器镜像 mirror 加速预取
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers

# 跳过容器镜像预取（仅打包二进制，不含 K8s 系统镜像）
cyctl image build-rootfs --k8s-version v1.35.3 --no-prefetch-images

# 添加额外容器镜像到 rootfs
cyctl image build-rootfs --k8s-version v1.35.3 \
  --extra-images calico/cni:v3.28.0,calico/node:v3.28.0

# 使用自定义镜像列表文件
cyctl image build-rootfs --k8s-version v1.35.3 --image-list images.txt

# 从 HTTP registry 拉取容器镜像
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=192.168.1.100:5000/google_containers --insecure-registry

# 包含 calico CNI addon（默认版本 v3.32.2）
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico

# 指定 calico 版本（自动匹配 tigera operator 版本）
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico:3.30.0

# 使用自定义 addon 目录
cyctl image build-rootfs --k8s-version v1.35.3 --addon-dir ./my-addon/


# 完整示例：构建包含 calico 的 rootfs
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
  --arch amd64 --output-dir ./out \
  --cache-dir ~/.cycore/cache \
  --addon calico
```

**Addon 机制说明**

addon 是在集群初始化完成后自动 apply 的扩展组件（如 CNI 插件）。支持两种方式：

**方式 1：内置 addon（`--addon`）**

目前内置 `calico` 一个 addon，支持版本指定：

| 用法 | 说明 |
|------|------|
| `--addon calico` | 使用默认版本（v3.32.2） |
| `--addon calico:3.30.0` | 指定 calico 版本 |
| `--addon calico:v3.30.0` | 同上，`v` 前缀可选 |

版本指定时，tigera operator 版本自动从对应版本的 `tigera-operator.yaml` 中提取，无需手动指定。

内置 addon 包含的镜像（以 calico 为例）：

| 镜像 | 说明 |
|------|------|
| `quay.io/tigera/operator` | Tigera Operator（版本自动匹配） |
| `quay.io/calico/typha` | Calico Typha |
| `quay.io/calico/cni` | Calico CNI 插件 |
| `quay.io/calico/node` | Calico 节点 agent |
| `quay.io/calico/kube-controllers` | Calico 控制器 |
| `quay.io/calico/pod2daemon-flexvol` | FlexVolume 驱动 |
| `quay.io/calico/apiserver` | Calico API Server |
| `quay.io/calico/csi` | Calico CSI 驱动 |
| `quay.io/calico/node-driver-registrar` | CSI 节点注册 |

> `--registry-mirror` 对所有镜像（包括 calico）生效。通用模式 `--registry-mirror my-harbor.local` 会将 `quay.io/calico/node:v3.30.0` 替换为 `my-harbor.local/calico/node:v3.30.0`。也可用按源 registry 映射：`--registry-mirror quay.io=quay.mirrors.example.com`。

**方式 2：自定义 addon 目录（`--addon-dir`）**

适用于内置 addon 不满足需求的场景（自定义 CNI、自定义版本组合等）。

目录结构：

```
my-addon/
├── addon.yaml            # 必须：名称、优先级、镜像列表
└── manifests/            # 必须：kubectl apply 的 yaml 文件
    ├── 01-namespace.yaml
    └── 02-deployment.yaml
```

`addon.yaml` 格式：

```yaml
name: my-custom-cni
priority: 20           # 数值越小越先 apply，calico 内置为 10
images:                # 需要预取的容器镜像列表
  - docker.io/myorg/my-cni:v1.0.0
  - docker.io/myorg/my-controller:v1.0.0
```

- `manifests/` 下的文件按文件名排序后依次 `kubectl apply --server-side`
- 文件名以 `.tmpl` 结尾的会先经过 Tera 模板渲染（可用 `registryDomain`、`registryPort` 等变量）
- `images` 中列出的镜像会被 prefetch 打包进 rootfs，部署时离线可用
- 多个 addon（内置 + 自定义）按 priority 排序后依次 apply

## `image build` — 构建集群镜像

```
cyctl image build [OPTIONS] [CONTEXT]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `[CONTEXT]` | 构建上下文目录 | `.` |
| `-t, --tag` | 镜像 tag | — |
| `-f, --file` | 指令文件（Kubefile / Dockerfile） | — |

示例：
```bash
# 从 Kubefile 构建
cyctl image build -t my-app:v1.0 -f Kubefile .

# 默认上下文
cyctl image build -t nginx-cluster:v1.0
```

## `image list` — 列出本地镜像

```bash
# JSON 格式
cyctl image list

# Table 格式
cyctl image list -o table
```

Table 输出示例：
```
REPOSITORY              TAG       IMAGE ID      SIZE
cycore/kubernetes       v1.35.3   sha256:abc1   245MB
nginx                   latest    sha256:def2   142MB
```

## `image pull` / `push`

```bash
# 从 registry 拉取
cyctl image pull cycore/kubernetes:v1.35.3

# 带认证拉取
cyctl image pull --username admin --password xxx myregistry.com/app:v1

# 推送到 HTTPS registry
cyctl image push myregistry.com/app:v1

# 推送到 HTTP registry（如 Harbor HTTP 端口）
cyctl image push 192.168.1.100:5000/cycore/kubernetes:v1.35.3-amd64 --insecure
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `image` | 镜像引用 | 必填 |
| `--insecure` | 允许推送到 HTTP registry | `false` |

> 如果 registry 需要认证，先用 `cyctl image login` 登录。

## 推送 rootfs 镜像到私有仓库

`build-rootfs` 产出的 tar 是 OCI archive，可以 load → tag → push 到任意 OCI 兼容 registry：

```bash
# 1. 构建 rootfs（产出 ./out/kubernetes-v1.35.3-amd64.tar）
cyctl image build-rootfs \
  --k8s-version v1.35.3 \
  --arch amd64 \
  --addon calico \
  --cycore-bin target/x86_64-unknown-linux-musl/release/cyctl \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
  --output-dir ./out

# 2. 加载 tar 到本地 image store
cyctl image load --input ./out/kubernetes-v1.35.3-amd64.tar
# 输出: Loaded: cycore/kubernetes:v1.35.3

# 3. tag 到目标 registry 地址
cyctl image tag cycore/kubernetes:v1.35.3 192.168.1.100:5000/cycore/kubernetes:v1.35.3

# 4. 如果 registry 需要认证，先登录
cyctl image login 192.168.1.100:5000 -u admin -p yourpassword

# 5. 推送（HTTP registry 加 --insecure）
cyctl image push 192.168.1.100:5000/cycore/kubernetes:v1.35.3 --insecure

# 6. 之后其他机器可以直接从 registry 拉取部署
cyctl cluster run 192.168.1.100:5000/cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --registry http://myuser:mypassword@192.168.1.100:5000
```

> `build-rootfs` 默认 tag 为 `cycore/kubernetes:{k8s_version}`，可通过 `--tag` 自定义。
> `image load` 会输出加载的镜像引用名，即为 step 3 中 `image tag` 的源引用。

## 推送 rootfs 镜像到 ghcr.io（公开分发）

GitHub Container Registry (ghcr.io) 适合公开分发 rootfs 镜像，任何人可匿名拉取。

```bash
# 1. 构建 rootfs
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64 --addon calico

# 2. 加载到本地 image store
cyctl image load --input ./kubernetes-v1.35.3-amd64.tar

# 3. tag 到 ghcr.io
cyctl image tag cycore/kubernetes:v1.35.3 ghcr.io/ubiomni/kubernetes:v1.35.3

# 4. 登录 ghcr.io（需要 GitHub Personal Access Token，权限需包含 write:packages）
cyctl image login ghcr.io --username <github-username> --password <ghp_xxx>

# 5. 推送
cyctl image push ghcr.io/ubiomni/kubernetes:v1.35.3
```

**设置为公开访问：**

ghcr.io 新推送的 package 默认为 **Private**，匿名用户无法拉取。需要手动设置为 Public：

1. 打开 https://github.com/orgs/ubiomni/packages/container/kubernetes/settings
2. 找到 Danger Zone → Change visibility → 选择 **Public**

设置一次即可，后续推送新 tag 会自动继承 Public 状态。

**GitHub Personal Access Token 获取方式：**

1. 打开 https://github.com/settings/tokens
2. Generate new token (classic)
3. 勾选 `write:packages` 权限
4. 生成后复制 token（格式为 `ghp_xxxx`）

> ghcr.io 使用 OAuth2 Bearer token 认证，`cyctl image login` 会自动处理 token 交换流程。

## `image save` / `load`

```bash
# 保存到文件
cyctl image save cycore/kubernetes:v1.35.3 --output k8s.tar

# 保存多个镜像
cyctl image save nginx:latest redis:7 --output apps.tar

# 从文件加载
cyctl image load --input k8s.tar
```

## `image tag` / `rm`

```bash
# 添加标签
cyctl image tag cycore/kubernetes:v1.35.3 myrepo/kubernetes:v1.35.3

# 删除镜像
cyctl image rm cycore/kubernetes:v1.35.3

# 删除多个
cyctl image rm nginx:latest redis:7
```

## `image inspect` / `diff`

```bash
# 查看镜像配置（JSON）
cyctl image inspect cycore/kubernetes:v1.35.3

# 查看镜像 layer 变更
cyctl image diff cycore/kubernetes:v1.35.3
```

## `image login` / `logout`

```bash
# 登录 registry
cyctl image login --username admin --password xxx myregistry.com

# 交互式登录（提示输入密码）
cyctl image login --username admin myregistry.com

# 登出
cyctl image logout myregistry.com
```

## `image merge`

将多个镜像合并为一个。

```bash
cyctl image merge -t my-combined:v1 image1:v1 image2:v1
```

## `image manifest` — 多架构清单

```bash
# 创建 manifest list
cyctl image manifest create myapp:v1 myapp:v1-amd64 myapp:v1-arm64

# 添加镜像
cyctl image manifest add myapp:v1 myapp:v1-ppc64le

# 查看 manifest
cyctl image manifest inspect myapp:v1
```

## `image create` / `from` / `mount` / `umount` / `containers`

低级容器操作，用于调试和镜像检查：

```bash
# 创建工作容器
cyctl image create --name debug-ctr cycore/kubernetes:v1.35.3

# 从镜像创建
cyctl image from cycore/kubernetes:v1.35.3

# 挂载容器文件系统
cyctl image mount <container-id>

# 卸载
cyctl image umount <container-id>

# 列出工作容器
cyctl image containers
```
