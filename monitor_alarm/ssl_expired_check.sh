#!/bin/bash

# 钉钉 Webhook URL，替换成实际的 Webhook 地址
WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=1f61ca30-866b-462b-901b-42d488a1a4f3"

# 获取当天的日期，格式为 "日"

# 设置警告阈值
THRESHOLD=15

# 获取当前时间
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
# 指定获取证书信息的域名
domains=( "yqh.yinquanhang888.com"
          "oms-admin.yinquanhang888.com"
          "pay-api.yinquanhang888.com"
 )

for domain in "${domains[@]}";do
    # 使用 OpenSSL 获取证书信息
    cert_info=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates)

    # 提取过期日期
    expiry_date=$(echo $cert_info | grep -o "notAfter=.*" | cut -d= -f2)
    echo  $expiry_date

    # 将日期字符串转换为时间戳
    expiry_timestamp=$(date -d "$expiry_date" "+%s")
    echo $expiry_timestamp

    # 获取当前日期时间戳
    current_timestamp=$(date "+%s")

    # 计算剩余天数
    remaining_days=$(( ($expiry_timestamp - $current_timestamp) / 86400 ))
    echo "剩余天数： "$remaining_days
    if [ $remaining_days -le $THRESHOLD ];then
       echo "证书 $domain 的过期日期为 $expiry_date，剩余 $remaining_days 天过期。"

        # 构建payload
          MESSAGE=$(cat <<-EOF
{
"msgtype": "markdown",
"markdown": {
  "content":"
##### 域名ssl过期报警 \n
>  ##### <font color=#67C23A> 【域名】</font> :<font color=#FF0000>  ssl 过期告警 </font> \n
>  ##### <font color=#67C23A> 【告警时间】</font> :<font color=#FF0000> $CURRENT_TIME </font> \n
>  ##### <font color=#67C23A> 【告警内容】</font>:<font color=#FF0000> $domain ssl剩余天数，不足 $THRESHOLD  天, 当前剩余天数 $remaining_days </font> \n
"
}
}
EOF
          )

             # 发送报警消息
             curl -s -X POST \
                 -H "Content-Type:application/json" \
                 -d "$MESSAGE" \
                 "$WEBHOOK_URL"


    fi
done

