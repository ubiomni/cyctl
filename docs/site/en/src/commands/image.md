# image — Image Management

The `image` command group manages OCI container images: building deployment rootfs images, pulling, pushing, tagging, and performing standard registry operations.

## image build-rootfs

Build a Kubernetes deployment image with all dependencies (kubeadm, kubelet, kubectl, containerd, runc, crictl, registry) bundled into a single OCI archive. This is the primary way to prepare for offline cluster deployment.

```
cyctl image build-rootfs [OPTIONS] --k8s-version <VERSION>
```

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--k8s-version` | Kubernetes version (required), e.g. `v1.35.3` | -- |
| `--arch` | Target architecture: `amd64` or `arm64` | `amd64` |
| `--cri` | Container runtime | `containerd` |
| `-t, --tag` | Output image tag | `cycore/kubernetes` |
| `--addon` | Built-in addon, supports version pinning (e.g. `calico`, `calico:3.30.0`). Repeatable | -- |
| `--addon-dir` | Custom addon directory (contains `addon.yaml` + `manifests/`). Repeatable | -- |
| `--registry-mirror` | Registry mirror substitution. Without `=`: universal (preserves full path). With `=`: per-source registry (flat path). Repeatable | -- |
| `--mirror` | Binary download mirror URL (replaces scheme+host in download URLs) | -- |
| `--proxy` | Download proxy (`http://` or `socks5://`) | -- |
| `--output-dir` | Output directory | `.` |
| `--cache-dir` | Binary cache directory | `~/.cycore/cache/binaries` |
| `--no-cache` | Disable cache, force re-download | `false` |
| `--no-prefetch-images` | Skip bundling K8s system container images | `false` |
| `--extra-images` | Additional container images to bundle (comma-separated) | -- |
| `--image-list` | Custom image list file (overrides auto-generated list) | -- |
| `--insecure-registry` | Allow pulling container images from HTTP registries | `false` |
| `--cycore-bin` | Bundle a cyctl binary into the rootfs | -- |

**Output:** `./out/kubernetes-v1.35.3-amd64.tar` (OCI archive)

### Examples

```bash
# Basic build
cyctl image build-rootfs --k8s-version v1.35.3

# With Calico CNI addon
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico

# Pinned Calico version
cyctl image build-rootfs --k8s-version v1.35.3 --addon calico:3.30.0

# ARM64 build with proxy
cyctl image build-rootfs --k8s-version v1.35.3 --arch arm64 \
  --proxy socks5://127.0.0.1:1080

# Use registry mirror for container image prefetch
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers

# Full build: addon + mirror + custom output
cyctl image build-rootfs --k8s-version v1.35.3 \
  --arch amd64 \
  --addon calico \
  --registry-mirror registry.k8s.io=registry.cn-hangzhou.aliyuncs.com/google_containers \
  --cycore-bin target/x86_64-unknown-linux-musl/release/cyctl \
  --output-dir ./out

# Skip image prefetch (binaries only, no system images)
cyctl image build-rootfs --k8s-version v1.35.3 --no-prefetch-images

# Bundle extra application images
cyctl image build-rootfs --k8s-version v1.35.3 \
  --extra-images calico/cni:v3.28.0,calico/node:v3.28.0

# Pull from HTTP registry
cyctl image build-rootfs --k8s-version v1.35.3 \
  --registry-mirror registry.k8s.io=192.168.1.100:5000/google_containers \
  --insecure-registry
```

### Addon Mechanism

Addons are extension components (such as CNI plugins) that are automatically applied via `kubectl apply` after cluster initialization.

**Built-in addons** are specified with `--addon`:

| Usage | Description |
|-------|-------------|
| `--addon calico` | Use default version (v3.32.2) |
| `--addon calico:3.30.0` | Pin a specific Calico version |
| `--addon calico:v3.30.0` | Same as above; the `v` prefix is optional |

When a version is specified, the corresponding tigera-operator version is automatically extracted from the upstream manifest.

The `--registry-mirror` flag applies to all images including addon images.

**Custom addons** are specified with `--addon-dir` and use this directory structure:

```
my-addon/
  addon.yaml            # Required: name, priority, images list
  manifests/            # Required: YAML files for kubectl apply
    01-namespace.yaml
    02-deployment.yaml
```

`addon.yaml` format:

```yaml
name: my-custom-cni
priority: 20           # Lower values apply first; built-in calico uses 10
images:                # Container images to prefetch
  - docker.io/myorg/my-cni:v1.0.0
  - docker.io/myorg/my-controller:v1.0.0
```

- Files in `manifests/` are applied in filename order via `kubectl apply --server-side`
- Files ending in `.tmpl` are rendered through the Tera template engine before applying
- Multiple addons (built-in + custom) are applied in priority order (lowest first)

### Component Version Mapping

cyctl automatically selects compatible component versions based on the Kubernetes version:

| K8s Version | containerd | runc | crictl | registry |
|-------------|-----------|------|--------|----------|
| <= 1.28 | 1.7.27 | 1.1.14 | 1.28.0 | 2.8.3 |
| 1.29 | 1.7.27 | 1.1.14 | 1.29.0 | 2.8.3 |
| 1.30 | 1.7.27 | 1.1.14 | 1.30.1 | 2.8.3 |
| 1.31 | 1.7.27 | 1.2.6 | 1.31.1 | 2.8.3 |
| 1.32 | 1.7.27 | 1.2.6 | 1.32.0 | 2.8.3 |
| **1.33** | **2.0.4** | 1.2.6 | 1.33.0 | 2.8.3 |
| **1.34+** | **2.1.1** | 1.2.6 | 1.33.0 | 2.8.3 |

Starting with K8s 1.33, containerd 2.x is used by default. K8s 1.35 will be the last version to support containerd 1.x.

---

## image list

List locally stored images.

```bash
# JSON output (default)
cyctl image list

# Human-readable table
cyctl image list -o table
```

Table output example:

```
REPOSITORY              TAG       IMAGE ID      SIZE
cycore/kubernetes       v1.35.3   sha256:abc1   245MB
nginx                   latest    sha256:def2   142MB
```

## image pull

Pull an image from a registry.

```bash
cyctl image pull cycore/kubernetes:v1.35.3

# With authentication
cyctl image pull --username admin --password xxx myregistry.com/app:v1
```

## image push

Push an image to a registry.

```bash
# Push to HTTPS registry
cyctl image push myregistry.com/app:v1

# Push to HTTP registry
cyctl image push 192.168.1.100:5000/myimage:latest --insecure
```

| Flag | Description | Default |
|------|-------------|---------|
| `--insecure` | Allow pushing to HTTP registries | `false` |

If the registry requires authentication, log in first with `cyctl image login`.

## image tag

Add a tag to an existing image.

```bash
cyctl image tag cycore/kubernetes:v1.35.3 myrepo/kubernetes:v1.35.3
```

## image rm

Remove local images.

```bash
cyctl image rm cycore/kubernetes:v1.35.3

# Remove multiple images
cyctl image rm nginx:latest redis:7
```

## image save

Export images to an OCI archive file.

```bash
cyctl image save cycore/kubernetes:v1.35.3 --output k8s.tar

# Save multiple images
cyctl image save nginx:latest redis:7 --output apps.tar
```

## image load

Import images from an OCI archive file.

```bash
cyctl image load --input k8s.tar
```

## Pushing Rootfs Images to a Private Registry

The rootfs tar produced by `build-rootfs` is an OCI archive. You can load, tag, and push it to any OCI-compatible registry:

```bash
# 1. Build rootfs
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64 --addon calico \
  --output-dir ./out

# 2. Load tar into local image store
cyctl image load --input ./out/kubernetes-v1.35.3-amd64.tar

# 3. Tag for destination registry
cyctl image tag cycore/kubernetes:v1.35.3 192.168.1.100:5000/cycore/kubernetes:v1.35.3

# 4. Log in to the registry (if authentication is required)
cyctl image login 192.168.1.100:5000 -u admin -p yourpassword

# 5. Push (add --insecure for HTTP registries)
cyctl image push 192.168.1.100:5000/cycore/kubernetes:v1.35.3 --insecure

# 6. Deploy from registry on other machines
cyctl cluster run 192.168.1.100:5000/cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --registry http://admin:pass@192.168.1.100:5000
```

## image login / logout

Manage registry credentials.

```bash
# Log in to a registry
cyctl image login --username admin --password xxx myregistry.com

# Interactive login (prompts for password)
cyctl image login --username admin myregistry.com

# Log out
cyctl image logout myregistry.com
```

## image build

Build a cluster image from a Kubefile (Dockerfile-like format).

```
cyctl image build [OPTIONS] [CONTEXT]
```

| Flag | Description | Default |
|------|-------------|---------|
| `[CONTEXT]` | Build context directory | `.` |
| `-t, --tag` | Image tag | -- |
| `-f, --file` | Instruction file (Kubefile / Dockerfile) | -- |

```bash
# Build from Kubefile
cyctl image build -t my-app:v1.0 -f Kubefile .

# Default context
cyctl image build -t nginx-cluster:v1.0
```

## image inspect / diff

Inspect image metadata and layer changes.

```bash
# View image configuration (JSON)
cyctl image inspect cycore/kubernetes:v1.35.3

# View image layer changes
cyctl image diff cycore/kubernetes:v1.35.3
```

## image merge

Merge multiple images into one.

```bash
cyctl image merge -t my-combined:v1 image1:v1 image2:v1
```

## image manifest

Manage multi-architecture manifest lists.

```bash
# Create manifest list
cyctl image manifest create myapp:v1 myapp:v1-amd64 myapp:v1-arm64

# Add an image to a manifest list
cyctl image manifest add myapp:v1 myapp:v1-ppc64le

# Inspect manifest
cyctl image manifest inspect myapp:v1
```
