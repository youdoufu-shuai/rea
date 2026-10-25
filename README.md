# REA 上手与调研资料包

> **这不是 REA 的官方仓库，也不是它的源码镜像。**
> 这是一份**第三方整理的资料包**：把 REA 的安装/接入路径、MCP 调用契约，
> 以及一份独立调研报告整理成能直接照着做的东西。
>
> REA 本体的所有权利属于 [morluto/rea](https://github.com/morluto/rea)（MIT）。

---

## REA 是什么

**Reverse Engineer Anything** —— 让 agent 做逆向工程，从应用行为一路下到原生二进制。

| | |
|---|---|
| 官方仓库 | [github.com/morluto/rea](https://github.com/morluto/rea) |
| 官网 / 文档 | [rea.tools](https://rea.tools) |
| 许可 | MIT |
| 形态 | MCP server（本地 stdio）+ CLI + agent skills |
| 安装 | `npx rea-agents setup` |

它不是一个独立的 GUI 工具，而是一个**挂在 agent 后面的能力层**：
你照常用 Claude Code / Codex / Cursor / DeepSeek Harness 这些客户端，
REA 通过 MCP 给它加一批逆向工具（列符号、反编译、读内存、抓包、分析页面…）。

### 它解决什么问题

平常让 agent 逆向会遇到三个断层：

1. **看不到二进制内部** —— agent 只能读源码，遇到 exe/so/dylib 就断。
   REA 把 Ghidra / Hopper / IDA 这些引擎接成 MCP 工具。
2. **证据留不住** —— agent 说「这里有个校验」，你没法复现。
   REA 的返回值带 Evidence（地址、字节、摘要），可以回查。
3. **一跳就丢上下文** —— 从反编译看到网络请求，再想抓包就断开。
   REA 用统一的会话/证据模型把各层串起来。

---

## 快速开始

### 1. 安装（挑一种）

```bash
# 自动探测并配置你机器上的 agent 客户端
npx rea-agents@latest setup
```

setup 会先给出**变更预览**（要改哪些配置文件、装哪些东西），你批准后才写入。
它不会静默改你的配置。

```powershell
# Windows 上也可以用本仓库的脚本（会先检查 node 版本再调官方 setup）
.\scripts\install-rea.ps1
```

```bash
# macOS / Linux
./scripts/install-rea.sh
```

### 2. 重启客户端

setup 完成后会告诉你需要重启哪些客户端。重启它们，REA 的 MCP 工具就出现了。

### 3. 验证

在客户端里让它列一下可用工具，或者直接跑一个只读任务，比如：

> 「用 REA 看看这个 exe 的导入表，告诉我它依赖哪些系统库」

---

## 仓库内容

```
docs/
  01-REA-逆向一切-详细调研报告.md      ← 独立调研：定位、能力边界、生态、争议
  02-REA-技术调研-MCP工具与引擎矩阵.md  ← 技术向：工具清单、分层、逐目标引擎矩阵
  setup.md                            ← 安装与接入指南（含各客户端配置方式）
  mcp-quickstart.md                   ← MCP 调用速查：会话、Evidence、超时、取消
  upstream/                           ← 官方文档的离线副本（MIT，见该目录 README）
scripts/
  install-rea.ps1                     ← Windows 安装脚本
  install-rea.sh                      ← macOS / Linux 安装脚本
mcp-config/
  dsh.json                            ← DeepSeek Harness 配置片段
  claude-code.json                    ← Claude Code 配置片段
  generic.json                        ← 任意支持 mcpServers 的客户端
```

---

## 支持的客户端

REA 的 setup 能自动配置这些（`--client` 值供非交互使用）：

`claude_code` · `claude_desktop` · `codex` · `cursor` · `gemini_cli` ·
`windsurf` · `devin` · `opencode` · `antigravity` · `copilot_cli` ·
`commandcode` · `qwen_code` · `vscode` · `grok_build` · `omp` · `pi` ·
`hermes` · `qoder` · `trae` · `zcode` · `dsh`

> `dsh`（DeepSeek Harness）目前在 main 分支可用，尚未进入正式 release。
> 装之前先看 [docs/setup.md](docs/setup.md) 里的说明。

## 分析引擎

| 引擎 | 说明 |
|---|---|
| **Ghidra** | 免费，跨平台。REA 可直接使用已安装的 Ghidra，或提示安装 |
| **Hopper** | macOS 上体验最好。REA 可检测已有安装或提示安装 |
| **IDA** | 需要自备 IDA + provider，见官方 `ida-provider.md` |

三个都用不到也能跑：REA 有一部分工具不依赖反汇编引擎（打包分析、页面观察、进程抓取等）。

---

## 许可与归属

| 内容 | 归属 | 许可 |
|---|---|---|
| `docs/upstream/` 下的官方文档副本 | morluto / REA 项目 | **MIT**（原文见该目录 `LICENSE-morluto-rea`） |
| 其余文档、脚本、配置 | 本仓库维护者 | MIT（见 [LICENSE](LICENSE)） |

- 本仓库与 REA 项目**没有隶属关系**，不代表官方立场。
- 调研报告中引用的第三方数据、媒体文章，版权归各自作者。
- MIT 允许再分发，但**必须保留版权声明** —— 所以 `docs/upstream/` 里带着上游许可证原文。

---

## 相关链接

- 官方仓库：[morluto/rea](https://github.com/morluto/rea)
- 官方文档：[rea.tools](https://rea.tools)
- MCP Registry：`io.github.morluto/rea`
- MCP 协议规范：[modelcontextprotocol.io](https://modelcontextprotocol.io)
