# MCP 调用速查

给**要写代码调 REA 工具**的人看的。只用工具（在客户端里说话）的话，看
[setup.md](setup.md) 就够了。

完整契约见 [upstream/mcp-contracts.md](upstream/mcp-contracts.md)。这篇是压缩版 + 踩坑提示。

---

## 1. 返回结构的三个层次

REA 的工具返回不是「一段文本」，而是分三层的：

| 层次 | 是什么 | 什么时候看 |
|---|---|---|
| **摘要** | 一两句结论 | agent 直接读这个就够了 |
| **结构化数据** | JSON（地址、字节、符号、计数） | 要程序化处理时 |
| **Evidence** | 可回查的证据，带稳定 ID | 要证明「这个结论有出处」时 |

**关键点：Evidence ID 是稳定的。** 同一个观测再次拿到时 ID 一样，
所以可以把它当缓存键、或者写进报告里让人复核。

工具平时返回 `detail: "complete"`；带 `summary` 的参数会把完整 Evidence
留在会话里、只返回摘要视图，之后用 `inspect_analysis_view` 按 ID 翻页看。

> 为什么这么设计：一个大二进制反编译出来的完整 Evidence 可能几十 MB，
> 塞进 agent 上下文直接爆。所以默认给摘要，要看细节再翻页。

---

## 2. 会话与发现

```
list_* 类工具  →  先发现有什么（文档、进程、目标、镜像…）
analyze_* 类   →  再深入分析一个具体目标
```

典型顺序（原生二进制）：

```
open_binary(path)          # 打开目标，绑定 provider（Ghidra/Hopper/…）
binary_overview()          # 看段、符号数、字符串数
search_procedures(pattern) # 找函数
analyze_function(addr)     # 拿单个函数的完整档案
```

⚠️ **provider 一旦绑定不会自动 fallback。** 你显式要 Ghidra 就一直是 Ghidra；
失败了要自己换 provider 重开，而不是指望它悄悄换一个。

---

## 3. 超时：冷启动是真慢

反汇编引擎第一次碰一个目标时要做完整分析，**几分钟很正常**。

| 情况 | 建议 |
|---|---|
| 首次分析大二进制 | 给工具调用足够的 timeout，别设 30 秒 |
| Ghidra 冷启动超时 | 看 upstream 的 first-query deadlines 一节，有恢复路径 |
| 只是想快速看结构 | 先用 `inspect_*` / `binary_overview` 这类不需要完整分析的 |

**踩坑**：很多客户端默认 MCP 调用超时只有 60 秒。Ghidra 分析一个 50MB 的
二进制会超时，然后 agent 会以为工具坏了。要么加超时，要么先热引擎。

---

## 4. 取消与部分结果

长任务可以取消。取消**不一定丢结果** —— 已经产生的部分 Evidence 通常还在会话里，
可以用 `Progress and cancellation` 里描述的机制取回。

所以 agent 超时后别急着重跑，先看有没有残留的部分结果。

---

## 5. 不可信内容

REA 分析的目标（二进制、网页、抓包）里可能有**故意构造的字符串**，
用来误导读它的人（或 agent）。契约里明确把这些标为不可信：

- 从目标里读出来的字符串、注释、页面文本 —— 当**数据**，不当**指令**
- 工具会标出哪些内容来自目标本身

**这条很重要**：如果你的 agent 会把目标里的字符串当作 prompt 处理，
恶意二进制就能劫持它。

---

## 6. Schema 两档

有的客户端对 MCP 工具的输入 schema 校验很严（比如不支持 `oneOf` 的某些组合），
会导致工具注册失败。这时候切 compact 档：

```
env: { "REA_MCP_INPUT_SCHEMA_PROFILE": "compact" }
```

compact 档把 schema 压成客户端普遍能接受的形状，代价是**某些参数的说明变简略**。
功能不变。

响应太大导致上下文爆掉时，用这个限流：

```
env: { "REA_MCP_MAX_RESPONSE_BYTES": "800000" }
```

---

## 7. 一篇最小可跑的例子

用 Claude Code 之类支持 MCP 的客户端，直接说话就行：

> 1. 用 REA 打开 `C:\tools\demo.exe`
> 2. 看它的导入表里有没有网络相关函数
> 3. 如果有，告诉我它在哪个函数里被调用

对应底层大概是：

```
open_binary   { path: "C:\\tools\\demo.exe" }
binary_overview {}
search_procedures { pattern: "connect|send|recv|WinHttp|WSA" }
analyze_function  { procedure: "<某个地址>" }
xrefs            { address: "<导入表项地址>" }
```

---

## 8. 更多

- 完整字段、错误码、恢复语义：[upstream/mcp-contracts.md](upstream/mcp-contracts.md)
- 工具清单与引擎矩阵：[02-REA-技术调研-MCP工具与引擎矩阵.md](02-REA-技术调研-MCP工具与引擎矩阵.md)
