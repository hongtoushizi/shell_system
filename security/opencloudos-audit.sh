#!/usr/bin/env bash
# opencloudos-audit.sh
# 仅检测/只读。只在你有权限的机器上运行。不会修改任何系统配置。
set -euo pipefail

TS=$(date +%Y%m%d%H%M%S)
OUTDIR="/root/opencloudos-audit-$TS"
mkdir -p "$OUTDIR"
echo "OpenCloudOS 只读检测报告 -> $OUTDIR"
echo "开始检测：$(date)" > "$OUTDIR/summary.txt"

echolog() { echo "$*" | tee -a "$OUTDIR/summary.txt"; }

echolog "=== 基本信息 ==="
echolog "主机名: $(hostname -f 2>/dev/null || hostname)"
echolog "当前用户: $(whoami)"
echolog "日期: $(date)"
echolog "uname: $(uname -a)"
if [ -f /etc/os-release ]; then
  echolog "---- /etc/os-release ----"
  sed -n '1,120p' /etc/os-release | tee -a "$OUTDIR/os-release.txt" >> "$OUTDIR/summary.txt" || true
fi

# Detect package manager
PKG=""
if command -v dnf >/dev/null 2>&1; then
  PKG=dnf
elif command -v yum >/dev/null 2>&1; then
  PKG=yum
fi
echolog "检测到的包管理器: ${PKG:-(未检测到 dnf/yum)}"

# 1) 检查可用更新（不安装）
if [ -n "$PKG" ]; then
  echolog ""
  echolog "=== 软件包更新检查（仅报告，不自动安装） ==="
  if [ "$PKG" = "dnf" ]; then
    echolog "运行： sudo dnf check-update  (结果已输出到 $OUTDIR/dnf-check-update.txt)"
    sudo dnf check-update > "$OUTDIR/dnf-check-update.txt" 2>&1 || true
  else
    echolog "运行： sudo yum check-update  (结果已输出到 $OUTDIR/yum-check-update.txt)"
    sudo yum check-update > "$OUTDIR/yum-check-update.txt" 2>&1 || true
  fi
fi

# 2) 检查 firewalld / iptables 状态 与 当前规则（只读）
echolog ""
echolog "=== 防火墙状态 (firewalld/iptables) ==="
if systemctl is-active --quiet firewalld 2>/dev/null; then
  echolog "firewalld: active"
  sudo firewall-cmd --list-all --zone=public > "$OUTDIR/firewalld-zone-public.txt" 2>&1 || true
  echolog "firewalld zone public rules -> $OUTDIR/firewalld-zone-public.txt"
else
  echolog "firewalld: not active or not installed"
  echolog "列出 iptables/nft (若可用)："
  if command -v iptables >/dev/null 2>&1; then
    sudo iptables -L -n -v > "$OUTDIR/iptables.txt" 2>&1 || true
    echolog "iptables -> $OUTDIR/iptables.txt"
  fi
  if command -v nft >/dev/null 2>&1; then
    sudo nft list ruleset > "$OUTDIR/nft-ruleset.txt" 2>&1 || true
    echolog "nft -> $OUTDIR/nft-ruleset.txt"
  fi
fi

# 3) SSH 配置检查（只读）
echolog ""
echolog "=== SSH 配置检测 (/etc/ssh/sshd_config) ==="
SSHD="/etc/ssh/sshd_config"
if [ -f "$SSHD" ]; then
  sudo cp "$SSHD" "$OUTDIR/sshd_config.copy" 2>/dev/null || true
  echolog "sshd_config 已复制到 $OUTDIR/sshd_config.copy (只读复制)"
  # 抽取关注项
  echo "PermitRootLogin: $(sudo grep -Ei '^\s*PermitRootLogin' $SSHD || true)" | tee -a "$OUTDIR/summary.txt"
  echo "PasswordAuthentication: $(sudo grep -Ei '^\s*PasswordAuthentication' $SSHD || true)" | tee -a "$OUTDIR/summary.txt"
  echo "PubkeyAuthentication: $(sudo grep -Ei '^\s*PubkeyAuthentication' $SSHD || true)" | tee -a "$OUTDIR/summary.txt"
  echo "Port: $(sudo grep -Ei '^\s*Port' $SSHD || true)" | tee -a "$OUTDIR/summary.txt"
else
  echolog "未找到 $SSHD"
fi

# 4) fail2ban / audit / aide / selinux / automations 检查
echolog ""
echolog "=== 常见安全服务检测（状态/安装） ==="
for pkg in fail2ban audit aide; do
  if rpm -q $pkg >/dev/null 2>&1; then
    echolog "$pkg: INSTALLED"
  else
    echolog "$pkg: NOT INSTALLED"
  fi
done

# SELinux
if command -v getenforce >/dev/null 2>&1; then
  SESTATUS=$(getenforce)
  echolog "SELinux 状态: $SESTATUS"
  echo "$SESTATUS" > "$OUTDIR/selinux-status.txt"
else
  echolog "SELinux: 无 getenforce 命令（无法检测）"
fi

# dnf-automatic / yum-cron 检查
if rpm -q dnf-automatic >/dev/null 2>&1 || rpm -q yum-cron >/dev/null 2>&1; then
  echolog "自动更新组件 (dnf-automatic 或 yum-cron) 似乎已安装"
  systemctl list-timers --all > "$OUTDIR/system-timers.txt" 2>&1 || true
  echolog "system timers -> $OUTDIR/system-timers.txt"
else
  echolog "未检测到 dnf-automatic 或 yum-cron（自动更新服务可能未安装）"
fi

# 5) 列出监听端口与对应进程（ss/netstat）
echolog ""
echolog "=== 当前监听端口与进程 ==="
if command -v ss >/dev/null 2>&1; then
  sudo ss -tulpen > "$OUTDIR/ss-listen.txt" 2>&1 || true
  echolog "ss -tulpen -> $OUTDIR/ss-listen.txt"
elif command -v netstat >/dev/null 2>&1; then
  sudo netstat -tulpen > "$OUTDIR/netstat-listen.txt" 2>&1 || true
  echolog "netstat -> $OUTDIR/netstat-listen.txt"
else
  echolog "未找到 ss/netstat"
fi

# 6) 列出启用的 systemd 服务
echolog ""
echolog "=== 已启用的 systemd 服务（可能长期运行） ==="
sudo systemctl list-unit-files --type=service | grep enabled > "$OUTDIR/enabled-services.txt" 2>/dev/null || true
echolog "enabled services -> $OUTDIR/enabled-services.txt"

# 7) 查找 world-writable 文件（限制结果量）
echolog ""
echolog "=== 查找 world-writable 文件（仅列前 100 条） ==="
sudo find / -xdev -type f -perm -0002 -print 2>/dev/null | head -n 100 > "$OUTDIR/world-writable.txt" || true
echolog "world-writable 文件 -> $OUTDIR/world-writable.txt"

# 8) 检查 /etc/shadow 中存在空密码账户（只读）
echolog ""
echolog "=== /etc/shadow 检查（是否存在空密码字段） ==="
if [ -r /etc/shadow ]; then
  sudo awk -F: '($2=="" ){print "可能存在空密码账户: "$1}' /etc/shadow > "$OUTDIR/empty-shadow-accounts.txt" 2>/dev/null || true
  if [ -s "$OUTDIR/empty-shadow-accounts.txt" ]; then
    echolog "注意：发现可能空密码账户，详情见 $OUTDIR/empty-shadow-accounts.txt"
  else
    echolog "未发现明显空密码账户（或需要更高权限读取）。"
  fi
else
  echolog "无法读取 /etc/shadow（需要 root 权限）"
fi

# 9) sysctl 推荐项对比（只读——输出当前值并标记是否与建议不同）
echolog ""
echolog "=== 常见内核网络安全 sysctl 检查 ==="
declare -A RECOMMENDED
RECOMMENDED=(
["net.ipv4.ip_forward"]="0"
["net.ipv4.conf.all.accept_source_route"]="0"
["net.ipv4.conf.all.accept_redirects"]="0"
["net.ipv4.conf.default.rp_filter"]="1"
["net.ipv4.tcp_syncookies"]="1"
)
for key in "${!RECOMMENDED[@]}"; do
  cur=$(sysctl -n $key 2>/dev/null || echo "N/A")
  want=${RECOMMENDED[$key]}
  if [ "$cur" = "$want" ]; then
    echo "$key = $cur  (OK)" >> "$OUTDIR/sysctl-check.txt"
  else
    echo "$key = $cur  (建议: $want) " >> "$OUTDIR/sysctl-check.txt"
  fi
done
echolog "sysctl 对比 -> $OUTDIR/sysctl-check.txt"

# 10) AIDE / 文件完整性工具 检查
if rpm -q aide >/dev/null 2>&1; then
  echolog "AIDE 已安装（请考虑初始化数据库：aide --init）"
else
  echolog "AIDE 未安装（若需要文件完整性监控可考虑安装）"
fi

# 11) 内核 & 已安装关键包快照
echolog ""
echolog "=== 内核与关键包快照 ==="
uname -r > "$OUTDIR/kernel-version.txt"
rpm -qa | sort > "$OUTDIR/rpm-packages.txt"
echolog "kernel -> $OUTDIR/kernel-version.txt ; rpm list -> $OUTDIR/rpm-packages.txt"

# 12) 总结与建议（只打印，不执行）
echolog ""
echolog "=== 自动化建议（仅建议，不执行） ==="
cat >> "$OUTDIR/summary.txt" <<'EOF'

检测完毕 — 建议（只读建议，不做改动）：
1) 若发现 sshd_config 中 PermitRootLogin yes 或 PasswordAuthentication yes，建议在确认公钥登录正常后手动关闭密码登录与 root 登录。
2) 若未启用 firewalld/nft/iptables，请评估并启用主机防火墙，只开放必要端口（例如 22/443/80）。
3) 若未安装 fail2ban，请在确认需求后考虑安装并配置防暴力破解规则。
4) 若 /etc/shadow 有空密码账户，必须立即调查并修复该账户。
5) 若需要文件完整性检测，考虑安装并初始化 AIDE 或同类工具，并建立定期比对任务。
6) 在生产环境启用自动安全更新前请在测试环境验证（dnf-automatic / yum-cron）。
7) 定期将 $OUTDIR 目录取出归档并保存到离线/安全位置作为审计证据。
EOF

echolog "检测完成，所有输出文件保存在: $OUTDIR"
echolog "示例修复命令（仅示范，请在确认后手动运行）："
echolog "  编辑 SSH: sudo vim /etc/ssh/sshd_config   -> 修改 PermitRootLogin no, PasswordAuthentication no -> sudo systemctl reload sshd"
echolog "  启用 firewalld: sudo dnf install -y firewalld && sudo systemctl enable --now firewalld"
echolog "  安装 fail2ban: sudo dnf install -y fail2ban && sudo systemctl enable --now fail2ban"

echo "结束时间: $(date)" >> "$OUTDIR/summary.txt"
echo "完成：请下载或查看 $OUTDIR 以获取详细检测报告。"
