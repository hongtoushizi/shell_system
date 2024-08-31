#!/bin/bash

# 钉钉 Webhook URL，替换成实际的 Webhook 地址
WEBHOOK_URL="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=1f61ca30-866b-462b-901b-42d488a1a4f3"
# 设置警告阈值
THRESHOLD=5

# 最新的行数
MAX_LINE_NUM=1000

# 当前日期
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
# 获取主机名和IP
HOSTNAME=$(hostname)
IP=$(hostname -I)
# 获取当天的日期，格式为 "日"
TODAY=$(date '+%d')
CURRENT_YEAR_MONTH=$(date '+%Y%m')

LOG_FILE="/www/wwwroot/new-bwc/runtime/logs/${CURRENT_YEAR_MONTH}/${TODAY}.log"

echo "日志文件路径: $LOG_FILE"


# 每5秒循环一次
while true;do
   # 读取最新的1000条日志
   LATEST_LOGS=$(tail -n "$MAX_LINE_NUM" "$LOG_FILE")

   # 统计错误数量，假设错误日志包含 "ERROR" 关键字
   ERROR_COUNT=$(echo "$LATEST_LOGS" | grep -c "ERROR")

   echo "$(date '+%Y-%m-%d %H:%M:%S') - 最新${MAX_LINE_NUM}条日志中的错误数量:$ERROR_COUNT"

   if [ "$ERROR_COUNT" -ge "$THRESHOLD" ];then
       # 构造报警消息

    # 构建payload
    MESSAGE=$(cat <<-EOF
{
"msgtype": "markdown",
"markdown": {
  "content":"
##### 小程序error报警 \n
>  ##### <font color=#67C23A> 【服务器: </font> <font color=#FF0000> $HOSTNAME </font> \n
>  ##### <font color=#67C23A> 【服务器IP】</font> :<font color=#FF0000> $IP </font> \n
>  ##### <font color=#67C23A> 【告警时间】</font> :<font color=#FF0000> $CURRENT_TIME </font> \n
>  ##### <font color=#67C23A> 【告警内容】</font>:<font color=#FF0000>当前错误数量为：$ERROR_COUNT  </font> \n
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

       echo "$(date '+%Y-%m-%d %H:%M:%S') - 已发送企业微信报警消息"
   fi

   # 等待5秒后再次进行检查
   sleep 5
done


