# AI Agent 集成指南

cyctl 设计时充分考虑了 AI Agent 的集成需求。以下是推荐的集成模式。

## JSON 输出模式

所有命令默认输出 JSON 格式（`-o json`），便于程序解析：

```bash
# Agent 获取集群状态
result=$(cyctl -q cluster status default -o json 2>/dev/null)
phase=$(echo "$result" | jq -r '.phase')
masters=$(echo "$result" | jq -r '.masters | length')
echo "集群状态: $phase, master 数量: $masters"
```

## 结构化错误 + Exit Code

错误输出到 stderr，格式为 JSON：

```json
{"error": true, "code": 3, "category": "ssh", "message": "ssh: connection refused"}
```

Exit Code 对照表：

| Exit Code | 类别 | 说明 | 常见原因 |
|-----------|------|------|---------|
| 0 | — | 成功 | — |
| 1 | `other` | 通用错误 | 未归类的错误 |
| 2 | `config` | 配置错误 | 参数错误、YAML 解析失败、Clusterfile 无效 |
| 3 | `ssh` | SSH 连接错误 | 密码错误、目标不可达、端口错误 |
| 4 | `oci` | OCI/Registry 错误 | 镜像不存在、认证失败、registry 不可达 |
| 5 | `cert` | 证书错误 | 证书生成失败、证书过期 |
| 6 | `runtime` | 运行时错误 | containerd 启动失败、kubeadm 失败 |
| 7 | `io` | IO 错误 | 磁盘满、权限不足、文件不存在 |

Agent 错误处理示例（Python）：

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
    print(f"集群 {status['name']} 状态: {status['phase']}")
else:
    error = json.loads(result.stderr)
    category = error["category"]
    message = error["message"]

    if result.returncode == 3:  # SSH 错误
        print(f"SSH 连接失败: {message}")
        # 可尝试重试或检查网络
    elif result.returncode == 2:  # 配置错误
        print(f"配置无效: {message}")
    else:
        print(f"错误 [{category}]: {message}")
        sys.exit(result.returncode)
```

## --quiet 模式

`-q` 或 `--quiet` 会抑制所有进度消息（输出到 stderr），只保留数据输出（stdout）和错误（stderr JSON）。这对 Agent 来说非常重要，因为它避免了混合人类可读的进度文本和机器可读的 JSON 数据。

```bash
# Agent 推荐模式
cyctl -q -o json cluster status default

# 等价于
cyctl --quiet --output json cluster status default
```

## Shell 补全

如果 Agent 需要动态探测可用命令和参数：

```bash
# 获取所有子命令
cyctl --help 2>&1 | grep '^  [a-z]'

# 获取特定子命令的参数
cyctl cluster run --help 2>&1
```

## 完整 Agent 集成示例

```python
#!/usr/bin/env python3
"""cyctl Agent integration example"""

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


# 使用示例
if __name__ == "__main__":
    client = CycoreClient()

    # 检查版本
    ver = client.version()
    print(f"cyctl {ver['version']} (commit: {ver['commit']})")

    # 检查集群状态
    try:
        status = client.cluster_status()
        print(f"集群: {status['name']}, 状态: {status['phase']}")
        print(f"Masters: {len(status['masters'])}, Workers: {len(status['workers'])}")
    except CycoreError as e:
        if e.code == 2:
            print("集群不存在，开始部署...")
            client.cluster_run(
                images=["cycore/kubernetes:v1.35.3"],
                masters="10.0.0.1,10.0.0.2,10.0.0.3",
                nodes="10.0.0.11,10.0.0.12",
                passwd="xxx"
            )
```
