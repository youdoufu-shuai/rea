#Requires -Version 5.1
<#
.SYNOPSIS
    安装 REA 并接入本机 agent 客户端（Windows）。

.DESCRIPTION
    这个脚本**不自己实现安装逻辑**，只做三件事：
      1. 检查 node / npx 版本够不够
      2. 按需设置代理
      3. 调官方命令 npx rea-agents@latest setup

    真正的安装、配置写入、回滚全部由 REA 官方 setup 负责 ——
    不去复制它的逻辑，免得官方升级后这里变成过期文档。

.PARAMETER Client
    指定客户端，跳过 setup 的交互选择。
    例：-Client claude_code,cursor

.PARAMETER Version
    指定版本（默认 latest）。想回滚就用 -Version 6.4.0

.PARAMETER Proxy
    代理地址，例：-Proxy http://127.0.0.1:7897

.EXAMPLE
    .\install-rea.ps1
    .\install-rea.ps1 -Client claude_code -Proxy http://127.0.0.1:7897
#>
[CmdletBinding()]
param(
    [string]$Client,
    [string]$Version = 'latest',
    [string]$Proxy
)

$ErrorActionPreference = 'Stop'

function Write-Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)       { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn2($msg)    { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Write-Err($msg)      { Write-Host "  XX  $msg" -ForegroundColor Red }

Write-Host @'
──────────────────────────────────────────────
  REA 安装助手 (Windows)
  REA 官方仓库: https://github.com/morluto/rea
──────────────────────────────────────────────
'@ -ForegroundColor White

# ── 1. 检查 node / npx ────────────────────────────────────
Write-Step 1 '检查 Node.js 环境'
$node = Get-Command node -ErrorAction SilentlyContinue
$npx  = Get-Command npx  -ErrorAction SilentlyContinue

if (-not $node) {
    Write-Err '找不到 node。先装 Node.js 20 LTS 或更高：https://nodejs.org'
    exit 1
}
if (-not $npx) {
    Write-Err '找不到 npx。它通常随 npm 一起安装，试试重装 Node.js。'
    exit 1
}

$nodeVer = (& node -v) -replace '^v', ''
$major = [int]($nodeVer.Split('.')[0])
Write-Ok "node v$nodeVer"
if ($major -lt 20) {
    Write-Warn2 "REA 建议 Node 20+，当前 v$nodeVer。可能能跑，但出问题别意外。"
}

# ── 2. 代理 ───────────────────────────────────────────────
Write-Step 2 '网络（首次要从 npm 拉包）'
if ($Proxy) {
    $env:HTTPS_PROXY = $Proxy
    $env:HTTP_PROXY  = $Proxy
    Write-Ok "已为本次会话设置代理 $Proxy"
} else {
    Write-Ok '未指定代理，沿用系统设置'
    Write-Host '     如果卡住不动，重跑并加 -Proxy http://127.0.0.1:7897' -ForegroundColor DarkGray
}

# ── 3. 调官方 setup ───────────────────────────────────────
Write-Step 3 "运行 npx rea-agents@$Version setup"
$npxArgs = @('-y', "rea-agents@$Version", 'setup')
if ($Client) {
    $npxArgs += @('--client', $Client)
    Write-Host "     指定客户端: $Client" -ForegroundColor DarkGray
}

Write-Host "     `$ npx $($npxArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ''
& npx @npxArgs
$code = $LASTEXITCODE

Write-Host ''
if ($code -eq 0) {
    Write-Host '──────────────────────────────────────────────' -ForegroundColor Green
    Write-Host '  安装完成' -ForegroundColor Green
    Write-Host '──────────────────────────────────────────────' -ForegroundColor Green
    Write-Host '  下一步：'
    Write-Host '    1. 完全重启被配置的客户端（不是刷新窗口）'
    Write-Host '    2. 在客户端里让它列一下 REA 的工具，确认接入成功'
    Write-Host '    3. 出问题先跑： npx rea-agents doctor'
} else {
    Write-Err "setup 退出码 $code"
    Write-Host '  排查：'
    Write-Host '    · 网络：加 -Proxy 重试'
    Write-Host '    · 权限：普通用户即可，不需要管理员（写的是用户目录下的配置）'
    Write-Host '    · 看官方说明：https://rea.tools'
}
exit $code
