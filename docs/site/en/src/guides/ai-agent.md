# AI Agent Integration

cyctl is designed with AI agent integration as a first-class concern. All commands produce structured output, use distinct exit codes, and support a quiet mode that cleanly separates data from progress messages.

## JSON Output Mode

All commands default to JSON output (`-o json`), making it straightforward to parse results programmatically.

```bash
# Get cluster status as JSON
result=$(cyctl -q cluster status default -o json 2>/dev/null)
phase=$(echo "$result" | jq -r '.phase')
masters=$(echo "$result" | jq -r '.masters | length')
echo "Cluster phase: $phase, master count: $masters"
```

For human-readable output, use `-o table`:

```bash
cyctl cluster status default -o table
```

You can also set the default output format via environment variable:

```bash
export CYCORE_OUTPUT=json
```

## Structured Errors and Exit Codes

Errors are written to stderr in JSON format:

```json
{"error": true, "code": 3, "category": "ssh", "message": "ssh: connection refused"}
```

Each exit code maps to a specific error category:

| Exit Code | Category | Description | Common Causes |
|-----------|----------|-------------|---------------|
| 0 | — | Success | — |
| 1 | `other` | Generic error | Uncategorized errors |
| 2 | `config` | Configuration error | Invalid arguments, YAML parse failure, invalid Clusterfile |
| 3 | `ssh` | SSH connection error | Wrong password, host unreachable, wrong port |
| 4 | `oci` | OCI/Registry error | Image not found, authentication failure, registry unreachable |
| 5 | `cert` | Certificate error | Certificate generation failure, expired certificate |
| 6 | `runtime` | Runtime error | containerd start failure, kubeadm failure |
| 7 | `io` | IO error | Disk full, permission denied, file not found |

### Error Handling Example (Python)

```python
import subprocess
import json
import sys

result = subprocess.run(
    ["cyctl", "-q", "cluster", "status", "default", "-o", "json"],
    capture_output=True, text=True
)

if result.returncode == 0:
    status = json.loads(result.stdout)
    print(f"Cluster {status['name']} phase: {status['phase']}")
else:
    error = json.loads(result.stderr)
    category = error["category"]
    message = error["message"]

    if result.returncode == 3:  # SSH error
        print(f"SSH connection failed: {message}")
        # Retry or check network connectivity
    elif result.returncode == 2:  # Config error
        print(f"Invalid configuration: {message}")
    else:
        print(f"Error [{category}]: {message}")
        sys.exit(result.returncode)
```

## Quiet Mode

The `-q` (or `--quiet`) flag suppresses all progress messages that would otherwise go to stderr. Only structured data output (stdout) and error JSON (stderr) remain. This is critical for agents because it prevents human-readable progress text from mixing with machine-readable JSON.

```bash
# Recommended mode for agents
cyctl -q -o json cluster status default

# Equivalent long form
cyctl --quiet --output json cluster status default
```

## Discovering Commands and Options

If your agent needs to dynamically explore available commands and flags:

```bash
# List all subcommands
cyctl --help 2>&1 | grep '^  [a-z]'

# Get flags for a specific subcommand
cyctl cluster run --help 2>&1
```

## Complete Integration Example

```python
#!/usr/bin/env python3
"""cyctl agent integration example."""

import subprocess
import json


class CycoreClient:
    def __init__(self):
        self.base_cmd = ["cyctl", "-q", "-o", "json"]

    def _run(self, args):
        result = subprocess.run(
            self.base_cmd + args,
            capture_output=True, text=True
        )
        if result.returncode != 0:
            error = json.loads(result.stderr)
            raise CycoreError(
                code=result.returncode,
                category=error["category"],
                message=error["message"]
            )
        return json.loads(result.stdout) if result.stdout.strip() else None

    def cluster_status(self, name="default"):
        return self._run(["cluster", "status", name])

    def cluster_run(self, images, masters, nodes="", passwd=None, pk=None):
        args = ["cluster", "run", "--masters", masters, "--nodes", nodes]
        if passwd:
            args += ["--passwd", passwd]
        if pk:
            args += ["--pk", pk]
        args += images
        return self._run(args)

    def node_add(self, nodes, passwd=None):
        args = ["node", "add", "--nodes", nodes]
        if passwd:
            args += ["--passwd", passwd]
        return self._run(args)

    def remote_exec(self, command, masters="", nodes="", role="all", passwd=None):
        args = ["remote", "exec"]
        if masters:
            args += ["--masters", masters]
        if nodes:
            args += ["--nodes", nodes]
        if passwd:
            args += ["--passwd", passwd]
        args += ["--role", role, "--", command]
        return self._run(args)

    def image_list(self):
        return self._run(["image", "list"])

    def version(self):
        return self._run(["version"])


class CycoreError(Exception):
    def __init__(self, code, category, message):
        self.code = code
        self.category = category
        self.message = message
        super().__init__(f"[{category}/{code}] {message}")


# Usage
if __name__ == "__main__":
    client = CycoreClient()

    # Check version
    ver = client.version()
    print(f"cyctl {ver['version']} (commit: {ver['commit']})")

    # Check cluster status
    try:
        status = client.cluster_status()
        print(f"Cluster: {status['name']}, Phase: {status['phase']}")
        print(f"Masters: {len(status['masters'])}, Workers: {len(status['workers'])}")
    except CycoreError as e:
        if e.code == 2:
            print("Cluster does not exist, starting deployment...")
            client.cluster_run(
                images=["cycore/kubernetes:v1.35.3"],
                masters="10.0.0.1,10.0.0.2,10.0.0.3",
                nodes="10.0.0.11,10.0.0.12",
                passwd="YourSecurePassword"
            )
```
