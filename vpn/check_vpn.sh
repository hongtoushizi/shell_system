#!/bin/bash
# ===============================
# macOS VPN Proxy Diagnostic Tool
# 作者: ChatGPT
# ===============================

# 代理端口（如果你用 ClashX 通常是 7890）
PROXY_HOST="127.0.0.1"
PROXY_PORT="7897"

# 颜色定义
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo "🔍 正在检测 VPN / 代理 状态..."
echo "-----------------------------------"

# 检查代理端口是否开启
if nc -z $PROXY_HOST $PROXY_PORT 2>/dev/null; then
  echo -e "✅ 代理端口已开启: ${GREEN}${PROXY_HOST}:${PROXY_PORT}${RESET}"
else
  echo -e "❌ 无法连接到代理端口: ${RED}${PROXY_HOST}:${PROXY_PORT}${RESET}"
  echo "请检查 ClashX / Surge / 代理软件是否正在运行。"
  exit 1
fi

# 检查出口 IP
IP=$(curl -s --max-time 5 --proxy http://$PROXY_HOST:$PROXY_PORT https://ifconfig.me)
if [[ -n "$IP" ]]; then
  echo -e "🌍 当前出口 IP: ${GREEN}$IP${RESET}"
else
  echo -e "❌ 无法获取出口 IP"
fi

# 检查 Google 连通性
if curl -I -s --max-time 5 --proxy http://$PROXY_HOST:$PROXY_PORT https://www.google.com | grep -q "HTTP"; then
  echo -e "✅ Google 可访问"
else
  echo -e "❌ Google 无法访问"
fi

# 检测 TCP 延迟
echo "⏱ 测试 TCP 延迟..."
TCP_LATENCY=$( (time curl -s --max-time 5 --proxy http://$PROXY_HOST:$PROXY_PORT https://www.google.com >/dev/null) 2>&1 | grep real | awk '{print $2}')
if [[ -n "$TCP_LATENCY" ]]; then
  echo -e "📶 TCP 响应时间约: ${YELLOW}$TCP_LATENCY${RESET}"
else
  echo -e "⚠️ 无法测得延迟"
fi

echo "-----------------------------------"
echo "✅ 检测完成"
