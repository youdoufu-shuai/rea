# 安装与接入指南

本文是**照着做就能跑通**的最小路径。官方完整说明见 [upstream/installation.md](upstream/installation.md)，
或者直接看 [rea.tools](https://rea.tools)。

---

## 0. 前置条件

| 要求 | 说明 |
|---|---|
| Node.js | 建议 20 LTS 或更高。`npx` 随 npm 一起装好 |
| 网络 | 首次运行要从 npm 拉包；国内网络可能需要代理 |
| 一个 agent 客户端 | Claude Code / Codex / Cursor / DeepSeek Harness / VS Code 等 |

验证环境：

```bash
node -v      # 期望 v20.x 或更高
npx -v
```

---

## 1. 一条命令装好

```bash
npx rea-agents@latest setup
```

这条命令做的事情**不是**直接写文件，而是：

1. 扫描你机器上装了哪些受支持的 agent
2. 给你一个多选列表（已注册过 REA 的默认勾上，新检测到的**不自动勾**）
3. 生成一份变更计划：要改哪个配置文件、要装什么外部软件、要联网到哪些域名
4. **等你批准**之后才真的写入

所以第一次跑会看到一堆提问，这是设计如此，不是卡住了。

### 非交互用法

CI 或脚本里想跳过选择：

```bash
npx rea-agents@latest setup --client claude_code    # 指定单个客户端
npx rea-agents@latest setup --client codex,cursor   # 指定多个
npx rea-agents@latest setup --client dsh --skill=false   # 不装 skill，只要 MCP
```

> ⚠️ `--yes` 只批准**下载 npm 包**，不批准 REA 的配置变更。两者是分开的。

### 关于版本

- `npx rea-agents setup` —— 用 npm 选中的版本
- `npx rea-agents@latest setup` —— 显式要最新版
- 想回滚：`npx rea-agents@6.4.0 setup`（换回具体版本号，再跑一次 setup）

已注册的 MCP 条目会被**钉死到具体版本**（不是 `@latest`），
这是为了防止某天自动升级后工具签名变了导致 agent 行为漂移。

---

## 2. 重启客户端

setup 结束时会告诉你需要重启哪些客户端。重启后 REA 的 MCP 工具才会出现。

---

## 3. 手动配置（不想用 setup 时）

任何支持 `mcpServers` 的客户端都可以手写。把版本号换成你要用的：

```json
{
  "mcpServers": {
    "rea": {
      "command": "npx",
      "args": ["-y", "rea-agents@6.4.0", "mcp"]
    }
  }
}
```

本仓库 `mcp-config/` 下有三份现成的片段：

| 文件 | 给谁用 |
|---|---|
| `generic.json` | 任意支持 `mcpServers` 的客户端 |
| `claude-code.json` | Claude Code |
| `dsh.json` | DeepSeek Harness |

### 环境变量

注册条目里可以带这些开关（写进 `env` 字段）：

| 变量 | 作用 |
|---|---|
| `REA_MCP_INPUT_SCHEMA_PROFILE` | 输入 schema 的兼容档位（客户端 schema 校验太严时用） |
| `REA_MCP_MAX_RESPONSE_BYTES` | 单次返回最大字节数，防止大响应把 agent 上下文撑爆 |

---

## 4. 各客户端的特殊情况

### DeepSeek Harness（`dsh`）

REA 支持 `dsh`，但**目前只在 main 分支可用**，还没进正式 release。

所以有两种做法：

1. 等 release（推荐，稳）
2. 从 main 装：`npx rea-agents@main setup --client dsh`
   —— 用到未发布代码，出问题自己承担

`dsh` 还需要 Cordis patch 和 launcher 的配合，官方说明见
`upstream/installation.md` 里的 DeepSeek Harness 一节。

### Claude Desktop

改完 `claude_desktop_config.json` 必须**完全退出** Claude Desktop 再打开，
只关窗口不算退出（macOS 上要从菜单栏 Quit）。

### VS Code / Copilot

VS Code 的 MCP 支持需要较新版本，并且要在设置里启用。
如果工具列表不出现，先确认 VS Code 版本，再看 `mcp-config/generic.json` 手写。

---

## 5. 诊断与维护

```bash
npx rea-agents doctor       # 体检：配置、路径、依赖、版本
npx rea-agents setup        # 重跑 setup 可以修复或升级注册
```

卸载：先 `npx rea-agents setup` 里取消勾选所有客户端，或者手删配置里的 `rea` 条目。
setup / 卸载都会保留 `.rea.backup` 快照，不会把你原来的配置搞丢。

---

## 6. 常见问题

**Q：`npx` 卡住不动？**
多半在拉包。加代理：
```bash
# PowerShell
$env:HTTPS_PROXY="http://127.0.0.1:7897"; npx rea-agents@latest setup
# bash
HTTPS_PROXY=http://127.0.0.1:7897 npx rea-agents@latest setup
```

**Q：工具出现了，但一调用就超时？**
反汇编引擎冷启动很慢（Ghidra 首次分析一个大型二进制可能要几分钟）。
先跑一个小的只读任务，把引擎热起来。官方对首次查询有专门的超时与恢复机制，
见 `upstream/mcp-contracts.md` 里的 first-query deadlines。

**Q：需要装 Ghidra 吗？**
不装也能用一部分工具（打包分析、页面观察、进程抓取等）。
要反编译才需要 Ghidra / Hopper / IDA 其中之一。

**Q：MCP 工具列表里没有 REA？**
1. 确认客户端重启过（不是刷新窗口）
2. `npx rea-agents doctor` 看注册状态
3. 检查配置里 `command` 是 `npx` 而不是某个绝对路径（换机器会失效）

---

## 参考

- 官方安装说明：[docs/upstream/installation.md](upstream/installation.md)
- MCP 调用契约：[docs/upstream/mcp-contracts.md](upstream/mcp-contracts.md)
- 官方站点：[rea.tools](https://rea.tools)
