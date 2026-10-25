# 配置片段

把对应文件里的 `mcpServers` 整块合并到你客户端的配置文件里，重启客户端。

| 文件 | 给谁 |
|---|---|
| `generic.json` | 任意支持 `mcpServers` 的客户端 |
| `claude-code.json` | Claude Code（`~/.claude.json` 或项目 `.mcp.json`） |
| `dsh.json` | DeepSeek Harness（注意：`dsh` 目前仅 main 分支支持） |

## 两条硬规则

1. **版本要钉死。** 例子里写的是 `rea-agents@6.4.0`，不要用 `@latest`。
   自动升级会让工具签名变化，agent 之前学会的调用方式可能失效。

2. **命令用 `npx`，别写绝对路径。** 写死 `C:\...\node.exe` 或
   `/usr/local/bin/npx` 的配置在换机器/换 node 版本后就会失效。

## 可选环境变量

| 变量 | 作用 |
|---|---|
| `REA_MCP_MAX_RESPONSE_BYTES` | 限制单次响应字节数，防止大响应撑爆 agent 上下文 |
| `REA_MCP_INPUT_SCHEMA_PROFILE` | 设成 `compact` 可兼容 schema 校验严格的客户端 |

## 更省事的做法

不想手写就用官方 setup，它会自动探测客户端并生成正确的注册条目：

```bash
npx rea-agents@latest setup
```
