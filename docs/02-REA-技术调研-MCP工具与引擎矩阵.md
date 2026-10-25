# REA（Reverse Engineer Anything）技术调研：MCP 工具、架构分层与逐目标引擎矩阵

> 核验时间：2026-10-13。**一手来源**：GitHub REST API（`api.github.com`）与仓库 `/contents` 接口返回的 base64 原文（已本地解码）。
> **抓取限制声明**：本沙箱的 PowerShell/curl 无法建立 TLS（`schannel: SEC_E_NO_CREDENTIALS`），`raw.githubusercontent.com` 与 `github.com/morluto/rea/blob/...` 均不可达；`https://rea.tools` 返回 `unsupported content type "unknown"`。因此**所有官方内容均通过 `api.github.com` 抓取并本地解码**，可用来源 URL 见文末。

---

## 1. 仓库 README 原文要点（已成功解码）

README 由 `https://api.github.com/repos/morluto/rea/readme` 返回（`size: 20692`，`sha c4a89bc`），base64 解码成功。核心内容：

- 标题与定位：**"REA: Reverse Engineer Anything —— One MCP for reverse engineering across binaries, applications, and runtime behavior."** 副标语：*"See a feature you like. Understand how it works, down to the binary level."*
- 一句话工作流：`npx rea-agents setup`；支持 **Claude Code、Codex、Cursor、Gemini CLI、Grok Build 等**；原生分析可复用已有的 **Hopper / Ghidra / IDA**，setup 可在获批后安装 Hopper；**静态 JavaScript 与 .NET 检查不需要任何原生分析引擎**。
- "How REA works"：Agent 通过 MCP 调工具 → REA 本地检查并追踪代码 → 返回**带证据的发现** → Agent 据此解释行为或实现/测试。CLI 走同一套 workflow。**分析全程本地运行**（FAQ：REA 不上传目标；但工具结果会交给你的模型供应商，适用其数据政策）。
- Showcases 三例（详见 §5）。多语言 README 共 17 个（`README_zh.md`、`README_ja.md`…）；Star 徽章文案为 **"170,000 GitHub stars — thank you!"**（仓库本体，与实际星数有滞后）。
- License：MIT（第三方组件保留自有许可，见 `THIRD_PARTY_NOTICES.md`）；法律声明指向 `DISCLAIMER.md`，强调须合法取得并授权使用 IDA Pro / Hex-Rays、Hopper、JEB 等商业工具，**REA 不授予任何工具许可或激活权益**。

仓库元数据（`api.github.com/repos/morluto/rea`）：`created_at 2026-04-14`，`language TypeScript`，`license MIT`，`default_branch main`，`homepage https://rea.tools`，topics 含 `mcp / model-context-protocol / ghidra / hopper / decompiler / binary-analysis / agent-skills / dsh / dsh-plugin`（本报告取数时刻：约 189,654 stars / 46,095 forks / 573 open issues）。

## 2. 官方文档抓取结果（逐文件）

| 文件 | 抓取方式 | 结果 |
|---|---|---|
| `README.md` | `/readme` API + base64 解码 | ✅ 全文 |
| `docs/installation.md` | `/contents` API + 解码 | ✅ 全文 49,105 字符（已存 `rea-research/installation.md`） |
| `docs/migration-6.2.md` | `/contents` API + 解码 | ✅ 全文 8,536 字节 |
| `docs/web-network-captures.md` | `/contents` API + 解码 | ✅ 全文 28,783 字节 |
| `SECURITY.md` | `/contents` API + 解码 | ✅ 全文 3,120 字节 |
| `docs/mcp-contracts.md` | `/contents` API + 解码 | ✅ 全文 43,179 字符（已存 `rea-research/mcp-contracts.md`） |
| `CHANGELOG.md` | `/contents` 元数据 | ⚠️ **仅有元数据**：`size 305770`（约 306 KB）。未逐字抓取；版本历史改用**官方 Release Notes**（权威且更精炼）。 |
| `docs/public/product-catalog.json` | `/contents` API | ❌ 404（该 JSON 不在仓库内，见 §3.2） |

### 2.1 `SECURITY.md`（官方原文要点）
- **支持策略**：只为**最新已发布版本**提供安全修复；报告前先升级。
- **报告渠道**：使用仓库 **Security** 标签页私密提交；**不要**开公开 issue、不要在公开处披露凭据/私有二进制/Hopper 文档/Ghidra 工程。报告须含版本、OS/发行版、所选用 provider 及版本、影响、复现条件与缓解建议，并**从日志中移除凭据、专有二进制、socket capability token 与无关本地路径**。
- **安全边界**：Hopper 与 Ghidra 的 bridge 用**每会话随机 capability token** 认证；POSIX 用**当前用户专属 Unix socket**，Windows Ghidra 用**已认证回环 TCP** + 私有 NTFS runtime（DACL 仅允许当前用户与 SYSTEM）；token 经**私有会话描述符**而非进程参数或环境变量传递。
- **明确否认沙箱能力**：*"This is not a sandbox and does not protect against malicious processes already running as the same operating-system user."* 打开不可信二进制 = 以你的用户权限解析它。
- **Ghidra**：使用随包 `HeadlessScript`、临时隔离工程与私有 home/cache/runtime，仅导入被请求的目标，限制启动与协议消息、CPU 与堆；**不打开、不修改用户自有 Ghidra 工程**。
- **Linux 安装 Hopper**：只从 Hopper 的 HTTPS 端点取发布元数据，包 URL 限定为 Hopper 公开下载源，限制包体大小，并在请求安装前比对 Hopper 公布的校验和；官方明示 **SHA-1 只是损坏校验而非现代包签名**，HTTPS 来源校验仍是信任边界的一部分。依赖安装委托给 `apt-get`/`dnf`/`pacman`（直接以 root 或经 `pkexec`），**REA 从不调用 `sudo`**。

## 3. MCP 工具与架构分层

### 3.1 三层架构（官方仓库判定）
1. **MCP server（本地 stdio）**——注册形态：`{"mcpServers":{"rea":{"command":"npx","args":["-y","rea-agents@6.4.0","mcp"]}}}`，**持久注册必须钉死精确版本**（`rea setup` 会 pin 到执行 setup 的那个版本；经 Bun 安装时写 `bunx rea-agents@<version> mcp`；Windows 额外用 `cmd.exe /d /c` 包装）。已发布到官方 **MCP Registry**，条目名 `io.github.morluto/rea`（不引入第二分发产物）。
2. **Skill（工作流指令，非引擎）**——随 setup 装到各客户端 personal skill 目录；无客户端时落到 `~/.agents/skills`。仓库内为 `.agents/skills/reverse-engineer-anything/SKILL.md`（18,732 字节）+ `references/{native-and-artifacts.md(15,988), javascript-applications.md(9,949), connection-and-recovery.md(8,814), evidence-workflows.md(4,058), runtime-observation.md(2,727), android-applications.md(1,992)}`。可用 skill 路由单独安装：`npx skills add morluto/rea --skill reverse-engineer-anything`（**只装指令，不装 MCP 注册与分析引擎**）。
3. **CLI（`rea`）**——与 MCP 共享同一 workflow 契约，可脱离 Agent 使用（`rea doctor`、`rea analyze-javascript-application`、`rea inspect-web-network-capture`、`rea update/uninstall` 等）；`stream canonical JSON` 输出、`--json` 自动化、stdout 专供结构化结果（交互 UI 走 stderr）。

**引擎桥接实现**（仓库 `bridge/` 目录，可交叉印证分层）：`bridge/hopper_bridge.py`(51,679 B)、`bridge/ghidra/ReaGhidraBridge.java`(**212,194 B**)、`bridge/ghidra/ReaGhidraApplySeeds.java`、`ReaGhidraMipsSoftFloat.java`、`ReaGhidraNoReturnFix.java`、`bridge/android/ReaJadxBridge.java`(14,655 B)、`bridge/mitmproxy/capture.py`(11,108 B)。

### 3.2 工具清单（从 `docs/mcp-contracts.md` 等官方文件逐名提取）
> ⚠️ **完整性说明**：README 的 "MCP tool catalog" 徽章指向 `docs/mcp-contracts.md#generated-catalog`，但该节只说明目录由 `npm run docs:generate` 生成到 `docs/public/product-catalog.json`，并托管在 `/rea/product-catalog.json`——**这是构建期生成物，仓库中不存在（API 返回 404），且 `rea.tools` 域名在本沙箱不可解析读取**。因此官方完整工具目录**未能获取**。下表是官方文档正文中**逐字出现**的工具名（非推测）。

- **会话与身份**：`binary_session`（报告活动包/服务器/SDK/协商特性，含 `result.tool_availability` 与 effect 记录）、`open_binary`（选择并校验 target/provider 绑定，**不等待** import 与自动分析）、`close_binary`（排空自有任务、关闭 provider、清空会话记录；可能返回 `cleanup_incomplete`）。
- **原生分析**：`binary_overview`、`analyze_function`（产出的 Evidence 可直接喂给 `compare_functions`）、`compare_functions`、`get_call_graph`（按遍历深度组织的 `graph` + `limitations`，空调用表+未知覆盖 ≠ 无调用）、`trace_call_path`（受限展开进 `residual_unknowns`，`goal_status` 可为 `unknown`/`not_reached`）。
- **聚合上下文**：`get_navigation_context`（当前文档/地址/所属过程）、`inspect_address_context`（须显式地址；name / procedure / comment / inline-comment / bookmark 各 facet）、`current_document`、`current_address`、`current_procedure`。
- **工件与布局**：`inspect_artifact`（Evidence → `compare_artifacts`）、`inventory_artifact`（原子清单 Evidence）、`extract_artifact`（支持 `--integrity-policy record-and-continue`）、`inspect_binary_layout`、`inspect_wasm_artifact`、`inspect_macho`。
- **JavaScript / Electron**：`analyze_javascript_application`（也接受 `--integrity-policy`；产出 `integrity_contradictions` 并把图覆盖标为 partial）、`trace_application_feature`、`trace_javascript_semantics`、`compare_application_versions`、`compare_source_to_bundle`、`compare_javascript_export_shapes`。
- **Web / 浏览器 / 抓包**：`inspect_web_network_capture`、`inspect_web_page`、`discover_webmcp_tools`、`capture_browser_scenario`、`capture_process_scenario`、`compare_web_captures`。
- **移动端 / 托管代码 / 其它**：`inspect_adb_client`、`inspect_apktool_client`、`project_managed_application_graph`。
- **证据与会话治理**：`inspect_analysis_view`（原生/JS/WASM/Mach-O/HAR 的**分页视图**；含 `api-surface` 派生 API 视图）、`export_evidence_bundle`、`get_evidence_bundle`（`detail:"summary"` 只列 Evidence ID/摘要）、`list_unknowns`、`record_unknown`、`update_unknown`。
- **重构验证**：`build_reconstruction_obligation_ledger`、`evaluate_reconstruction_coverage`。

### 3.3 证据模型（这是 REA 与"薄封装"的分水岭）
产物型工具把**完整规范 Evidence 记录**直接放进 `structuredContent` 与 JSON 文本：读 `structuredContent.normalized_result` 取结果、`.evidence_id` 取身份；**6.1 的 `{result, evidence_id, evidence}` 包装层已被删除**（见 §6）。每条记录强制带 `analysis_profile`（具体对象或 `null`）并参与语义身份；`raw_result` 保存 provider 原始表示（无则为 `null`）。工具失败返回 `isError: true` 且**省略 `structuredContent`**，诊断以 JSON 放在 text `content` 中。结果超出 MCP 传输预算时返回 `resource_constraint`（`details.resource:"transport"`），并给出 `details.reported_limits.evidence_reference` 供 `inspect_analysis_view` / `export_evidence_bundle` 续取；服务端默认以钉死的 **10 MiB** stdio 接收缓冲为预算，可用 `REA_MCP_MAX_RESPONSE_BYTES`（≥1,048,576）调大；Kimi/Moonshot 等限制 schema 体积的客户端可设 `REA_MCP_INPUT_SCHEMA_PROFILE=compact`（输入 schema 压到 13,312 字节内，运行时校验仍是完整版）。
**提示注入防护**：字符串、符号、反编译代码、页面文本、脚本、抓包、日志、文件清单**一律视为不可信数据**；带目标内容的工具结果在 `_meta` 携带 `{"provenance":{"untrusted_content":true,"source":"analysis_target"}}`，并明确指示 Agent **绝不执行工具结果里的指令**，而应报告为注入尝试。
**超时归属**：Hopper 启动默认 120,000 ms（`REA_HOPPER_STARTUP_TIMEOUT_MS`），Ghidra 启动默认 **330,000 ms**（`REA_GHIDRA_STARTUP_TIMEOUT_MS`，上限 2,147,483,647）；客户端 SDK 2.3.1 默认单次请求 60,000 ms 且可能早于 provider 截止时间取消，需自行设 `timeout`/`resetTimeoutOnProgress`/`maxTotalTimeout`。官方实测：Windows x64 + Ghidra 12.1.4 + JDK 21 冷启动 overview 约 163 s，热调用约 19 ms。

## 4. 逐目标引擎 / 返回内容 / 前置依赖矩阵

以下为 README "What you can analyze" 表格的完整还原（官方原文），并补充文档中确认的引擎细节：

| 分析目标 | REA 返回什么 | 前置依赖 |
|---|---|---|
| **原生二进制** | 伪代码、汇编、字符串、符号、调用与交叉引用 | Hopper / Ghidra / IDA；[native 指南](https://rea.tools/guides/native/) |
| **离线 ELF 布局** | 节、段、原始符号/重定位、静态缓解（mitigation）候选 | 调用方自备 **pwntools**，**Linux x64**；`docs/binary-diagnostics.md` |
| **Go 二进制** | 内嵌编译器版本、模块、replace、构建设置 | **内置**静态 ELF/PE/Thin Mach-O 检查，**无需安装 Go** |
| **WASM 产物** | 校验、节、精确 import/export WAT 形式与解码后 WAT | 调用方自备 **WABT 1.0.42**；`inspect_wasm_artifact` |
| **EVM 字节码** | 分发选择器、字节偏移、推断参数与可变性（mutability） | 本地 raw/hex carrier，**Linux x64**（EVMole）；`docs/evm-bytecode.md` |
| **SQLite 数据库** | 表、列、索引、视图、触发器与选定普通表行 | 本地库/WAL 快照；Node.js **24.x ≥24.15 或 26+**（原生 SQLite 限制） |
| **Linux 崩溃记录** | 原始 notes、每个记录线程的寄存器/信号、可选映射候选 | 调用方自备 pwntools（Linux x64）；可选 GDB/pwndbg；`docs/recorded-crashes.md` |
| **JavaScript / Electron** | 模块、import、source map、路由、IPC 与原生插件关系 | 仅需 **Node.js + npm**；[JS 指南](https://rea.tools/guides/javascript/) |
| **网站** | 页面结构、脚本、网络观测、按需截图 | **Chrome 系浏览器**；[browser 指南](https://rea.tools/guides/browser/) |
| **已保存的网络抓包** | 请求、响应、暴露的载荷与源位置 | **HAR** 或 **Fiddler Everywhere SAZ**；mitmproxy 需 **Linux 上的 mitmdump**；`docs/web-network-captures.md` |
| **.NET 程序集** | 元数据、CIL 指令、声明的原生依赖与构建对比 | **无**（纯静态托管代码分析）；`docs/managed-code-analysis.md` |
| **Android APK** | 清单声明、类、反编译方法、引用 | **headless JADX + 完整 JDK**（Linux/macOS/Windows x64）；`docs/android-analysis.md` |
| **Android 设备** | 设备、包、进程、日志、dump、截屏、APK/文件传输 | 调用方自备 **adb**（模拟器或真机）；`docs/adb-device-analysis.md` |
| **JEB 工程** | 引擎驱动的工程单元、工件摘要、类型/方法伪代码 | 调用方启动的本地 **JEB MCP server**，用 `REA_JEB_MCP_URL` 选定；`docs/jeb-analysis.md` |
| **Android 资源** | 解码后的清单、字符串表、locale、版本事实 | 调用方自备 **Apktool** launcher；`docs/apktool-resource-analysis.md` |
| **Flutter 应用** | Dart 快照哈希、逐 ABI 的库摘要、引擎构建来源 | **无**（纯静态 APK 解析）；`docs/flutter-analysis.md` |
| **固件** | 区域、提取结果、原生分析交接 | **Binwalk / Unblob，Linux**；`docs/firmware-analysis.md`（v5.0 起接受已核验的 Binwalk 与 Unblob 发布线） |
| **抓包（数据包）** | 选定字段、重复值、过滤器与 decode-as 规则 | Linux：**TShark 4.x + prlimit**；`docs/packet-captures.md` |
| **数据包摘要** | 端点、DNS、TLS SNI、协议分布与 HTTP 请求 | 调用方自备 **tshark + capinfos**（仅 Linux 验证）；`docs/pcap-analysis.md` |
| **逻辑信号记录** | 解码器注解、采样区间与诊断 | Linux：**sigrok-cli 0.7.2 + prlimit**；`docs/signal-recordings.md` |
| **包与资源** | 文件清单、摘要、plist、Apple bundle 解剖与提取资源 | `docs/javascript-artifact-reconstruction.md`、`docs/apple-application-analysis.md` |
| **进程行为** | 终端输出、交互、退出与文件系统观测、运行对比 | **Linux/macOS + 原生 PTY**；`docs/process-capture.md` |

补充要点（来自 `installation.md` 与 `mcp-contracts.md`）：
- **静态 JavaScript 与 .NET 不需要原生引擎**；原生深分析走 Hopper / Ghidra / IDA 之一。`--provider ghidra` / `provider_id:"ghidra"` / `REA_ANALYSIS_PROVIDER=ghidra` 三选一；一个会话只含**一个**导入的 Program。**Windows Ghidra 是实验性 P0 且只读**；Ghidra 需**完整 JDK（非 JRE）**，核验版本 12.1.4；`REA_GHIDRA_LANGUAGE_ID` / `REA_GHIDRA_COMPILER_SPEC_ID` 可覆盖语言，`REA_GHIDRA_SEED_FILE` 可在自动分析前种入 function/code/label，`REA_GHIDRA_DISABLED_ANALYZERS` 可跳过指定分析器（如 `Objective-C Message Analyzer`），堆内存取 `GHIDRA_HEADLESS_MAXMEM` → `GHIDRA_MAXMEM` → `2G` 优先级，Linux/macOS 固定 `-XX:ParallelGCThreads=2 -XX:CICompilerCount=2`。
- **Hopper 是独立商业软件**（免费 demo 有厂商限制），**没有 Windows 版**；Linux 上需要 PWN/X 会话（无头主机可能要 Xvfb）。支持的原生主机基线：**macOS 12+、Ubuntu 24.04+、Fedora 41+、Nobara 44+、64 位 Arch Linux、CachyOS、Omarchy**。大二进制可调 `REA_GHIDRA_STARTUP_TIMEOUT_MS` / `REA_HOPPER_STARTUP_TIMEOUT_MS`。
- **网页抓包 adapter 的硬约束**：只支持 **HAR 1.2** profile；依赖 `har-schema@2.0.0`(draft-06)、`ajv@8.20.0`、`ajv-formats@3.0.1`、`jsonc-parser@3.3.1`、`lossless-json@4.3.1`（npm lockfile 钉死）。mitmproxy 原生解码要求 **调用方提供的 mitmdump 12.2.3 且仅限 Linux**（上游 tag `v12.2.3`，commit `6c09d56`），REA **不安装 mitmproxy**，只跑 `--no-server` 私有配置目录；非 Linux 原生解码不支持。SAZ 走 Fiddler Everywhere 的 ZIP 布局，按文件名配对 `raw/<id>_c.txt`、`_s.txt`、`_m.xml`，展开上限 32 MiB。资源预算：**输入 32 MiB、decoder reply 96 MiB、嵌套 64 层**；HAR/SAZ/qlog 跑在自有 **192 MiB** Node old-gen 堆 + 1 个 V8 worker；mitmproxy 额外套 Linux 限制 **768 MiB 地址空间 / 30 s CPU / 96 MiB 文件输出**，两者都有 **30 s wall deadline**；超预算返回 `resource_constraint` 且**不给部分成功**。敏感值可用 MCP `sensitive_values` 或 CLI 重复 `--sensitive-value` 声明，声明本身不入库，只记数量。
- **`api-surface` 派生视图**：把请求行按 method + WHATWG origin + 路径模板分组，`{numeric}`/`{uuid}`/`{hex}`/`{iso-date}` 四类规则按表序套用（如 `/a/%2e%2e/admin` 与 `/admin` 保持区分），每组回指父记录序号并标记混合状态/内容类型；**官方明确它不做 handler 身份、schema 或因果性主张**。

## 5. 官方 showcase 案例细节

| 案例 | 官方描述（README 原文要点） | 链接 |
|---|---|---|
| **DX-Ball：重建一个声像（sound-pan）计算** | 沿一次声音调用追到它的 position-to-pan helper，检查指令，把**不完整伪代码**还原成 C。重建版本通过 **3,205 个原始 x86 用例**，并**逐字节复现全部 63 个编译后函数字节** | [案例](https://rea.tools/showcase/dx-ball/)、[重建仓库 N0zoM1z0/dx-ball](https://github.com/N0zoM1z0/dx-ball) |
| **Notion：追踪 Electron 剪贴板桥** | 定位渲染进程的剪贴板 API，沿 **preload → IPC → 主进程** 追下去，并检查富文本剪贴板格式 | [案例](https://rea.tools/showcase/notion/) |
| **TH04：恢复一个 DOS 弹幕环计算** | 检查原始 PC-98 游戏的 **16 位指令**，恢复固定角与瞄准角两套计算，并把重建的 C++ 与**历史编译器输出**对比 | [案例](https://rea.tools/showcase/th04/)、[重建仓库 N0zoM1z0/th04](https://github.com/N0zoM1z0/th04) |

相关背景（官方 Release Notes 可印证时间线）：DX-Ball 案例于 **5.0.0（2026-10-07）** 引入网站（`docs: add DX-Ball reconstruction showcase`、`website: introduce REA and the DX-Ball reconstruction`）；Notion 与 TH04 案例同在 **5.0.0**（`website: add Notion case study and improve onboarding`、`website: add TH04 bullet-ring case study`）；**6.2.0** 增加 Aegis APK 代码生成 showcase 与 Android showcase。

## 6. 版本迭代历史（日期均取官方 Release API）

| 版本 | 发布日期（UTC） | 要点 | 破坏性变更 |
|---|---|---|---|
| **3.2.0** | **2026-10-03** | `native: add investigation features`；移除分析结果上限/固定配额、artifact 清单并入 inspection、`inventory` 包装层去重、MCP 工具输入与内联结果简化、去掉 readiness 工具 | Release Notes 未列 BREAKING 段，但大量工具契约被重构 |
| **4.0.0** | **2026-10-05** | Ghidra **DOS MZ 分析** + 完整函数范围；原生 inspection 原语、dispatch trace 与"经批准的 UI 观测"；setup 扩展 agent 集成并校验更新 | ⚠️ **移除受控重放（controlled replay）、Node characterization、finite replay-machine、managed runtime planning 与冗余 string-tracing 工具**；**移除权限配置与 policy 命令、approval 字段、filesystem scope 输入与固定确认选项**；进程捕获改为继承宿主环境并接受命令名；无作用域 setup 只刷新 REA 自有注册（需 `--all-detected` 才配所有探测到的客户端） |
| **5.0.0** | **2026-10-07** | 浏览器：关联网络内容与生命周期证据、追踪网站 module import 与 source-map 位置、归因原生执行/监听来源；JS：**Wakaru 恢复可读模块**；原生：chained fixups / binds / ObjC categories 与 properties、打开 iOS 风格与 iOS-on-Mac 包装 bundle、Apple bundle 解剖入图；web：导出抓到的脚本供 JS 分析；Android + Apple inventory graph 工具；网站加入 DX-Ball / Notion / TH04 案例 | ⚠️ 原生**保留不完整的 UI 捕获**语义变更；**Android 分析要求完整 JDK 17+ 且含 compiler 模块** |
| **6.0.0** | **2026-10-08** | 浏览器：检查**历史 web 网络抓包**；EVM：经 **EVMole** 检查离线字节码接口；Ghidra：**Windows 原生 x86 PE** 支持；原生：经 **pwntools 检查离线 ELF 布局**与**记录崩溃**、在 LLDB 下观测函数与 ObjC 方法调用；Mach-O dylib 解析追踪；dotnet 元数据/CIL 边界校验 | ⚠️ **MCP 文件系统输入一律要求绝对宿主路径**（如 `open_binary({"path":"./app"})` 必须改传 `/home/analyst/app` 或 `C:\analysis\app`）；CLI 相对路径仍可用 |
| **6.1.0** | **2026-10-09** | 注册 **Grok Build / Grok Bot**；Ghidra 启动截止时间可配置；网站加 GitHub 实时星数 | ⚠️ **Hopper 正则改为 ECMAScript Unicode 语法**（不再是 Python `re`），在可取消 worker 中执行、5 秒截止；**移除 `set_current_document`**，改用 `open_binary` 切换目标，document 参数绑定到活动目标 |
| **6.2.0** | **2026-10-09** | JS 观测导出属性存在性；MCP 支持选择已保留分析结果的**视图**；大量网站内容（Aegis APK、Android showcase、入门示例） | ⚠️ **见下方专节（6.2 breaking change）** |
| **6.3.0** | **2026-10-09** | 延续 6.2 的契约与目录重构 | ⚠️ **历史抓包若缺少当前 producer 记账或事务身份、web diff 缺少可访问性或存储维度，将被拒绝**；需保留原始抓包并用当前版本重新捕获 |
| **6.4.0** | **2026-10-11** | **Android 设备检查、split-APK 获取、日志、截屏、文件传输与显式应用生命周期动作（经 ADB）**，并用 Apktool 解码清单与本地化字符串；**JEB**：经调用方启动的本地 JEB MCP server 浏览工程单元并反编译；大分析：**无需加载全部载荷即可发现保留的 Evidence**，经摘要与选定视图检查 JS 图/二进制布局/函数档案；JS 分析隔离到自有进程并可配堆与超时；Ghidra 可配置导入语言/编译器规格与种子函数、代码、标签；RPC 发现支持 tRPC、HTTP-link URL 与命名 GraphQL 操作；新增 **Pi / Hermes / Qwen Code** setup；`REA_MCP_INPUT_SCHEMA_PROFILE=compact` | ⚠️ WebSocket 结果改用 `network.websocket_connections`（删 `network.websocket_events`，**无遗留别名**）；直接资源 API 需传调用方自有的 `ArtifactResourceScope`；保存的引用图排除项需带匹配 `pattern` 且区分 `project-ignored` / `default-ignored`；终端捕获缓冲上限 1,000,000 单元格（`columns × (rows + scrollback)`）；语义图 schema 去掉 `identifier_strategy`；工件图边改从 `occurrence_id` 选中的 occurrence 读子工件 ID/路径 |

### 6.2 的 breaking change（官方 `docs/migration-6.2.md` 专文）
仓库采用 **`always-bump-minor` 策略——minor 号递增不代表向后兼容**。6.2 的核心变化：
1. **MCP 结果结构**：证据型工具**直接**在 `structuredContent` 与 JSON 文本中返回完整 Evidence；**旧的 `{ result, evidence_id, evidence }` 包装层消失**。迁移：`const evidence = reply.structuredContent; const value = evidence.normalized_result; const evidenceId = evidence.evidence_id;`。
2. **`analysis_profile` 成为必填字段**（具体对象或 `null`）且参与 Evidence 身份；**缺失该字段的旧记录无法通过插入 `null` 迁移**——必须保留原始文件并用 6.2 重新生成观测。
3. **`binary_session` 移除顶层 `provider` / `providers` 别名**，改读 `analysis_provider_binding` / `analysis_provider_candidates` 与逐操作 `capabilities`；provider 通过 `open_binary.provider_id` 或 CLI `--provider` 选择。
4. **快照（snapshot）**：要求 `workflow_entries` 且每个缓存查询都有 profile 绑定的 Evidence 记录；导入时直接拒绝不完整绑定，而不是静默丢弃；不兼容时保留旧快照并用新路径重跑（示例 `rea analyze <path> --provider ghidra --snapshot <path>-6.2.json`）。
5. **工件清单**：kind/format/executable 等路径相关角色与权限**移到 occurrence**（`nodes[].kind` → `occurrences[].artifact_kind` 等），需重新生成旧清单。
6. **进程捕获**：**不再转换 legacy v3 捕获**，必须显式提供选中/启动的可执行身份与 `event_journal`；旧捕获只能作历史参考。
7. **清理与评估**：一次性分析可能返回 `cleanup_incomplete` 而非静默成功；成功率不等于清理成功。
8. **JS 与函数比较**：return-field 投影要求显式 `presence`（`present`/`absent`/`unknown-coverage`），语义对象操作保留完整 `properties.property_path` 段；函数比较维度状态改为 `unchanged`/`changed`/`unknown`，**移除不可达的 `truncated` 状态与 `summary.truncated` 计数**。
9. **历史源码符号链接**：`target_state` 为 `unreadable`/`unknown` 时**必须** `target: null`（不能用 `<outside-root>` 之类展示占位符当查询数据）。

## 7. 安装与使用最短路径

- **运行要求**：**Node.js 22.x（≥22.19）、24.x（≥24.11）或 26+**，随附 npm；**Node 23、25 与预发布版明确不支持**；REA 使用该运行时自带的 npm，**从不自行升级 Node.js、npm 或 Homebrew**（Bun 全局更新需 **Bun ≥1.2.17**）。
- **最短三步**：
  1. `npx rea-agents setup`（选客户端 → 审阅改动 → 批准；npm 包下载批准与 REA 的 setup 批准是**两次独立批准**）→ 2. 重启被点名的 Agent → 3. 对 Agent 说：*"Understand how search works in the Notes app, show me the evidence, and build a similar feature for my project."*
- **常用变体**：`npx rea-agents@latest setup`；`rea setup --client codex --client cursor --skill=false --dry-run`；`rea setup --yes --all-detected --install-hopper --json`；`npm install --global rea-agents` 后 `rea --help` / `rea doctor --json` / `rea update` / `rea uninstall [--purge-data]`；`curl -fsSL https://raw.githubusercontent.com/morluto/rea/main/install.sh | bash`（可选 curl 包装，支持 `--version`、`--dry-run`、`--no-setup`、`--no-prompt`、`--verbose`）；无 Agent 时静态 JS 可直跑 `npx -y rea-agents@latest analyze-javascript-application /abs/path/to/app --json`。
- **官方支持的客户端（`--client` 值，共 22 项）**：`claude_code`、`claude_desktop`、`codex`、`cursor`、`gemini_cli`、`windsurf`、`devin`、`opencode`、`antigravity`、`copilot_cli`、`commandcode`、`qwen_code`、`vscode`、`grok_build`、`omp`、`pi`、`hermes`、`qoder`、`trae`、`zcode`、**`dsh`（DeepSeek Harness）**。
  - 官方注明：**`dsh` 目前只在 main 上，尚未进入 npm 6.4.0**；对 `@latest` 执行 `rea setup --client dsh` 会报 unsupported client，直到含它的版本发布。6.4.0 的注册表包接受 **17 个** client ID 的 dry-run setup 计划（含 Qwen Code、Pi、Hermes）。Codex 与 Grok Build 会额外写入 `startup_timeout_sec = 30`；Grok Bot 走手动托管 connector。

## 8. 抓不到 / 需注意的内容（不编造）

1. **官方完整 MCP 工具目录（product catalog）**：`docs/public/product-catalog.json` 在仓库中不存在（API 404），该文件由 `npm run docs:generate` / `scripts/generate-mcp-tool-catalog.mjs` 构建期生成，官方托管于 `/rea/product-catalog.json`；`rea.tools` 在本沙箱返回 `unsupported content type`，**无法读取**。因此 §3.2 是"官方文档正文中出现的工具名"，**不等于官方声明的全集**。
2. **`CHANGELOG.md` 全文（约 306 KB）**：未逐字抓取；§6 的版本信息改用**官方 Release Notes**（`/releases` 与 `/releases/tags/...`），属一手来源。
3. **`raw.githubusercontent.com` 与 GitHub 网页版**：本沙箱不可达（TLS 与出口限制），故未能核对 `docs/cli.md`、`docs/roadmap.md`、`docs/architecture.mermaid`、`DISCLAIMER.md`、`THIRD_PARTY_NOTICES.md`、`AGENTS.md` 的正文。
4. **第三方说法（与官方区分）**：Apidog 博客（2026-10-13）称"10-12 突破 11.5 万星 / 2.5 万 fork"、把版本节奏概括为"3.2→10/3、4.0→10/5、5.0→10/7、6.0→10/8、6.1–6.4 于 10/9–10/11"，并给出星数曲线（10/4 1,373、10/7 5,602、10/9 19,375、10/10 26,572、10/11 31,255）。**其中 3.2.0(10-03)、4.0.0(10-05)、5.0.0(10-07)、6.0.0(10-08)、6.1.0(10-09)、6.2.0(10-03 至 10-09 间, UTC 10-09)、6.4.0(10-11) 已由官方 Release API 逐条核实**；星数曲线与"115K stars"为**第三方数据，未由本报告独立验证**（本报告实测该时刻仓库为约 18.97 万星，与第三方数字差距很大，说明媒体数字存在明显滞后或口径差异）。
5. 第三方独立站 `unstone.github.io/dsh-xray` 把 `morluto/rea` 列为 **C2 级 DSH 插件能力卡**，标注能力面：执行系统命令（`exec`）、解码 base64、启动网络服务（`net_server`）、读取凭据类环境变量（`REA_BROWSER_VERIFIER_SECRET`），出站域 `www.hopperapp.com` / `www.npmjs.com` / `rea.tools`——与仓库 topics 中的 `dsh` / `dsh-plugin` 相互印证（**第三方静态分析结论**）。

## 9. 来源 URL 清单

**一手（官方）**
- 仓库元数据：https://api.github.com/repos/morluto/rea
- README：https://api.github.com/repos/morluto/rea/readme ｜ https://github.com/morluto/rea/blob/main/README.md
- 安装：https://api.github.com/repos/morluto/rea/contents/docs/installation.md
- 抓包：https://api.github.com/repos/morluto/rea/contents/docs/web-network-captures.md
- 6.2 迁移：https://api.github.com/repos/morluto/rea/contents/docs/migration-6.2.md
- 安全：https://api.github.com/repos/morluto/rea/contents/SECURITY.md
- MCP 契约：https://api.github.com/repos/morluto/rea/contents/docs/mcp-contracts.md
- 文件树：https://api.github.com/repos/morluto/rea/git/trees/main?recursive=1
- 版本：https://github.com/morluto/rea/releases/tag/rea-agents-3.2.0 ｜ `-4.0.0` ｜ `-5.0.0` ｜ `-6.0.0` ｜ `-6.1.0` ｜ `-6.2.0` ｜ `-6.3.0` ｜ `-6.4.0`
- 官网/案例：https://rea.tools/ ｜ https://rea.tools/showcase/ ｜ https://rea.tools/showcase/dx-ball/ ｜ https://rea.tools/showcase/notion/ ｜ https://rea.tools/showcase/th04/
- npm：https://www.npmjs.com/package/rea-agents

**二手（第三方，已在正文标注）**
- https://apidog.com/blog/what-is-rea-reverse-engineer-anything/
- https://unstone.github.io/dsh-xray/p/morluto__rea.html
- https://news.qiniu.com/archives/1791789498629
