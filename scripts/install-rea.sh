#!/usr/bin/env bash
# ---------------------------------------------------------------
#  安装 REA 并接入本机 agent 客户端（macOS / Linux）
#
#  这个脚本不自己实现安装逻辑，只做三件事：
#    1. 检查 node / npx
#    2. 按需设置代理
#    3. 调官方命令 npx rea-agents@latest setup
#
#  真正的安装与配置写入由 REA 官方 setup 负责，
#  免得官方升级后这里变成过期文档。
#
#  用法：
#    ./install-rea.sh
#    ./install-rea.sh --client claude_code
#    ./install-rea.sh --client claude_code,cursor --proxy http://127.0.0.1:7897
#    ./install-rea.sh --version 6.4.0          # 回滚到指定版本
# ---------------------------------------------------------------
set -euo pipefail

CLIENT=""
VERSION="latest"
PROXY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)  CLIENT="$2";  shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --proxy)   PROXY="$2";   shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（--help 看用法）" >&2; exit 2 ;;
  esac
done

cyan() { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  OK  %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  !!  %s\033[0m\n' "$*"; }
err()  { printf '\033[31m  XX  %s\033[0m\n' "$*"; }
dim()  { printf '\033[90m%s\033[0m\n' "$*"; }

echo "──────────────────────────────────────────────"
echo "  REA 安装助手 (macOS / Linux)"
echo "  REA 官方仓库: https://github.com/morluto/rea"
echo "──────────────────────────────────────────────"

# ── 1. 检查 Node ─────────────────────────────────────────
cyan "[1] 检查 Node.js 环境"
if ! command -v node >/dev/null 2>&1; then
  err "找不到 node。先装 Node.js 20 LTS 或更高：https://nodejs.org"
  exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
  err "找不到 npx（通常随 npm 一起装）。"
  exit 1
fi

NODE_VER="$(node -v | sed 's/^v//')"
NODE_MAJOR="${NODE_VER%%.*}"
ok "node v$NODE_VER"
if [ "$NODE_MAJOR" -lt 20 ]; then
  warn "REA 建议 Node 20+，当前 v$NODE_VER。"
fi

# ── 2. 代理 ──────────────────────────────────────────────
cyan "[2] 网络（首次要从 npm 拉包）"
if [ -n "$PROXY" ]; then
  export HTTPS_PROXY="$PROXY"
  export HTTP_PROXY="$PROXY"
  ok "已为本次会话设置代理 $PROXY"
else
  ok "未指定代理，沿用环境变量"
  dim "     卡住的话重跑并加 --proxy http://127.0.0.1:7897"
fi

# ── 3. 官方 setup ────────────────────────────────────────
cyan "[3] 运行 npx rea-agents@$VERSION setup"
ARGS=(-y "rea-agents@$VERSION" setup)
if [ -n "$CLIENT" ]; then
  ARGS+=(--client "$CLIENT")
  dim "     指定客户端: $CLIENT"
fi

dim "     \$ npx ${ARGS[*]}"
echo
set +e
npx "${ARGS[@]}"
CODE=$?
set -e

echo
if [ $CODE -eq 0 ]; then
  printf '\033[32m──────────────────────────────────────────────\033[0m\n'
  printf '\033[32m  安装完成\033[0m\n'
  printf '\033[32m──────────────────────────────────────────────\033[0m\n'
  echo "  下一步："
  echo "    1. 完全重启被配置的客户端（不是刷新窗口）"
  echo "    2. 在客户端里让它列一下 REA 的工具，确认接入成功"
  echo "    3. 出问题先跑： npx rea-agents doctor"
else
  err "setup 退出码 $CODE"
  echo "  排查："
  echo "    · 网络：加 --proxy 重试"
  echo "    · 不需要 sudo：写的是用户目录下的配置"
  echo "    · 官方说明：https://rea.tools"
fi
exit $CODE
