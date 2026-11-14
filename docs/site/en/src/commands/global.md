# Global Options

All cyctl subcommands inherit the following global options.

## Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-o, --output <FORMAT>` | Output format: `json` or `table` | `json` |
| `-q, --quiet` | Suppress progress messages, only output data and errors | `false` |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CYCORE_OUTPUT` | Default output format (`json` or `table`) |
| `CYCORE_DATA_DIR` | Data directory path |
| `CYCORE_API_URL` | API server URL |
| `CYCORE_TOKEN` | API authentication token |
| `RUST_LOG` | Log level, e.g., `cycore=debug`, `cycore=trace` |

## Examples

```bash
# Use table format output
CYCORE_OUTPUT=table cyctl image list

# Enable debug logging
RUST_LOG=cycore=debug cyctl cluster run ...

# Enable trace logging (most verbose)
RUST_LOG=cycore=trace cyctl cluster run ...

# Only show SSH module logs
RUST_LOG=cycore::ssh=debug cyctl remote exec ...

# Quiet mode (recommended for scripts and AI agents)
cyctl -q cluster status default -o json

# Equivalent long form
cyctl --quiet --output json cluster status default
```

## Output Formats

**JSON** (default) — Machine-readable structured output on stdout. Recommended for programmatic consumption and AI agent integration.

**Table** — Human-readable tabular output. Useful for interactive terminal sessions.

Errors are always output to stderr in JSON format:

```json
{"error": true, "code": 3, "category": "ssh", "message": "ssh: connection refused"}
```

## Exit Codes

| Code | Category | Description |
|------|----------|-------------|
| 0 | — | Success |
| 1 | `other` | General / uncategorized error |
| 2 | `config` | Configuration or argument error |
| 3 | `ssh` | SSH connection error |
| 4 | `oci` | OCI / registry error |
| 5 | `cert` | Certificate error |
| 6 | `runtime` | Runtime error (containerd, kubeadm) |
| 7 | `io` | IO / filesystem error |
