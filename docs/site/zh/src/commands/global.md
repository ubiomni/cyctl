# 全局选项

所有子命令继承以下全局选项：

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-o, --output <FORMAT>` | 输出格式：`json` 或 `table` | `json` |
| `-q, --quiet` | 静默模式，只输出数据和错误，不输出进度消息 | `false` |

## 环境变量

| 变量 | 说明 |
|------|------|
| `CYCORE_OUTPUT` | 默认输出格式，值为 `json` 或 `table` |
| `CYCORE_DATA_DIR` | 数据目录 |
| `RUST_LOG` | 日志级别，如 `cycore=debug`, `cycore=trace` |

示例：
```bash
# 使用 table 格式输出
CYCORE_OUTPUT=table cyctl image list

# 开启 debug 日志
RUST_LOG=cycore=debug cyctl cluster run ...

# 静默模式（适合脚本/Agent）
cyctl -q cluster status default -o json
```
