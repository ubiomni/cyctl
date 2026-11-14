# Private Registry Configuration

This guide covers how to configure cyctl to work with private container registries, including HTTPS registries with self-signed certificates and HTTP registries.

## HTTPS Private Registry

When your private registry uses HTTPS (even with self-signed certificates), cyctl automatically configures containerd with `skip_verify = true` on all nodes:

```bash
cyctl cluster run myregistry.com:4000/kubernetes:v1.35.3 \
  -m 10.0.0.1 -p YourPassword
```

No additional configuration is needed for HTTPS registries.

## HTTP Private Registry

HTTP registries require extra containerd configuration. There are four methods, listed from most to least recommended.

### Method 1: Deploy-Time Configuration (Recommended)

Use the `--registry` flag during `cluster run` to automatically configure all nodes:

```bash
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.11 -p YourPassword \
  --registry http://192.168.1.100:30077
```

For a registry that requires authentication:

```bash
cyctl cluster run ./kubernetes-v1.35.3-amd64.tar \
  -m 10.0.0.1 -n 10.0.0.11 -k ~/.ssh/id_rsa \
  --registry http://myuser:mypassword@192.168.1.100:30077
```

This creates the appropriate `/etc/containerd/certs.d/` configuration on all nodes automatically.

### Method 2: Post-Deploy Manual Configuration

If the cluster is already deployed, configure each node manually:

```bash
cyctl remote exec -c default -p YourPassword --role all -- '
mkdir -p /etc/containerd/certs.d/192.168.1.100:30077

cat > /etc/containerd/certs.d/192.168.1.100:30077/hosts.toml << EOF
server = "http://192.168.1.100:30077"

[host."http://192.168.1.100:30077"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
'
```

containerd detects changes to the `certs.d` directory automatically -- no restart required.

### Method 3: CRI Shim Auto-Rewrite

The cri-shim intercepts all image pull requests and rewrites them to point to your local registry:

```yaml
# /etc/cycore/cri-shim.yaml
address: /var/run/cycore-cri-shim.sock
force: true
image: 192.168.1.100:30077
```

```bash
# Start cri-shim on each node
cyctl ctl cri-shim --config /etc/cycore/cri-shim.yaml
```

### Method 4: Edit containerd config.toml

For full control, edit `/etc/containerd/config.toml` on each node:

```toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
```

Then create the appropriate `hosts.toml` file as shown in Method 2.

## Registry Authentication

### hosts.toml with Authorization Header

Add a Basic Auth header to the `hosts.toml` configuration:

```toml
server = "http://192.168.1.100:30077"

[host."http://192.168.1.100:30077"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true

  [host."http://192.168.1.100:30077".header]
    Authorization = ["Basic dXNlcjpwYXNzd29yZA=="]
```

Generate the base64 credential string:

```bash
echo -n 'user:password' | base64
```

### Kubernetes ImagePullSecret

Create a docker-registry secret and reference it in pod specs:

```bash
kubectl create secret docker-registry my-registry-cred \
  --docker-server=http://192.168.1.100:30077 \
  --docker-username=admin \
  --docker-password='YourPassword' \
  --docker-email=admin@example.com
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
      image: 192.168.1.100:30077/myproject/myapp:v1.0
```

### cyctl Image Login

Use `cyctl image login` to store credentials for push/pull operations:

```bash
cyctl image login -u admin -p YourPassword 192.168.1.100:30077
```

## Complete Example

End-to-end workflow: deploy a cluster with an HTTP registry and configure authentication.

```bash
# 1. Deploy cluster with HTTP registry (recommended approach)
cyctl cluster run cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1,10.0.0.2,10.0.0.3 \
  -n 10.0.0.11,10.0.0.12 \
  -p YourPassword \
  --registry http://192.168.1.100:30077

# 2. If the registry requires authentication, configure all nodes
cyctl remote exec -c default -p YourPassword --role all -- '
mkdir -p /etc/containerd/certs.d/192.168.1.100:30077
cat > /etc/containerd/certs.d/192.168.1.100:30077/hosts.toml << INNER_EOF
server = "http://192.168.1.100:30077"

[host."http://192.168.1.100:30077"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true

  [host."http://192.168.1.100:30077".header]
    Authorization = ["Basic $(echo -n admin:YourPassword | base64)"]
INNER_EOF
'

# 3. Create a Kubernetes ImagePullSecret
cyctl remote exec -m 10.0.0.1 -p YourPassword -- '
kubectl create secret docker-registry private-reg \
  --docker-server=http://192.168.1.100:30077 \
  --docker-username=admin \
  --docker-password=YourPassword
'

# 4. Test pulling an image
cyctl remote exec -m 10.0.0.1 -p YourPassword -- '
crictl pull 192.168.1.100:30077/myproject/myapp:v1.0
'
```

## Pushing Rootfs Images to a Private Registry

The rootfs tar produced by `build-rootfs` is an OCI archive. You can load, tag, and push it to any OCI-compatible registry:

```bash
# 1. Build rootfs
cyctl image build-rootfs --k8s-version v1.35.3 --arch amd64 --addon calico

# 2. Load into local image store
cyctl image load --input ./out/kubernetes-v1.35.3-amd64.tar

# 3. Tag for target registry
cyctl image tag cycore/kubernetes:v1.35.3 192.168.1.100:30077/cycore/kubernetes:v1.35.3

# 4. Log in to the registry
cyctl image login 192.168.1.100:30077 -u admin -p YourPassword

# 5. Push (add --insecure for HTTP registries)
cyctl image push 192.168.1.100:30077/cycore/kubernetes:v1.35.3 --insecure

# 6. Other machines can now pull and deploy directly from the registry
cyctl cluster run 192.168.1.100:30077/cycore/kubernetes:v1.35.3 \
  -m 10.0.0.1 -n 10.0.0.2,10.0.0.17 \
  -k ~/.ssh/id_rsa \
  --registry http://admin:YourPassword@192.168.1.100:30077
```
