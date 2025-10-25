#!/bin/bash
# 1️⃣ 创建目录并下载 composer7.phar
mkdir -p /opt/composer7
cd /opt/composer7
curl -sS https://getcomposer.org/composer-stable.phar -o composer7.phar
chmod +x composer7.phar

# 2️⃣ 创建全局执行脚本
cat > /usr/local/bin/composer7 <<'EOF'
#!/bin/bash
/www/server/php/74/bin/php /opt/composer7/composer7.phar "$@"
EOF

# 3️⃣ 赋予执行权限
chmod +x /usr/local/bin/composer7

# 4️⃣ 验证
composer7 -V