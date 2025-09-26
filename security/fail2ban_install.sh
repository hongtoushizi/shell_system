#!/bin/bash

set -e

# ===============================
# 配置邮件参数
# ===============================
EMAIL_RECIPIENT="admin@example.com"   # 收件人
EMAIL_SENDER="fail2ban@example.com"   # 发件人
EMAIL_SUBJECT="Fail2Ban Alert on $(hostname)"  # 邮件主题

echo "=== 安装依赖包 ==="
sudo dnf install -y python3 python3-setuptools python3-virtualenv git firewalld iptables-services mailx

echo "=== 下载 Fail2Ban 源码 ==="
cd /tmp
git clone https://github.com/fail2ban/fail2ban.git
cd fail2ban

echo "=== 安装 Fail2Ban ==="
sudo python3 setup.py install

# 获取 fail2ban-server 路径
FAIL2BAN_SERVER=$(which fail2ban-server)
if [ -z "$FAIL2BAN_SERVER" ]; then
    echo "无法找到 fail2ban-server，请检查安装"
    exit 1
fi
echo "fail2ban-server 路径：$FAIL2BAN_SERVER"

# 确保配置文件存在
sudo mkdir -p /etc/fail2ban
sudo cp -n /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null || true

echo "=== 配置 SSH 防护 ==="
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s/^enabled *=.*/enabled = true/' /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s/^#port = ssh/port = ssh/' /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s|^#logpath =.*|logpath = /var/log/secure|' /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s/^#maxretry = 5/maxretry = 5/' /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s/^#bantime = 600/bantime = 3600/' /etc/fail2ban/jail.local

# 设置 allowipv6 = false，消除警告
grep -q '^allowipv6' /etc/fail2ban/jail.local || echo 'allowipv6 = false' | sudo tee -a /etc/fail2ban/jail.local

# 配置邮件通知
sudo sed -i '/^\[sshd\]/,/^\[.*\]/s/^#action *=.*/action = %(action_mwl)s/' /etc/fail2ban/jail.local
sudo sed -i "/^\[sshd\]/,/^\[.*\]/s|^#destemail.*|destemail = $EMAIL_RECIPIENT|" /etc/fail2ban/jail.local
sudo sed -i "/^\[sshd\]/,/^\[.*\]/s|^#sender.*|sender = $EMAIL_SENDER|" /etc/fail2ban/jail.local
sudo sed -i "/^\[sshd\]/,/^\[.*\]/s|^#mta.*|mta = mail|" /etc/fail2ban/jail.local
sudo sed -i "/^\[sshd\]/,/^\[.*\]/s|^#subject.*|subject = $EMAIL_SUBJECT|" /etc/fail2ban/jail.local

echo "=== 配置 systemd 服务 ==="
SERVICE_FILE="/etc/systemd/system/fail2ban.service"
if [ ! -f "$SERVICE_FILE" ]; then
    sudo cp /tmp/fail2ban/dist/systemd/fail2ban.service "$SERVICE_FILE"
fi

# 修改 ExecStart 为实际路径
sudo sed -i "s|ExecStart=.*|ExecStart=$FAIL2BAN_SERVER -xf start|" "$SERVICE_FILE"


# 重新加载 systemd
sudo systemctl daemon-reload

echo "=== 启动 firewalld 并配置 Fail2Ban 规则 ==="
if systemctl is-active --quiet firewalld; then
    echo "firewalld 已启用，添加 Fail2Ban firewalld 动作..."
    sudo fail2ban-client set sshd addaction firewallcmd-ipset
else
    echo "firewalld 未启用，Fail2Ban 默认使用 iptables"
fi

echo "=== 启动 Fail2Ban ==="
sudo systemctl enable --now fail2ban

echo "=== 完成 ==="
sudo systemctl status fail2ban --no-pager
sudo fail2ban-client status

echo "=== 邮件通知配置完成 ==="
echo "SSH jail 被 Ban 时会发送邮件到 $EMAIL_RECIPIENT"
