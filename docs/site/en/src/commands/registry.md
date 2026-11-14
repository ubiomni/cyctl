# registry — Registry Management

The `registry` command group manages an embedded OCI-compatible container registry, useful for offline and air-gapped environments.

## registry serve

Start a local OCI registry server.

```
cyctl registry serve [OPTIONS]
```

| Flag | Description | Default |
|------|-------------|---------|
| `--listen` | Listen address | `0.0.0.0:4000` |
| `--data-dir` | Data directory for filesystem storage | -- |
| `--inmem` | Use in-memory storage (for testing) | `false` |

### Examples

```bash
# Start with persistent storage
cyctl registry serve --data-dir /var/lib/registry

# Custom port
cyctl registry serve --listen 0.0.0.0:5443 --data-dir /data/registry

# In-memory mode (testing only, data lost on restart)
cyctl registry serve --inmem
```

---

## registry save

Save images to a local registry directory layout.

```bash
cyctl registry save nginx:latest redis:7 --output /data/offline-registry
```

---

## registry sync

Synchronize all images between two registries.

```bash
cyctl registry sync \
  --source docker.io/library \
  --destination 10.0.0.1:4000/library
```

---

## registry copy

Copy a single image between registries.

```bash
cyctl registry copy \
  docker.io/library/nginx:latest \
  myregistry.com:4000/nginx:latest
```

---

## registry passwd

Set htpasswd authentication for the embedded registry.

```bash
cyctl registry passwd --username admin --password 'SecurePass123'
```
